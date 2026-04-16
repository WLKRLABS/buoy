import Foundation

enum StorageProtectedScope: String, CaseIterable {
    case desktop
    case documents
    case downloads
    case pictures

    var title: String {
        switch self {
        case .desktop:
            return "Desktop"
        case .documents:
            return "Documents"
        case .downloads:
            return "Downloads"
        case .pictures:
            return "Pictures"
        }
    }

    var note: String {
        switch self {
        case .desktop:
            return "Only scan Desktop when you explicitly enable it."
        case .documents:
            return "Keep Documents opt-in to avoid surprise permission prompts."
        case .downloads:
            return "Downloads is useful for cleanup, but it should be your call."
        case .pictures:
            return "Pictures can trigger the macOS Photos prompt, so keep it opt-in."
        }
    }

    var defaultURL: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        switch self {
        case .desktop:
            return home.appendingPathComponent("Desktop", isDirectory: true)
        case .documents:
            return home.appendingPathComponent("Documents", isDirectory: true)
        case .downloads:
            return home.appendingPathComponent("Downloads", isDirectory: true)
        case .pictures:
            return home.appendingPathComponent("Pictures", isDirectory: true)
        }
    }

    var enabledDefaultsKey: String {
        "storage_access.\(rawValue).enabled"
    }

    var bookmarkDefaultsKey: String {
        "storage_access.\(rawValue).bookmark"
    }

    func effectiveURL(for grantedURL: URL) -> URL? {
        let desiredURL = defaultURL.standardizedFileURL
        let desiredPath = desiredURL.path
        let grantedPath = grantedURL.standardizedFileURL.path

        if grantedPath == desiredPath {
            return desiredURL
        }

        if desiredPath.hasPrefix(grantedPath + "/") {
            return desiredURL
        }

        return nil
    }
}

final class StorageAccessSession {
    let protectedURLs: [StorageProtectedScope: URL]
    let customURLs: [URL]

    private var stopHandlers: [() -> Void]
    private var finished = false

    init(
        protectedURLs: [StorageProtectedScope: URL],
        customURLs: [URL],
        stopHandlers: [() -> Void]
    ) {
        self.protectedURLs = protectedURLs
        self.customURLs = customURLs
        self.stopHandlers = stopHandlers
    }

    func finish() {
        guard !finished else { return }
        finished = true
        stopHandlers.reversed().forEach { $0() }
        stopHandlers.removeAll()
    }

    deinit {
        finish()
    }
}

final class StorageAccessManager {
    private enum Keys {
        static let customEnabled = "storage_access.custom.enabled"
        static let customBookmarks = "storage_access.custom.bookmarks"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ scope: StorageProtectedScope) -> Bool {
        defaults.bool(forKey: scope.enabledDefaultsKey)
    }

    func setEnabled(_ enabled: Bool, for scope: StorageProtectedScope) {
        defaults.set(enabled, forKey: scope.enabledDefaultsKey)
    }

    func hasBookmark(for scope: StorageProtectedScope) -> Bool {
        defaults.data(forKey: scope.bookmarkDefaultsKey) != nil
    }

    func resolvedURL(for scope: StorageProtectedScope) -> URL? {
        guard let url = resolvedBookmarkURL(for: scope) else { return nil }
        return scope.effectiveURL(for: url)
    }

    func saveBookmark(for scope: StorageProtectedScope, url: URL) throws {
        let data = try bookmarkData(for: url)
        defaults.set(data, forKey: scope.bookmarkDefaultsKey)
    }

    private func resolvedBookmarkURL(for scope: StorageProtectedScope) -> URL? {
        guard let data = defaults.data(forKey: scope.bookmarkDefaultsKey) else { return nil }
        return resolveURL(forBookmarkData: data) { [weak self] refreshed in
            self?.defaults.set(refreshed, forKey: scope.bookmarkDefaultsKey)
        }
    }

    func isCustomLocationsEnabled() -> Bool {
        defaults.bool(forKey: Keys.customEnabled)
    }

    func setCustomLocationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.customEnabled)
    }

    func hasCustomBookmarks() -> Bool {
        let items = defaults.array(forKey: Keys.customBookmarks) as? [Data] ?? []
        return !items.isEmpty
    }

    func resolvedCustomURLs() -> [URL] {
        let items = defaults.array(forKey: Keys.customBookmarks) as? [Data] ?? []
        guard !items.isEmpty else { return [] }

        var resolved: [URL] = []
        var refreshedData: [Data] = []
        for data in items {
            guard let url = resolveURL(forBookmarkData: data, refreshed: { refreshedData.append($0) }) else {
                continue
            }
            resolved.append(url)
            if refreshedData.count < resolved.count, let renewed = try? bookmarkData(for: url) {
                refreshedData.append(renewed)
            }
        }

        if !refreshedData.isEmpty {
            defaults.set(refreshedData, forKey: Keys.customBookmarks)
        }

        return resolved.sorted {
            $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }
    }

    func saveCustomBookmarks(for urls: [URL]) throws {
        let bookmarks = try urls.map { try bookmarkData(for: $0) }
        defaults.set(bookmarks, forKey: Keys.customBookmarks)
    }

    func clearCustomBookmarks() {
        defaults.removeObject(forKey: Keys.customBookmarks)
        defaults.set(false, forKey: Keys.customEnabled)
    }

    func cacheFingerprint() -> StorageAccessFingerprint {
        let enabledProtectedScopes = StorageProtectedScope.allCases
            .filter { isEnabled($0) }
            .map(\.rawValue)

        let customPaths = isCustomLocationsEnabled()
            ? resolvedCustomURLs().map { $0.standardizedFileURL.path }
            : []

        return StorageAccessFingerprint(
            enabledProtectedScopes: enabledProtectedScopes,
            customPaths: customPaths
        )
    }

    func beginAccessSession() -> StorageAccessSession {
        var protectedURLs: [StorageProtectedScope: URL] = [:]
        var customURLs: [URL] = []
        var stopHandlers: [() -> Void] = []

        for scope in StorageProtectedScope.allCases where isEnabled(scope) {
            guard let grantedURL = resolvedBookmarkURL(for: scope),
                  let effectiveURL = scope.effectiveURL(for: grantedURL) else {
                continue
            }
            if grantedURL.startAccessingSecurityScopedResource() {
                stopHandlers.append { grantedURL.stopAccessingSecurityScopedResource() }
            }
            protectedURLs[scope] = effectiveURL
        }

        if isCustomLocationsEnabled() {
            for url in resolvedCustomURLs() {
                if url.startAccessingSecurityScopedResource() {
                    stopHandlers.append { url.stopAccessingSecurityScopedResource() }
                }
                customURLs.append(url)
            }
        }

        return StorageAccessSession(
            protectedURLs: protectedURLs,
            customURLs: customURLs,
            stopHandlers: stopHandlers
        )
    }

    private func bookmarkData(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private func resolveURL(
        forBookmarkData data: Data,
        refreshed: ((Data) -> Void)? = nil
    ) -> URL? {
        var isStale = false

        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            if isStale, let renewed = try? bookmarkData(for: url) {
                refreshed?(renewed)
            }
            return url
        }

        isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            if isStale, let renewed = try? bookmarkData(for: url) {
                refreshed?(renewed)
            }
            return url
        }

        return nil
    }
}
