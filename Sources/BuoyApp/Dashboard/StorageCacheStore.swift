import Foundation

struct StorageCacheRecord: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var capturedAt: Date
    var lastDeepScanAt: Date?
    var scanCompleteness: StorageScanMode
    var accessFingerprint: StorageAccessFingerprint
    var snapshot: StorageCacheSnapshotDTO

    init(
        schemaVersion: Int = StorageCacheRecord.currentSchemaVersion,
        capturedAt: Date,
        lastDeepScanAt: Date?,
        scanCompleteness: StorageScanMode,
        accessFingerprint: StorageAccessFingerprint,
        snapshot: StorageCacheSnapshotDTO
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.lastDeepScanAt = lastDeepScanAt
        self.scanCompleteness = scanCompleteness
        self.accessFingerprint = accessFingerprint
        self.snapshot = snapshot
    }

    init(
        snapshot: StorageScanSnapshot,
        lastDeepScanAt: Date?,
        accessFingerprint: StorageAccessFingerprint
    ) {
        self.init(
            capturedAt: snapshot.capturedAt,
            lastDeepScanAt: lastDeepScanAt,
            scanCompleteness: snapshot.scanMode,
            accessFingerprint: accessFingerprint,
            snapshot: StorageCacheSnapshotDTO(snapshot: snapshot)
        )
    }

    func runtimeSnapshot() -> StorageScanSnapshot {
        snapshot.runtimeSnapshot(
            capturedAt: capturedAt,
            scanMode: scanCompleteness
        )
    }
}

struct StorageCacheSnapshotDTO: Codable, Equatable {
    var disk: StorageDiskSnapshotDTO
    var explainedBytes: Int64
    var reclaimableBytes: Int64
    var systemBytes: Int64
    var unexplainedBytes: Int64
    var rootBreakdown: [StorageCategorySummaryDTO]
    var homeHighlights: [StorageItemDTO]
    var cleanupHighlights: [StorageItemDTO]
    var heavyItems: [StorageItemDTO]
    var inaccessiblePaths: [String]
    var scanDuration: TimeInterval

    init(snapshot: StorageScanSnapshot) {
        disk = StorageDiskSnapshotDTO(snapshot.disk)
        explainedBytes = snapshot.explainedBytes
        reclaimableBytes = snapshot.reclaimableBytes
        systemBytes = snapshot.systemBytes
        unexplainedBytes = snapshot.unexplainedBytes
        rootBreakdown = snapshot.rootBreakdown.map(StorageCategorySummaryDTO.init)
        homeHighlights = snapshot.homeHighlights.map(StorageItemDTO.init)
        cleanupHighlights = snapshot.cleanupHighlights.map(StorageItemDTO.init)
        heavyItems = snapshot.heavyItems.map(StorageItemDTO.init)
        inaccessiblePaths = snapshot.inaccessiblePaths
        scanDuration = snapshot.scanDuration
    }

    func runtimeSnapshot(
        capturedAt: Date,
        scanMode: StorageScanMode
    ) -> StorageScanSnapshot {
        StorageScanSnapshot(
            capturedAt: capturedAt,
            disk: disk.runtimeSnapshot(),
            explainedBytes: explainedBytes,
            reclaimableBytes: reclaimableBytes,
            systemBytes: systemBytes,
            unexplainedBytes: unexplainedBytes,
            rootBreakdown: rootBreakdown.map(\.runtimeSummary),
            homeHighlights: homeHighlights.map(\.runtimeItem),
            cleanupHighlights: cleanupHighlights.map(\.runtimeItem),
            heavyItems: heavyItems.map(\.runtimeItem),
            inaccessiblePaths: inaccessiblePaths,
            scanDuration: scanDuration,
            scanMode: scanMode
        )
    }
}

struct StorageDiskSnapshotDTO: Codable, Equatable {
    var totalGB: Double
    var usedGB: Double
    var availableGB: Double
    var usagePercent: Double
    var mountPoint: String

    init(_ snapshot: DiskSnapshot) {
        totalGB = snapshot.totalGB
        usedGB = snapshot.usedGB
        availableGB = snapshot.availableGB
        usagePercent = snapshot.usagePercent
        mountPoint = snapshot.mountPoint
    }

    func runtimeSnapshot() -> DiskSnapshot {
        DiskSnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            availableGB: availableGB,
            usagePercent: usagePercent,
            mountPoint: mountPoint
        )
    }
}

struct StorageItemDTO: Codable, Equatable {
    var path: String
    var name: String
    var kind: StorageItemKind
    var sizeBytes: Int64
    var category: StorageCategory
    var safety: StorageSafety
    var isHidden: Bool
    var isCleanupCandidate: Bool
    var note: String

    init(_ item: StorageItem) {
        path = item.path
        name = item.name
        kind = item.kind
        sizeBytes = item.sizeBytes
        category = item.category
        safety = item.safety
        isHidden = item.isHidden
        isCleanupCandidate = item.isCleanupCandidate
        note = item.note
    }

    var runtimeItem: StorageItem {
        StorageItem(
            path: path,
            name: name,
            kind: kind,
            sizeBytes: sizeBytes,
            category: category,
            safety: safety,
            isHidden: isHidden,
            isCleanupCandidate: isCleanupCandidate,
            note: note
        )
    }
}

struct StorageCategorySummaryDTO: Codable, Equatable {
    var category: StorageCategory
    var sizeBytes: Int64

    init(_ summary: StorageCategorySummary) {
        category = summary.category
        sizeBytes = summary.sizeBytes
    }

    var runtimeSummary: StorageCategorySummary {
        StorageCategorySummary(category: category, sizeBytes: sizeBytes)
    }
}

struct StorageRefreshPolicy {
    let freshnessInterval: TimeInterval

    init(freshnessInterval: TimeInterval = 30 * 60) {
        self.freshnessInterval = freshnessInterval
    }

    func cacheStatus(for record: StorageCacheRecord, now: Date = Date()) -> StorageCacheStatus {
        cacheStatus(
            capturedAt: record.capturedAt,
            scanCompleteness: record.scanCompleteness,
            lastDeepScanAt: record.lastDeepScanAt,
            now: now
        )
    }

    func cacheStatus(
        capturedAt: Date,
        scanCompleteness: StorageScanMode,
        lastDeepScanAt: Date?,
        now: Date = Date()
    ) -> StorageCacheStatus {
        if now.timeIntervalSince(capturedAt) > freshnessInterval {
            return .stale
        }

        if scanCompleteness == .summaryOnly, lastDeepScanAt == nil {
            return .partial
        }

        return .fresh
    }

    func automaticRefreshMode(for record: StorageCacheRecord?, now: Date = Date()) -> StorageScanMode? {
        guard let record else { return .summaryOnly }
        return cacheStatus(for: record, now: now) == .stale ? .summaryOnly : nil
    }
}

final class StorageCacheStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadRecord(for accessFingerprint: StorageAccessFingerprint) -> StorageCacheRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        guard let record = try? decoder.decode(StorageCacheRecord.self, from: data),
              record.schemaVersion == StorageCacheRecord.currentSchemaVersion,
              record.accessFingerprint == accessFingerprint else {
            invalidate()
            return nil
        }

        return record
    }

    func save(
        snapshot: StorageScanSnapshot,
        lastDeepScanAt: Date?,
        accessFingerprint: StorageAccessFingerprint
    ) throws {
        let record = StorageCacheRecord(
            snapshot: snapshot,
            lastDeepScanAt: lastDeepScanAt,
            accessFingerprint: accessFingerprint
        )

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: .atomic)
    }

    func invalidate() {
        try? fileManager.removeItem(at: fileURL)
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        return appSupportDirectory
            .appendingPathComponent("Buoy", isDirectory: true)
            .appendingPathComponent("storage-scan-cache.json", isDirectory: false)
    }
}
