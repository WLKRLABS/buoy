import Foundation

enum StorageItemKind: String, CaseIterable, Codable {
    case folder = "Folder"
    case file = "File"
}

enum StorageScopeFilter: String, CaseIterable {
    case all = "All Heavy Items"
    case cleanup = "Cleanup Candidates"
    case userFiles = "User Files"
    case applications = "Applications"
    case developer = "Developer"
    case system = "System / Hidden"
}

enum StorageKindFilter: String, CaseIterable {
    case all = "All"
    case folders = "Folders"
    case files = "Files"
}

enum StorageSortKey: String, CaseIterable {
    case size = "Size"
    case name = "Name"
    case category = "Category"
    case path = "Path"
}

enum StorageCategory: String, CaseIterable, Codable {
    case applications = "Applications"
    case users = "User Data"
    case downloads = "Downloads"
    case documents = "Documents"
    case media = "Media"
    case developer = "Developer"
    case backups = "Backups"
    case caches = "Caches"
    case library = "Library"
    case system = "System"
    case hidden = "Hidden"
    case other = "Other"
}

enum StorageSafety: String, Codable {
    case likelySafe = "Likely Safe"
    case reviewFirst = "Review First"
    case essential = "Essential"
}

enum StorageScanMode: String, Codable {
    case summaryOnly
    case deep
}

enum StorageSnapshotSource {
    case seed
    case cached
    case live
}

enum StorageCacheStatus {
    case fresh
    case stale
    case partial
}

struct StorageItem: Equatable {
    var path: String
    var name: String
    var kind: StorageItemKind
    var sizeBytes: Int64
    var category: StorageCategory
    var safety: StorageSafety
    var isHidden: Bool
    var isCleanupCandidate: Bool
    var note: String
}

struct StorageCategorySummary: Equatable {
    var category: StorageCategory
    var sizeBytes: Int64
}

struct StorageScanSnapshot {
    var capturedAt: Date
    var disk: DiskSnapshot
    var explainedBytes: Int64
    var reclaimableBytes: Int64
    var systemBytes: Int64
    var unexplainedBytes: Int64
    var rootBreakdown: [StorageCategorySummary]
    var homeHighlights: [StorageItem]
    var cleanupHighlights: [StorageItem]
    var heavyItems: [StorageItem]
    var inaccessiblePaths: [String]
    var scanDuration: TimeInterval
    var scanMode: StorageScanMode

    static func seed(disk: DiskSnapshot, capturedAt: Date = Date()) -> StorageScanSnapshot {
        StorageScanSnapshot(
            capturedAt: capturedAt,
            disk: disk,
            explainedBytes: 0,
            reclaimableBytes: 0,
            systemBytes: 0,
            unexplainedBytes: 0,
            rootBreakdown: [],
            homeHighlights: [],
            cleanupHighlights: [],
            heavyItems: [],
            inaccessiblePaths: [],
            scanDuration: 0,
            scanMode: .summaryOnly
        )
    }

    func preservingHeavyItems(
        from previousSnapshot: StorageScanSnapshot?,
        lastDeepScanAt: Date?
    ) -> StorageScanSnapshot {
        guard scanMode == .summaryOnly, let previousSnapshot, lastDeepScanAt != nil else {
            return self
        }

        var updated = self
        updated.heavyItems = previousSnapshot.heavyItems
        return updated
    }
}

struct StorageAccessFingerprint: Codable, Equatable {
    var enabledProtectedScopes: [String]
    var customPaths: [String]

    init(enabledProtectedScopes: [String], customPaths: [String]) {
        self.enabledProtectedScopes = enabledProtectedScopes.sorted()
        self.customPaths = customPaths.sorted()
    }
}
