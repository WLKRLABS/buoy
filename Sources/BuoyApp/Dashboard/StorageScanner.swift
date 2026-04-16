import Foundation

final class StorageScanner {
    typealias ProgressHandler = (String) -> Void

    private struct CleanupTarget {
        var url: URL
        var category: StorageCategory
        var safety: StorageSafety
        var note: String
    }

    private let queue = DispatchQueue(label: "buoy.storage.scanner", qos: .utility)
    private let stateLock = NSLock()
    private let runner = SystemCommandRunner()
    private let fileManager = FileManager.default
    private var generation: UInt64 = 0

    func scan(
        mode: StorageScanMode,
        access: StorageAccessSession,
        progress: @escaping ProgressHandler,
        completion: @escaping (Result<StorageScanSnapshot, Error>) -> Void
    ) {
        let token = nextGeneration()
        queue.async { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try self.buildSnapshot(
                    token: token,
                    mode: mode,
                    access: access,
                    progress: progress
                )
                self.finish(token: token, result: .success(snapshot), completion: completion)
            } catch {
                self.finish(token: token, result: .failure(error), completion: completion)
            }
        }
    }

    private func nextGeneration() -> UInt64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        generation += 1
        return generation
    }

    private func isCurrent(_ token: UInt64) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation == token
    }

    private func report(token: UInt64, progress: @escaping ProgressHandler, message: String) {
        guard isCurrent(token) else { return }
        DispatchQueue.main.async {
            progress(message)
        }
    }

    private func finish(
        token: UInt64,
        result: Result<StorageScanSnapshot, Error>,
        completion: @escaping (Result<StorageScanSnapshot, Error>) -> Void
    ) {
        guard isCurrent(token) else { return }
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func buildSnapshot(
        token: UInt64,
        mode: StorageScanMode,
        access: StorageAccessSession,
        progress: @escaping ProgressHandler
    ) throws -> StorageScanSnapshot {
        defer { access.finish() }

        let startedAt = Date()
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let userDisk = DiskMetricsCollector.sample()
        let usedBytes = Self.bytes(fromGigabytes: userDisk.usedGB)

        var inaccessiblePaths = Set<String>()
        var collectedItems: [String: StorageItem] = [:]

        report(token: token, progress: progress, message: "Scanning allowed storage roots…")
        let summaryTargets = summaryTargets(homeURL: homeURL, access: access)
        let summaryItems = try measuredItems(for: summaryTargets, inaccessiblePaths: &inaccessiblePaths)
        merge(summaryItems, into: &collectedItems)

        let nestedParents = deepInspectionTargets(homeURL: homeURL, access: access)
        for parent in nestedParents {
            guard isCurrent(token) else { throw BuoyError.io("Storage scan superseded") }
            report(
                token: token,
                progress: progress,
                message: "Inspecting \(DashboardFormatters.abbreviatedPath(parent.path))…"
            )
            let items = try measuredChildren(of: parent, inaccessiblePaths: &inaccessiblePaths)
            merge(items, into: &collectedItems)
        }

        report(token: token, progress: progress, message: "Measuring likely cleanup targets…")
        let cleanupItems = try measuredCleanupTargets(
            homeURL: homeURL,
            access: access,
            inaccessiblePaths: &inaccessiblePaths
        )
        merge(cleanupItems, into: &collectedItems)

        if mode == .deep {
            report(token: token, progress: progress, message: "Finding the largest files…")
            let topFiles = largestFiles(
                in: largestFileRoots(homeURL: homeURL, access: access),
                limit: 72,
                inaccessiblePaths: &inaccessiblePaths
            )
            merge(topFiles, into: &collectedItems)
        }

        let rootBreakdown = summarize(items: summaryItems)
        let reclaimableBytes = cleanupItems.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let systemBytes = rootBreakdown.reduce(Int64(0)) { partial, summary in
            switch summary.category {
            case .system, .library, .hidden:
                return partial + summary.sizeBytes
            default:
                return partial
            }
        }
        let explainedBytes = min(summaryItems.reduce(Int64(0)) { $0 + $1.sizeBytes }, usedBytes)
        let unexplainedBytes = max(0, usedBytes - explainedBytes)

        let heavyItems = collectedItems.values
            .sorted { lhs, rhs in
                lhs.sizeBytes == rhs.sizeBytes
                    ? lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
                    : lhs.sizeBytes > rhs.sizeBytes
            }
            .prefix(220)

        let cleanupHighlights = cleanupItems
            .sorted { lhs, rhs in
                lhs.sizeBytes == rhs.sizeBytes
                    ? lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
                    : lhs.sizeBytes > rhs.sizeBytes
            }
            .prefix(6)

        let homeHighlights = summaryItems
            .filter { item in
                item.path.hasPrefix(NSHomeDirectory()) || item.path.hasPrefix("/Volumes/")
            }
            .sorted { lhs, rhs in
                lhs.sizeBytes == rhs.sizeBytes
                    ? lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
                    : lhs.sizeBytes > rhs.sizeBytes
            }
            .prefix(6)

        return StorageScanSnapshot(
            capturedAt: Date(),
            disk: userDisk,
            explainedBytes: explainedBytes,
            reclaimableBytes: reclaimableBytes,
            systemBytes: systemBytes,
            unexplainedBytes: unexplainedBytes,
            rootBreakdown: rootBreakdown,
            homeHighlights: Array(homeHighlights),
            cleanupHighlights: Array(cleanupHighlights),
            heavyItems: Array(heavyItems),
            inaccessiblePaths: inaccessiblePaths.sorted(),
            scanDuration: Date().timeIntervalSince(startedAt),
            scanMode: mode
        )
    }

    private func summaryTargets(homeURL: URL, access: StorageAccessSession) -> [URL] {
        let targets = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Library", isDirectory: true),
            URL(fileURLWithPath: "/System", isDirectory: true),
            URL(fileURLWithPath: "/private", isDirectory: true),
            URL(fileURLWithPath: "/usr", isDirectory: true),
            URL(fileURLWithPath: "/opt", isDirectory: true),
            homeURL.appendingPathComponent("Applications", isDirectory: true),
            homeURL.appendingPathComponent("Library", isDirectory: true),
            homeURL.appendingPathComponent("Movies", isDirectory: true),
            homeURL.appendingPathComponent("Music", isDirectory: true),
            homeURL.appendingPathComponent("Pictures", isDirectory: true),
            homeURL.appendingPathComponent(".Trash", isDirectory: true)
        ] + Array(access.protectedURLs.values) + access.customURLs

        return uniqueExistingDirectories(from: targets)
    }

    private func deepInspectionTargets(homeURL: URL, access: StorageAccessSession) -> [URL] {
        let libraryURL = homeURL.appendingPathComponent("Library", isDirectory: true)
        let targets = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Library/Application Support", isDirectory: true),
            URL(fileURLWithPath: "/usr/local", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew", isDirectory: true),
            libraryURL,
            libraryURL.appendingPathComponent("Application Support", isDirectory: true),
            libraryURL.appendingPathComponent("Developer", isDirectory: true)
        ] + Array(access.protectedURLs.values) + access.customURLs

        return uniqueExistingDirectories(from: targets)
    }

    private func largestFileRoots(homeURL: URL, access: StorageAccessSession) -> [URL] {
        let roots = [
            homeURL.appendingPathComponent("Library", isDirectory: true),
            homeURL.appendingPathComponent("Movies", isDirectory: true),
            homeURL.appendingPathComponent("Music", isDirectory: true),
            homeURL.appendingPathComponent("Pictures", isDirectory: true)
        ] + Array(access.protectedURLs.values) + access.customURLs

        return uniqueExistingDirectories(from: roots)
    }

    private func uniqueExistingDirectories(from urls: [URL]) -> [URL] {
        var kept: [URL] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard fileManager.fileExists(atPath: path) else { continue }
            if kept.contains(where: { existing in
                let existingPath = existing.standardizedFileURL.path
                return path == existingPath || path.hasPrefix(existingPath + "/")
            }) {
                continue
            }
            kept.removeAll { existing in
                existing.standardizedFileURL.path.hasPrefix(path + "/")
            }
            kept.append(URL(fileURLWithPath: path, isDirectory: true))
        }
        return kept
    }

    private func measuredChildren(
        of parent: URL,
        inaccessiblePaths: inout Set<String>
    ) throws -> [StorageItem] {
        let children = directChildren(of: parent)
        guard !children.isEmpty else { return [] }

        let sizes = try measuredSizes(for: children, inaccessiblePaths: &inaccessiblePaths)
        return children.compactMap { url in
            guard let size = sizes[url.path], size > 0 else { return nil }
            return makeItem(url: url, sizeBytes: size, preferredKind: nil, cleanupOverride: nil)
        }
    }

    private func measuredItems(
        for urls: [URL],
        inaccessiblePaths: inout Set<String>
    ) throws -> [StorageItem] {
        let sizes = try measuredSizes(for: urls, inaccessiblePaths: &inaccessiblePaths)
        return urls.compactMap { url in
            guard let size = sizes[url.path], size > 0 else { return nil }
            return makeItem(url: url, sizeBytes: size, preferredKind: nil, cleanupOverride: nil)
        }
    }

    private func measuredCleanupTargets(
        homeURL: URL,
        access: StorageAccessSession,
        inaccessiblePaths: inout Set<String>
    ) throws -> [StorageItem] {
        let targets = cleanupTargets(homeURL: homeURL, access: access)
            .filter { fileManager.fileExists(atPath: $0.url.path) }
        guard !targets.isEmpty else { return [] }

        let sizes = try measuredSizes(for: targets.map(\.url), inaccessiblePaths: &inaccessiblePaths)
        return targets.compactMap { target in
            guard let size = sizes[target.url.path], size > 0 else { return nil }
            return makeItem(
                url: target.url,
                sizeBytes: size,
                preferredKind: .folder,
                cleanupOverride: target
            )
        }
    }

    private func measuredSizes(
        for urls: [URL],
        inaccessiblePaths: inout Set<String>
    ) throws -> [String: Int64] {
        let existing = urls.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return [:] }

        let output = try runner.run(
            executable: "/usr/bin/du",
            arguments: ["-skx"] + existing.map(\.path),
            allowNonZeroExit: true
        )

        if !output.stderr.isEmpty {
            parseInaccessiblePaths(stderr: output.stderr).forEach { inaccessiblePaths.insert($0) }
        }

        var sizes: [String: Int64] = [:]
        for rawLine in output.stdout.split(separator: "\n") {
            let parts = rawLine.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let kibibytes = Int64(parts[0]) else { continue }
            sizes[String(parts[1])] = kibibytes * 1024
        }
        return sizes
    }

    private func directChildren(of parent: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        guard let children = try? fileManager.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            return []
        }

        return children
            .filter { $0.lastPathComponent != "." && $0.lastPathComponent != ".." }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }

    private func largestFiles(
        in roots: [URL],
        limit: Int,
        inaccessiblePaths: inout Set<String>
    ) -> [StorageItem] {
        var largest: [StorageItem] = []
        var discoveredInaccessible = Set<String>()
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isPackageKey,
            .isHiddenKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .totalFileSizeKey
        ]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsPackageDescendants],
                errorHandler: { url, _ in
                    discoveredInaccessible.insert(url.path)
                    return true
                }
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: keys)
                    guard values.isRegularFile == true else { continue }
                    let size = Int64(
                        values.totalFileAllocatedSize
                            ?? values.fileAllocatedSize
                            ?? values.totalFileSize
                            ?? values.fileSize
                            ?? 0
                    )
                    guard size > 0 else { continue }

                    let item = makeItem(url: fileURL, sizeBytes: size, preferredKind: .file, cleanupOverride: nil)
                    largest.append(item)
                    largest.sort {
                        $0.sizeBytes == $1.sizeBytes
                            ? $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
                            : $0.sizeBytes > $1.sizeBytes
                    }
                    if largest.count > limit {
                        largest.removeLast(largest.count - limit)
                    }
                } catch {
                    discoveredInaccessible.insert(fileURL.path)
                }
            }
        }

        inaccessiblePaths.formUnion(discoveredInaccessible)
        return largest
    }

    private func makeItem(
        url: URL,
        sizeBytes: Int64,
        preferredKind: StorageItemKind?,
        cleanupOverride: CleanupTarget?
    ) -> StorageItem {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        let values = (try? url.resourceValues(forKeys: keys))
        let isDirectory = values?.isDirectory ?? false
        let isHidden = (values?.isHidden ?? false) || url.lastPathComponent.hasPrefix(".")
        let kind = preferredKind ?? (isDirectory ? .folder : .file)

        if let cleanupOverride {
            return StorageItem(
                path: url.path,
                name: displayName(for: url),
                kind: kind,
                sizeBytes: sizeBytes,
                category: cleanupOverride.category,
                safety: cleanupOverride.safety,
                isHidden: isHidden,
                isCleanupCandidate: true,
                note: cleanupOverride.note
            )
        }

        let classification = classify(path: url.path, isHidden: isHidden, kind: kind)
        return StorageItem(
            path: url.path,
            name: displayName(for: url),
            kind: kind,
            sizeBytes: sizeBytes,
            category: classification.category,
            safety: classification.safety,
            isHidden: isHidden,
            isCleanupCandidate: classification.isCleanupCandidate,
            note: classification.note
        )
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "Macintosh HD"
        }
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func classify(
        path: String,
        isHidden: Bool,
        kind: StorageItemKind
    ) -> (category: StorageCategory, safety: StorageSafety, isCleanupCandidate: Bool, note: String) {
        let home = NSHomeDirectory()
        let trash = (home as NSString).appendingPathComponent(".Trash")
        let homeLibrary = (home as NSString).appendingPathComponent("Library")
        let caches = (homeLibrary as NSString).appendingPathComponent("Caches")
        let logs = (homeLibrary as NSString).appendingPathComponent("Logs")
        let mobileBackup = (homeLibrary as NSString).appendingPathComponent("Application Support/MobileSync/Backup")
        let developer = (homeLibrary as NSString).appendingPathComponent("Developer")
        let downloads = (home as NSString).appendingPathComponent("Downloads")
        let documents = (home as NSString).appendingPathComponent("Documents")
        let desktop = (home as NSString).appendingPathComponent("Desktop")
        let pictures = (home as NSString).appendingPathComponent("Pictures")
        let movies = (home as NSString).appendingPathComponent("Movies")
        let music = (home as NSString).appendingPathComponent("Music")

        if path == "/Applications" || path.hasPrefix("/Applications/") || path.hasPrefix((home as NSString).appendingPathComponent("Applications")) {
            return (.applications, .reviewFirst, false, "Large app bundles often live here.")
        }

        if path.hasPrefix("/Volumes/") {
            return (.other, .reviewFirst, false, "User-selected removable or network storage.")
        }

        if path == "/Users" || path.hasPrefix("/Users/") {
            return (.users, .reviewFirst, false, "User-owned folders and shared data live here.")
        }

        if path == downloads || path.hasPrefix(downloads + "/") {
            return (.downloads, .reviewFirst, true, "Downloads often contain installers, archives, and duplicates.")
        }

        if path == documents || path.hasPrefix(documents + "/") || path == desktop || path.hasPrefix(desktop + "/") {
            return (.documents, .reviewFirst, false, "Review personal files before deleting.")
        }

        if path == pictures || path.hasPrefix(pictures + "/") || path == movies || path.hasPrefix(movies + "/") || path == music || path.hasPrefix(music + "/") {
            return (.media, .reviewFirst, false, "Large personal media libraries often live here.")
        }

        if path == trash || path.hasPrefix(trash + "/") {
            return (.hidden, .likelySafe, true, "Trash is usually the safest place to reclaim space first.")
        }

        if path == caches || path.hasPrefix(caches + "/") || path == "/Library/Caches" || path.hasPrefix("/Library/Caches/") {
            let safety: StorageSafety = path.hasPrefix(home) ? .likelySafe : .reviewFirst
            return (.caches, safety, true, "Cache data is usually rebuildable.")
        }

        if path == logs || path.hasPrefix(logs + "/") {
            return (.caches, .likelySafe, true, "Old logs can usually be removed.")
        }

        if path == mobileBackup || path.hasPrefix(mobileBackup + "/") {
            return (.backups, .reviewFirst, true, "Old iPhone and iPad backups are often large.")
        }

        if path == developer || path.hasPrefix(developer + "/") || path.hasPrefix("/Library/Developer/") || path.hasPrefix("/opt/homebrew") || path.hasPrefix("/usr/local") {
            let lowercased = path.lowercased()
            let isCleanupCandidate = lowercased.contains("deriveddata")
                || lowercased.contains("coresimulator")
                || lowercased.contains("archives")
            let safety: StorageSafety = isCleanupCandidate ? .likelySafe : .reviewFirst
            let note = isCleanupCandidate
                ? "Developer caches, simulators, or build artifacts can usually be trimmed."
                : "Developer toolchains and package managers often live here."
            return (.developer, safety, isCleanupCandidate, note)
        }

        if path == homeLibrary || path.hasPrefix(homeLibrary + "/") || path == "/Library" || path.hasPrefix("/Library/") {
            let safety: StorageSafety = path.hasPrefix(home) ? .reviewFirst : .essential
            let note = path.hasPrefix(home)
                ? "Application support, containers, and indexes live here."
                : "Shared app support and system-managed libraries live here."
            return (.library, safety, false, note)
        }

        if path.hasPrefix("/System") || path.hasPrefix("/private") || path.hasPrefix("/usr/") || path == "/usr" || path.hasPrefix("/bin") || path.hasPrefix("/sbin") || path.hasPrefix("/dev") {
            return (.system, .essential, false, "macOS-managed system data.")
        }

        if isHidden {
            let note = path.hasPrefix(home)
                ? "Hidden folders often hold package-manager data, app support, or caches."
                : "Protected hidden system data."
            let safety: StorageSafety = path.hasPrefix(home) ? .reviewFirst : .essential
            return (.hidden, safety, path.hasPrefix(home), note)
        }

        if kind == .file,
           let ext = path.split(separator: ".").last.map({ String($0).lowercased() }),
           ["dmg", "zip", "pkg", "iso", "ipsw", "tar", "gz"].contains(ext) {
            return (.downloads, .reviewFirst, true, "Large installers and archives are good cleanup candidates.")
        }

        if path.hasPrefix(home) {
            return (.users, .reviewFirst, false, "User-owned files and folders.")
        }

        return (.other, .reviewFirst, false, "Review before deleting.")
    }

    private func merge(_ items: [StorageItem], into store: inout [String: StorageItem]) {
        for item in items {
            if let existing = store[item.path] {
                store[item.path] = merged(existing: existing, incoming: item)
            } else {
                store[item.path] = item
            }
        }
    }

    private func merged(existing: StorageItem, incoming: StorageItem) -> StorageItem {
        var merged = existing
        merged.sizeBytes = max(existing.sizeBytes, incoming.sizeBytes)
        merged.isHidden = existing.isHidden || incoming.isHidden
        merged.isCleanupCandidate = existing.isCleanupCandidate || incoming.isCleanupCandidate

        if existing.category == .other {
            merged.category = incoming.category
        }
        if incoming.isCleanupCandidate {
            merged.safety = incoming.safety
            merged.note = incoming.note
        } else if merged.note.isEmpty {
            merged.note = incoming.note
        }
        if existing.kind == .folder, incoming.kind == .file {
            merged.kind = .file
        }
        return merged
    }

    private func summarize(items: [StorageItem]) -> [StorageCategorySummary] {
        guard !items.isEmpty else { return [] }

        var grouped: [StorageCategory: Int64] = [:]
        for item in items {
            grouped[item.category, default: 0] += item.sizeBytes
        }

        var sorted = grouped.map { key, value in
            StorageCategorySummary(category: key, sizeBytes: value)
        }
        sorted.sort { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes {
                return lhs.category.rawValue.localizedCaseInsensitiveCompare(rhs.category.rawValue) == .orderedAscending
            }
            return lhs.sizeBytes > rhs.sizeBytes
        }

        var visible: [StorageCategorySummary] = Array(sorted.prefix(6))
        let remaining = sorted.dropFirst(6).reduce(Int64(0)) { $0 + $1.sizeBytes }
        if remaining > 0 {
            visible.append(StorageCategorySummary(category: .other, sizeBytes: remaining))
        }
        return visible
    }

    private func cleanupTargets(homeURL: URL, access: StorageAccessSession) -> [CleanupTarget] {
        let libraryURL = homeURL.appendingPathComponent("Library", isDirectory: true)
        var targets = [
            CleanupTarget(
                url: homeURL.appendingPathComponent(".Trash", isDirectory: true),
                category: .hidden,
                safety: .likelySafe,
                note: "Trash is usually the safest place to reclaim space first."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Caches", isDirectory: true),
                category: .caches,
                safety: .likelySafe,
                note: "Cache data is usually rebuildable."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Logs", isDirectory: true),
                category: .caches,
                safety: .likelySafe,
                note: "Old logs can usually be removed."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Developer/Xcode/DerivedData", isDirectory: true),
                category: .developer,
                safety: .likelySafe,
                note: "DerivedData is safe to regenerate."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Developer/Xcode/Archives", isDirectory: true),
                category: .developer,
                safety: .reviewFirst,
                note: "Review old Xcode archives before deleting them."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Developer/CoreSimulator", isDirectory: true),
                category: .developer,
                safety: .reviewFirst,
                note: "Unused simulator data can be trimmed when you need space."
            ),
            CleanupTarget(
                url: libraryURL.appendingPathComponent("Application Support/MobileSync/Backup", isDirectory: true),
                category: .backups,
                safety: .reviewFirst,
                note: "Old iPhone and iPad backups are often large."
            ),
            CleanupTarget(
                url: URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
                category: .caches,
                safety: .reviewFirst,
                note: "Shared system-wide caches should be reviewed before deleting."
            )
        ]

        if let downloadsURL = access.protectedURLs[.downloads] {
            targets.insert(
                CleanupTarget(
                    url: downloadsURL,
                    category: .downloads,
                    safety: .reviewFirst,
                    note: "Downloads often contain installers, archives, and duplicates."
                ),
                at: 1
            )
        }

        return targets
    }

    private func parseInaccessiblePaths(stderr: String) -> [String] {
        stderr
            .split(separator: "\n")
            .compactMap { line in
                let text = String(line)
                let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                guard parts.count >= 2 else {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private static func bytes(fromGigabytes value: Double) -> Int64 {
        Int64(value * 1_073_741_824.0)
    }
}
