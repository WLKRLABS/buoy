import Foundation

enum DashboardFormatters {
    static func abbreviatedPath(_ path: String) -> String { path }
}

@main
struct StorageScannerTests {
    static func main() throws {
        testDiskMetricsPreferImportantUsageCapacity()
        testProtectedScopeNormalizesAncestorGrant()
        try testSummaryModeUsesBoundedTargetsAndResidualSystemEstimate()
        try testSummaryModeSurvivesSinglePathTimeout()
        try testDeepScanKeepsLargestFileEnumeration()
        print("Storage scanner tests passed.")
    }

    private static func testDiskMetricsPreferImportantUsageCapacity() {
        let total = 1_000 * gib
        let regularAvailable = 80 * gib
        let importantAvailable = 560 * gib
        let snapshot = DiskMetricsCollector.snapshotFromVolumeValues(
            totalBytes: total,
            availableBytes: regularAvailable,
            importantAvailableBytes: importantAvailable,
            mountPoint: "/"
        )

        expect(snapshot != nil, "Expected disk snapshot to be created from volume metadata.")
        expect(snapshot?.usedGB == Double(440 * gib) / Double(gib), "Expected used capacity to prefer important-usage availability.")
        expect(snapshot?.availableGB == Double(importantAvailable) / Double(gib), "Expected available capacity to prefer important-usage availability.")
    }

    private static func testProtectedScopeNormalizesAncestorGrant() {
        let scope = StorageProtectedScope.documents
        let normalized = scope.effectiveURL(for: scope.defaultURL.deletingLastPathComponent())
        let invalid = scope.effectiveURL(for: scope.defaultURL.appendingPathComponent("Project", isDirectory: true))

        expect(normalized?.path == scope.defaultURL.standardizedFileURL.path, "Expected an ancestor grant to normalize back to the scoped folder.")
        expect(invalid == nil, "Expected a descendant folder grant to be rejected for a protected scope.")
    }

    private static func testSummaryModeUsesBoundedTargetsAndResidualSystemEstimate() throws {
        let harness = try TestHarness()
        let runner = FakeCommandRunner()
        let disk = makeDiskSnapshot(usedGB: 200)

        runner.sizeByPath["/Applications"] = 30 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Application Support", isDirectory: true).path] = 20 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Containers", isDirectory: true).path] = 8 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Group Containers", isDirectory: true).path] = 4 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Movies", isDirectory: true).path] = 12 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Music", isDirectory: true).path] = 2 * gib
        runner.sizeByPath[harness.home.appendingPathComponent(".Trash", isDirectory: true).path] = gib
        runner.sizeByPath[harness.downloads.path] = 9 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Caches", isDirectory: true).path] = 6 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Logs", isDirectory: true).path] = gib

        let scanner = StorageScanner(
            runner: runner,
            fileManager: .default,
            homeURL: harness.home,
            diskSampler: { disk }
        )

        let snapshot = try scanner.buildSnapshotSynchronously(
            mode: .summaryOnly,
            access: harness.accessSession
        )

        let measuredPaths = runner.invocations.flatMap { invocation in
            invocation.arguments.filter { !$0.hasPrefix("-") }
        }

        expect(measuredPaths.contains("/Applications"), "Expected summary scan to still try core app storage.")
        expect(!measuredPaths.contains("/System"), "Expected summary scan to skip /System.")
        expect(!measuredPaths.contains("/private"), "Expected summary scan to skip /private.")
        expect(!measuredPaths.contains("/usr"), "Expected summary scan to skip /usr.")
        expect(!measuredPaths.contains("/Library"), "Expected summary scan to skip the whole /Library tree.")
        expect(runner.invocations.allSatisfy { $0.timeout == 1.0 }, "Expected summary measurements to use a bounded timeout.")
        expect(snapshot.scanMode == .summaryOnly, "Expected summary-only snapshot.")
        expect(snapshot.explainedBytes == bytes(fromGigabytes: disk.usedGB), "Expected summary scan to close the used-space gap with a residual system estimate.")
        expect(snapshot.systemBytes > 0, "Expected residual system estimate to populate system bytes.")
        expect(snapshot.rootBreakdown.contains { $0.category == .system }, "Expected breakdown to include system estimate.")
        expect(snapshot.cleanupHighlights.contains { $0.path == harness.downloads.path }, "Expected Downloads cleanup target to surface.")
    }

    private static func testSummaryModeSurvivesSinglePathTimeout() throws {
        let harness = try TestHarness()
        let runner = FakeCommandRunner()

        runner.errorByPath["/Applications"] = BuoyError.commandFailed("Timed out after 1.0s: /usr/bin/du -skx /Applications")
        runner.sizeByPath[harness.home.appendingPathComponent("Movies", isDirectory: true).path] = 5 * gib
        runner.sizeByPath[harness.downloads.path] = 7 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Caches", isDirectory: true).path] = 3 * gib

        let scanner = StorageScanner(
            runner: runner,
            fileManager: .default,
            homeURL: harness.home,
            diskSampler: { makeDiskSnapshot(usedGB: 120) }
        )

        let snapshot = try scanner.buildSnapshotSynchronously(
            mode: .summaryOnly,
            access: harness.accessSession
        )

        expect(snapshot.inaccessiblePaths.contains("/Applications"), "Expected timed-out path to be marked inaccessible.")
        expect(snapshot.cleanupHighlights.contains { $0.path == harness.downloads.path }, "Expected remaining cleanup results to survive a timed-out sibling path.")
        expect(snapshot.rootBreakdown.contains { $0.category == .system }, "Expected system estimate even when a measured path times out.")
        expect(!snapshot.heavyItems.isEmpty, "Expected summary scan to keep any successful measurements.")
    }

    private static func testDeepScanKeepsLargestFileEnumeration() throws {
        let harness = try TestHarness()
        let runner = FakeCommandRunner()
        let movieURL = harness.home.appendingPathComponent("Movies/archive.mov")
        try Data(repeating: 0xAB, count: 4 * 1_048_576).write(to: movieURL)

        runner.sizeByPath["/Applications"] = 3 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Movies", isDirectory: true).path] = 4 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Music", isDirectory: true).path] = gib
        runner.sizeByPath[harness.home.appendingPathComponent(".Trash", isDirectory: true).path] = 512 * mib
        runner.sizeByPath[harness.downloads.path] = 2 * gib
        runner.sizeByPath[harness.home.appendingPathComponent("Library/Caches", isDirectory: true).path] = 2 * gib

        let scanner = StorageScanner(
            runner: runner,
            fileManager: .default,
            homeURL: harness.home,
            diskSampler: { makeDiskSnapshot(usedGB: 60) }
        )

        let snapshot = try scanner.buildSnapshotSynchronously(
            mode: .deep,
            access: harness.accessSession
        )

        let expectedMoviePath = movieURL.standardizedFileURL.path
        let hasMovieFile = snapshot.heavyItems.contains {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == expectedMoviePath && $0.kind == .file
        }
        expect(hasMovieFile, "Expected deep scan to keep largest-file enumeration active.")
        expect(runner.invocations.contains { $0.timeout == nil }, "Expected deep scan measurements to run without the summary timeout.")
    }

    private static func makeDiskSnapshot(usedGB: Double) -> DiskSnapshot {
        DiskSnapshot(
            totalGB: 1000,
            usedGB: usedGB,
            availableGB: 1000 - usedGB,
            usagePercent: usedGB / 10,
            mountPoint: "/"
        )
    }

    private static func bytes(fromGigabytes value: Double) -> Int64 {
        Int64(value * Double(gib))
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    private static let gib: Int64 = 1_073_741_824
    private static let mib: Int64 = 1_048_576
}

private struct TestHarness {
    let root: URL
    let home: URL
    let downloads: URL
    let accessSession: StorageAccessSession

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        home = root.appendingPathComponent("home", isDirectory: true)
        downloads = home.appendingPathComponent("Downloads", isDirectory: true)

        try Self.makeDirectory(home)
        try Self.makeDirectory(home.appendingPathComponent("Applications", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Application Support", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Containers", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Group Containers", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Caches", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Logs", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Movies", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent("Music", isDirectory: true))
        try Self.makeDirectory(home.appendingPathComponent(".Trash", isDirectory: true))
        try Self.makeDirectory(downloads)

        accessSession = StorageAccessSession(
            protectedURLs: [.downloads: downloads],
            customURLs: [],
            stopHandlers: []
        )
    }

    private static func makeDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private final class FakeCommandRunner: CommandRunning {
    struct Invocation {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval?
    }

    var sizeByPath: [String: Int64] = [:]
    var errorByPath: [String: Error] = [:]
    var invocations: [Invocation] = []

    func run(
        executable: String,
        arguments: [String],
        environment: [String : String]?,
        interactive: Bool,
        allowNonZeroExit: Bool,
        timeout: TimeInterval?
    ) throws -> CommandOutput {
        invocations.append(Invocation(executable: executable, arguments: arguments, timeout: timeout))

        let paths = arguments.filter { !$0.hasPrefix("-") }
        for path in paths {
            if let error = errorByPath[path] {
                throw error
            }
        }

        let stdout = paths.compactMap { path -> String? in
            guard let size = sizeByPath[path] else { return nil }
            return "\(size / 1024)\t\(path)"
        }.joined(separator: "\n")

        return CommandOutput(
            stdout: stdout.isEmpty ? "" : stdout + "\n",
            stderr: "",
            exitCode: 0
        )
    }

    func runDetached(
        executable: String,
        arguments: [String],
        environment: [String : String]?
    ) throws -> Int32 {
        0
    }
}
