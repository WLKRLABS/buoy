import Foundation

@main
struct StorageCacheStoreTests {
    static func main() throws {
        try testSummaryCacheRoundTrip()
        try testDeepCacheRoundTrip()
        try testRejectsStaleSchemaVersion()
        try testInvalidatesOnFingerprintChange()
        testRefreshPolicy()
        testSummarySnapshotPreservesDeepItems()
        print("Storage cache tests passed.")
    }

    private static func testSummaryCacheRoundTrip() throws {
        let harness = try TestHarness()
        let snapshot = makeSnapshot(mode: .summaryOnly, capturedAt: Date(timeIntervalSince1970: 1_710_000_000))
        let fingerprint = StorageAccessFingerprint(
            enabledProtectedScopes: ["downloads"],
            customPaths: []
        )

        try harness.store.save(
            snapshot: snapshot,
            lastDeepScanAt: nil,
            accessFingerprint: fingerprint
        )

        let loaded = try require(
            harness.store.loadRecord(for: fingerprint),
            "Expected summary cache record to load."
        )

        expect(loaded.scanCompleteness == .summaryOnly, "Expected summary-only completeness.")
        expect(loaded.lastDeepScanAt == nil, "Expected no deep timestamp for summary-only cache.")
        let runtime = loaded.runtimeSnapshot()
        expect(runtime.heavyItems.count == snapshot.heavyItems.count, "Expected heavy item count to round-trip.")
        expect(runtime.cleanupHighlights.first?.path == snapshot.cleanupHighlights.first?.path, "Expected cleanup highlight to round-trip.")
    }

    private static func testDeepCacheRoundTrip() throws {
        let harness = try TestHarness()
        let capturedAt = Date(timeIntervalSince1970: 1_710_000_600)
        let snapshot = makeSnapshot(mode: .deep, capturedAt: capturedAt)
        let fingerprint = StorageAccessFingerprint(
            enabledProtectedScopes: ["documents", "downloads"],
            customPaths: ["/Volumes/Archive"]
        )

        try harness.store.save(
            snapshot: snapshot,
            lastDeepScanAt: capturedAt,
            accessFingerprint: fingerprint
        )

        let loaded = try require(
            harness.store.loadRecord(for: fingerprint),
            "Expected deep cache record to load."
        )

        expect(loaded.scanCompleteness == .deep, "Expected deep completeness.")
        expect(loaded.lastDeepScanAt == capturedAt, "Expected deep timestamp to persist.")
        let runtime = loaded.runtimeSnapshot()
        expect(runtime.scanMode == .deep, "Expected runtime snapshot to restore deep mode.")
        expect(runtime.heavyItems.first?.kind == .file, "Expected deep cache to retain file-heavy results.")
    }

    private static func testRejectsStaleSchemaVersion() throws {
        let harness = try TestHarness()
        let fingerprint = StorageAccessFingerprint(
            enabledProtectedScopes: ["downloads"],
            customPaths: []
        )
        let record = StorageCacheRecord(
            schemaVersion: StorageCacheRecord.currentSchemaVersion + 1,
            capturedAt: Date(timeIntervalSince1970: 1_710_001_000),
            lastDeepScanAt: nil,
            scanCompleteness: .summaryOnly,
            accessFingerprint: fingerprint,
            snapshot: StorageCacheSnapshotDTO(snapshot: makeSnapshot(mode: .summaryOnly))
        )

        try encode(record).write(to: harness.fileURL, options: .atomic)

        expect(harness.store.loadRecord(for: fingerprint) == nil, "Expected stale schema cache to be rejected.")
        expect(!FileManager.default.fileExists(atPath: harness.fileURL.path), "Expected stale schema cache file to be removed.")
    }

    private static func testInvalidatesOnFingerprintChange() throws {
        let harness = try TestHarness()
        let originalFingerprint = StorageAccessFingerprint(
            enabledProtectedScopes: ["downloads"],
            customPaths: ["/Volumes/FastSSD"]
        )
        let changedFingerprint = StorageAccessFingerprint(
            enabledProtectedScopes: ["downloads", "documents"],
            customPaths: ["/Volumes/FastSSD"]
        )

        try harness.store.save(
            snapshot: makeSnapshot(mode: .deep),
            lastDeepScanAt: Date(timeIntervalSince1970: 1_710_001_500),
            accessFingerprint: originalFingerprint
        )

        expect(harness.store.loadRecord(for: changedFingerprint) == nil, "Expected mismatched fingerprint cache to be rejected.")
        expect(!FileManager.default.fileExists(atPath: harness.fileURL.path), "Expected mismatched fingerprint cache file to be removed.")
    }

    private static func testRefreshPolicy() {
        let now = Date(timeIntervalSince1970: 1_710_100_000)
        let policy = StorageRefreshPolicy(freshnessInterval: 30 * 60)

        let freshDeep = StorageCacheRecord(
            capturedAt: now.addingTimeInterval(-60),
            lastDeepScanAt: now.addingTimeInterval(-60),
            scanCompleteness: .deep,
            accessFingerprint: StorageAccessFingerprint(enabledProtectedScopes: [], customPaths: []),
            snapshot: StorageCacheSnapshotDTO(snapshot: makeSnapshot(mode: .deep))
        )
        let partialSummary = StorageCacheRecord(
            capturedAt: now.addingTimeInterval(-60),
            lastDeepScanAt: nil,
            scanCompleteness: .summaryOnly,
            accessFingerprint: StorageAccessFingerprint(enabledProtectedScopes: [], customPaths: []),
            snapshot: StorageCacheSnapshotDTO(snapshot: makeSnapshot(mode: .summaryOnly))
        )
        let staleDeep = StorageCacheRecord(
            capturedAt: now.addingTimeInterval(-(31 * 60)),
            lastDeepScanAt: now.addingTimeInterval(-(31 * 60)),
            scanCompleteness: .deep,
            accessFingerprint: StorageAccessFingerprint(enabledProtectedScopes: [], customPaths: []),
            snapshot: StorageCacheSnapshotDTO(snapshot: makeSnapshot(mode: .deep))
        )

        expect(policy.cacheStatus(for: freshDeep, now: now) == .fresh, "Expected recent deep cache to be fresh.")
        expect(policy.cacheStatus(for: partialSummary, now: now) == .partial, "Expected summary-only cache without deep timestamp to be partial.")
        expect(policy.cacheStatus(for: staleDeep, now: now) == .stale, "Expected old cache to be stale.")
        expect(policy.automaticRefreshMode(for: nil, now: now) == .summaryOnly, "Expected no-cache auto refresh to use summary mode.")
        expect(policy.automaticRefreshMode(for: staleDeep, now: now) == .summaryOnly, "Expected stale cache auto refresh to use summary mode.")
        expect(policy.automaticRefreshMode(for: freshDeep, now: now) == nil, "Expected fresh cache to skip auto refresh.")
    }

    private static func testSummarySnapshotPreservesDeepItems() {
        let deepSnapshot = makeSnapshot(mode: .deep)
        var summarySnapshot = makeSnapshot(mode: .summaryOnly)
        summarySnapshot.heavyItems = [
            StorageItem(
                path: "/Users/test/Library",
                name: "Library",
                kind: .folder,
                sizeBytes: 6_000_000_000,
                category: .library,
                safety: .reviewFirst,
                isHidden: false,
                isCleanupCandidate: false,
                note: "Summary-only folder result."
            )
        ]

        let preserved = summarySnapshot.preservingHeavyItems(
            from: deepSnapshot,
            lastDeepScanAt: deepSnapshot.capturedAt
        )
        let untouched = summarySnapshot.preservingHeavyItems(
            from: deepSnapshot,
            lastDeepScanAt: nil
        )

        expect(preserved.heavyItems.first?.path == deepSnapshot.heavyItems.first?.path, "Expected summary snapshot to keep previous deep heavy items when available.")
        expect(untouched.heavyItems.first?.path == summarySnapshot.heavyItems.first?.path, "Expected summary snapshot to stay unchanged without a deep timestamp.")
    }

    private static func makeSnapshot(
        mode: StorageScanMode,
        capturedAt: Date = Date(timeIntervalSince1970: 1_710_000_000)
    ) -> StorageScanSnapshot {
        let disk = DiskSnapshot(
            totalGB: 1000,
            usedGB: 640,
            availableGB: 360,
            usagePercent: 64,
            mountPoint: "/"
        )
        let deepItems = [
            StorageItem(
                path: "/Users/test/Movies/archive.mov",
                name: "archive.mov",
                kind: .file,
                sizeBytes: 12_000_000_000,
                category: .media,
                safety: .reviewFirst,
                isHidden: false,
                isCleanupCandidate: false,
                note: "Large media file."
            ),
            StorageItem(
                path: "/Users/test/Downloads/installer.dmg",
                name: "installer.dmg",
                kind: .file,
                sizeBytes: 6_500_000_000,
                category: .downloads,
                safety: .reviewFirst,
                isHidden: false,
                isCleanupCandidate: true,
                note: "Installer archive."
            )
        ]
        let summaryItems = [
            StorageItem(
                path: "/Users/test/Library",
                name: "Library",
                kind: .folder,
                sizeBytes: 18_000_000_000,
                category: .library,
                safety: .reviewFirst,
                isHidden: false,
                isCleanupCandidate: false,
                note: "User library."
            ),
            StorageItem(
                path: "/Users/test/Downloads",
                name: "Downloads",
                kind: .folder,
                sizeBytes: 9_000_000_000,
                category: .downloads,
                safety: .reviewFirst,
                isHidden: false,
                isCleanupCandidate: true,
                note: "Large downloads folder."
            )
        ]

        return StorageScanSnapshot(
            capturedAt: capturedAt,
            disk: disk,
            explainedBytes: 420_000_000_000,
            reclaimableBytes: 12_500_000_000,
            systemBytes: 155_000_000_000,
            unexplainedBytes: 25_000_000_000,
            rootBreakdown: [
                StorageCategorySummary(category: .users, sizeBytes: 320_000_000_000),
                StorageCategorySummary(category: .applications, sizeBytes: 80_000_000_000),
                StorageCategorySummary(category: .system, sizeBytes: 75_000_000_000)
            ],
            homeHighlights: summaryItems,
            cleanupHighlights: [summaryItems[1]],
            heavyItems: mode == .deep ? deepItems : summaryItems,
            inaccessiblePaths: ["/Users/test/Documents/Private"],
            scanDuration: mode == .deep ? 41.2 : 7.6,
            scanMode: mode
        )
    }

    private static func encode(_ record: StorageCacheRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(record)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestError(message)
        }
        return value
    }
}

private final class TestHarness {
    let directoryURL: URL
    let fileURL: URL
    let store: StorageCacheStore

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("storage-cache.json", isDirectory: false)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        store = StorageCacheStore(fileURL: fileURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private struct TestError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
