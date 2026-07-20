import Foundation

@main
struct PowerStateTests {
    static func main() throws {
        try testOffWithGlobalSleepDisabledReportsSleepPrevented()
        try testOffWithACSleepDisabledReportsSleepPrevented()
        try testOffWithBatterySleepDisabledReportsSleepPrevented()
        try testActiveAssertionReportsSleepPrevented()
        try testUnreadableAssertionsNeverReportAllowed()
        try testPartialAssertionStateNeverReportsAllowed()
        try testUnknownSleepStateIsNeverReportedAllowed()
        try testOffWithLiveSleepAllowedIsVerified()
        try testEnabledMatchingSettingsIsConsistent()
        try testEnabledDriftReportsMismatch()
        try testUnknownConfiguredKeyReportsIncompleteRestoreState()
        try testStoppedClamMonitorReportsMismatch()
        try testOffWithoutRestorePointWarnsWithoutMutation()
        try testFailedRestoreVerificationKeepsState()
        try testRestoredOriginalSleepDisabledIsReportedHonestly()
        try testApplyFailureKeepsPreMutationRestorePoint()
        try testIncompleteRestorePointBlocksDisableBeforeMutation()
        try testApplyThenDisableRestoresExactOriginalState()
        try testJSONCarriesLiveAndReconciledState()
        print("Power state tests passed.")
    }

    private static func testOffWithGlobalSleepDisabledReportsSleepPrevented() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 10

        let status = try harness.engine.status()
        expect(status.mode.enabled == false, "Expected Buoy ownership to remain off.")
        expect(status.mode.state == .sleepPrevented, "Expected live sleep prevention to override a healthy off report.")
        expect(status.mode.issues.contains(.sleepStillPrevented), "Expected sleep_still_prevented issue.")
        expect(status.system.sleepAllowed == false, "Expected SleepDisabled=1 to prevent system sleep.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.title == "Sleep is still prevented", "Expected presentation to lead with live behavior.")
        expect(!presentation.detail.localizedCaseInsensitiveContains("normal sleep"), "Presentation must not claim normal sleep.")
        expect(!presentation.sourceDetail.localizedCaseInsensitiveContains("allowed"), "Presentation must not claim sleep is allowed.")
    }

    private static func testOffWithACSleepDisabledReportsSleepPrevented() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 0

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == false, "Expected AC sleep=0 to disable idle system sleep.")
        expect(status.mode.state == .sleepPrevented, "Expected AC sleep=0 to prevent a healthy off report.")
    }

    private static func testOffWithBatterySleepDisabledReportsSleepPrevented() throws {
        let harness = try Harness()
        harness.runner.powerSource = "Battery Power"
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.batterySettings[.sleep] = 0

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == false, "Expected active battery sleep=0 to disable idle system sleep.")
        expect(status.mode.state == .sleepPrevented, "Expected active battery sleep=0 to prevent a healthy off report.")
    }

    private static func testActiveAssertionReportsSleepPrevented() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.sleepPreventingAssertions = ["PreventUserIdleSystemSleep"]

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == false, "Expected an active sleep assertion to prevent current idle sleep.")
        expect(status.mode.state == .sleepPrevented, "Expected an active sleep assertion to prevent a healthy off report.")
        expect(status.system.sleepPreventingAssertions == ["PreventUserIdleSystemSleep"], "Expected active assertions in status JSON.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(!presentation.sourceDetail.localizedCaseInsensitiveContains("allowed"), "An active assertion must not be presented as allowed.")
    }

    private static func testUnreadableAssertionsNeverReportAllowed() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.assertionsReadable = false

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == nil, "Unreadable assertion state must make effective sleep behavior unverified.")
        expect(status.mode.state == .unverified, "Unreadable assertion state must never report a healthy off state.")
    }

    private static func testPartialAssertionStateNeverReportsAllowed() throws {
        let parsed = PMSetParser.sleepPreventingAssertions("""
            Assertion status system-wide:
               PreventSystemSleep             0
            Listed by owning process:
            """)
        expect(parsed == nil, "Partial assertion output must remain unverified.")
    }

    private static func testUnknownSleepStateIsNeverReportedAllowed() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = nil
        harness.runner.acSettings[.sleep] = 10

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == nil, "Expected missing SleepDisabled to remain unknown.")
        expect(status.mode.state == .unverified, "Expected unknown live state to report unverified.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.title == "Sleep state unverified", "Expected an explicit unverified title.")
        expect(!presentation.sourceDetail.localizedCaseInsensitiveContains("allowed"), "Unknown state must not be inferred as allowed.")
    }

    private static func testOffWithLiveSleepAllowedIsVerified() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10

        let status = try harness.engine.status()
        expect(status.mode.state == .disabled, "Expected verified off state when live settings allow sleep.")
        expect(status.system.sleepAllowed == true, "Expected live settings to allow sleep.")
    }

    private static func testEnabledMatchingSettingsIsConsistent() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        try harness.store.save(enabledState(configured: harness.runner.acSettings))

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Expected matching saved and live settings to report enabled.")
        expect(status.mode.issues.isEmpty, "Expected no issues for matching settings.")
    }

    private static func testEnabledDriftReportsMismatch() throws {
        let harness = try Harness()
        let configured = managedSettings(displaySleep: 10)
        harness.runner.acSettings = configured
        harness.runner.acSettings[.sleep] = 15
        try harness.store.save(enabledState(configured: configured))

        let status = try harness.engine.status()
        expect(status.mode.state == .configurationMismatch, "Expected live AC drift to report mismatch.")
        expect(status.mode.issues.contains(.managedSettingsDrifted), "Expected managed_settings_drifted issue.")
    }

    private static func testUnknownConfiguredKeyReportsIncompleteRestoreState() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings)
        state.configuredValues["future_unknown_key"] = 1
        try harness.store.save(state)

        let status = try harness.engine.status()
        expect(status.mode.state == .configurationMismatch, "Unknown configured keys must not report healthy ownership.")
        expect(status.mode.issues.contains(.restoreStateIncomplete), "Unknown configured keys must report an incomplete restore state.")
    }

    private static func testStoppedClamMonitorReportsMismatch() throws {
        let harness = try Harness()
        let configured = managedSettings(displaySleep: 10)
        harness.runner.acSettings = configured
        harness.runner.sleepDisabled = 1
        var state = enabledState(configured: configured)
        state.config?.clamEnabled = true
        state.clamOriginalSleepDisabled = 0
        state.clamMonitorPID = 123
        try harness.store.save(state)

        let status = try harness.engine.status()
        expect(status.mode.state == .configurationMismatch, "Expected a stopped clam monitor to report mismatch.")
        expect(status.mode.issues.contains(.closedLidMonitorStopped), "Expected closed_lid_monitor_stopped issue.")
    }

    private static func testOffWithoutRestorePointWarnsWithoutMutation() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 10

        let lines = try harness.engine.disable(dryRun: false)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("still prevent"), "Expected off to warn about live sleep prevention.")
        expect(harness.runner.sudoCalls.isEmpty, "Missing ownership must not silently mutate live power settings.")
    }

    private static func testFailedRestoreVerificationKeepsState() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        harness.runner.applySudoMutations = false
        var state = enabledState(configured: harness.runner.acSettings, originalSleep: 10)
        state.config?.clamEnabled = true
        state.clamOriginalSleepDisabled = 0
        try harness.store.save(state)

        let message = expectError { try harness.engine.disable(dryRun: false) }
        expect(message.localizedCaseInsensitiveContains("could not be verified"), "Expected explicit restoration verification failure.")
        expect(try harness.store.load() != nil, "Failed verification must keep the restore state.")
    }

    private static func testRestoredOriginalSleepDisabledIsReportedHonestly() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings, originalSleep: 10)
        state.config?.clamEnabled = true
        state.clamOriginalSleepDisabled = 1
        try harness.store.save(state)

        let lines = try harness.engine.disable(dryRun: false)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("still prevents system sleep"), "Expected restored SleepDisabled=1 to be reported honestly.")
        expect(try harness.store.load() == nil, "Verified restoration should clear the state file.")
    }

    private static func testApplyFailureKeepsPreMutationRestorePoint() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.failDetachedLaunch = true

        _ = expectError {
            try harness.engine.apply(
                config: BuoyConfig(displaySleepMinutes: 10, clamEnabled: true, clamMinBattery: 25, clamPollSeconds: 20),
                dryRun: false
            )
        }

        guard let state = try harness.store.load() else {
            fail("Apply failure must keep a recoverable state file.")
        }
        expect(state.originalValues[BuoyPowerKey.sleep.rawValue] == 10, "Expected original AC sleep value to be saved before mutation.")
        expect(state.clamOriginalSleepDisabled == 0, "Expected original SleepDisabled to be saved before helper launch.")
    }

    private static func testIncompleteRestorePointBlocksDisableBeforeMutation() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings)
        state.originalValues.removeValue(forKey: BuoyPowerKey.womp.rawValue)
        try harness.store.save(state)

        let message = expectError { try harness.engine.disable(dryRun: false) }
        expect(message.localizedCaseInsensitiveContains("restore point is incomplete"), "Expected incomplete restore point error.")
        expect(harness.runner.sudoCalls.isEmpty, "Incomplete restore state must block all privileged mutations.")
        expect(try harness.store.load() == state, "Incomplete restore state must remain available for recovery.")
    }

    private static func testApplyThenDisableRestoresExactOriginalState() throws {
        let harness = try Harness()
        let originalAC = harness.runner.acSettings
        harness.runner.sleepDisabled = 0

        _ = try harness.engine.apply(
            config: BuoyConfig(displaySleepMinutes: 7, clamEnabled: true, clamMinBattery: 25, clamPollSeconds: 20),
            dryRun: false
        )
        let appliedStatus = try harness.engine.status()
        expect(appliedStatus.mode.state == .enabled, "Expected a verified enabled state after apply.")
        expect(harness.runner.acSettings[.sleep] == 0, "Apply must disable AC idle sleep.")
        expect(harness.runner.sleepDisabled == 1, "Closed-lid mode must set SleepDisabled on AC.")

        let lines = try harness.engine.disable(dryRun: false)
        expect(harness.runner.acSettings == originalAC, "Turn Off must restore every original managed AC value.")
        expect(harness.runner.sleepDisabled == 0, "Turn Off must restore the original SleepDisabled value.")
        expect(try harness.store.load() == nil, "Verified Turn Off must clear the restore state.")
        expect(try harness.engine.status().mode.state == .disabled, "Final state must be verified disabled.")
        expect(!lines.joined(separator: " ").localizedCaseInsensitiveContains("warning"), "Successful restoration must not warn.")
    }

    private static func testJSONCarriesLiveAndReconciledState() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 10
        let data = try JSONEncoder().encode(harness.engine.status())
        let json = String(decoding: data, as: UTF8.self)

        expect(json.contains("\"state\":\"sleep_prevented\""), "Expected JSON to include reconciled mode state.")
        expect(json.contains("\"sleep_disabled\":1"), "Expected JSON to retain the raw live SleepDisabled value.")
        expect(json.contains("\"sleep_allowed\":false"), "Expected JSON to include derived live sleep behavior.")
    }

    private static func enabledState(
        configured: [BuoyPowerKey: Int],
        originalSleep: Int = 10
    ) -> PersistedState {
        var original = configured
        original[.sleep] = originalSleep
        return PersistedState(
            modeEnabled: true,
            enabledAt: "2026-07-20T00:00:00Z",
            config: BuoyConfig(displaySleepMinutes: configured[.displaysleep] ?? 10),
            originalValues: rawValues(original),
            configuredValues: rawValues(configured)
        )
    }

    private static func managedSettings(displaySleep: Int) -> [BuoyPowerKey: Int] {
        [
            .sleep: 0,
            .displaysleep: displaySleep,
            .standby: 0,
            .powernap: 0,
            .womp: 1,
            .ttyskeepawake: 1,
            .tcpkeepalive: 1
        ]
    }

    private static func rawValues(_ values: [BuoyPowerKey: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
    }

    private static func expectError(_ operation: () throws -> Any) -> String {
        do {
            _ = try operation()
            fail("Expected operation to throw.")
        } catch {
            return error.localizedDescription
        }
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) {
        do {
            if try !condition() {
                fail(message)
            }
        } catch {
            fail("\(message) Error: \(error.localizedDescription)")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private final class Harness {
    let root: URL
    let runner = FakeCommandRunner()
    let store: StateStore
    let engine: BuoyEngine

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stateURL = root.appendingPathComponent("state.json")
        store = StateStore(stateFileURL: stateURL)
        engine = BuoyEngine(
            runner: runner,
            stateStore: store,
            environment: [:],
            executablePath: "/tmp/buoy-test"
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class FakeCommandRunner: CommandRunning {
    var powerSource = "AC Power"
    var batteryPercent = 80
    var sleepDisabled: Int? = 0
    var acSettings: [BuoyPowerKey: Int] = [
        .sleep: 10,
        .displaysleep: 10,
        .standby: 1,
        .powernap: 1,
        .womp: 1,
        .ttyskeepawake: 1,
        .tcpkeepalive: 1
    ]
    var batterySettings: [BuoyPowerKey: Int] = [
        .sleep: 10,
        .displaysleep: 10,
        .standby: 1,
        .powernap: 1,
        .womp: 0,
        .ttyskeepawake: 1,
        .tcpkeepalive: 1
    ]
    var applySudoMutations = true
    var failDetachedLaunch = false
    var monitorRunning = false
    var sleepPreventingAssertions: [String] = []
    var assertionsReadable = true
    var sudoCalls: [[String]] = []

    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        interactive: Bool,
        allowNonZeroExit: Bool,
        timeout: TimeInterval?
    ) throws -> CommandOutput {
        if executable == "/usr/bin/pmset", arguments == ["-g", "cap"] {
            let keys = BuoyPowerKey.allCases.map { " \($0.rawValue)" }.joined(separator: "\n")
            return output("Capabilities for AC Power:\n\(keys)\n")
        }
        if executable == "/usr/bin/pmset", arguments == ["-g", "custom"] {
            return output(customSettingsOutput())
        }
        if executable == "/usr/bin/pmset", arguments == ["-g", "batt"] {
            return output("Now drawing from '\(powerSource)'\n -InternalBattery-0\t\(batteryPercent)%; charging; present: true\n")
        }
        if executable == "/usr/bin/pmset", arguments == ["-g"] {
            let line = sleepDisabled.map { " SleepDisabled\t\t\($0)\n" } ?? ""
            return output("System-wide power settings:\n\(line)")
        }
        if executable == "/usr/bin/pmset", arguments == ["-g", "assertions"] {
            guard assertionsReadable else {
                return output("Assertions unavailable\n")
            }
            let preventSystem = sleepPreventingAssertions.contains("PreventSystemSleep") ? 1 : 0
            let preventIdle = sleepPreventingAssertions.contains("PreventUserIdleSystemSleep") ? 1 : 0
            return output("""
                Assertion status system-wide:
                   PreventSystemSleep             \(preventSystem)
                   PreventUserIdleSystemSleep     \(preventIdle)
                Listed by owning process:
                """)
        }
        if executable == "/bin/ps" {
            return monitorRunning
                ? output("/tmp/buoy-test __clam-monitor\n")
                : CommandOutput(stdout: "", stderr: "", exitCode: 1)
        }
        if executable == "/usr/bin/sudo" {
            sudoCalls.append(arguments)
            if arguments == ["-v"] {
                return output("")
            }
            if arguments.count == 3, arguments[0] == "pmset", arguments[1] == "disablesleep" {
                if applySudoMutations {
                    sleepDisabled = Int(arguments[2])
                }
                return output("")
            }
            if arguments.starts(with: ["pmset", "-c"]) {
                if applySudoMutations {
                    var index = 2
                    while index + 1 < arguments.count {
                        if let key = BuoyPowerKey(rawValue: arguments[index]), let value = Int(arguments[index + 1]) {
                            acSettings[key] = value
                        }
                        index += 2
                    }
                }
                return output("")
            }
            if arguments.first == "kill" {
                monitorRunning = false
                return output("")
            }
        }
        throw BuoyError.commandFailed("Unexpected test command: \(executable) \(arguments.joined(separator: " "))")
    }

    func runDetached(executable: String, arguments: [String], environment: [String: String]?) throws -> Int32 {
        if failDetachedLaunch {
            throw BuoyError.commandFailed("Simulated helper launch failure.")
        }
        monitorRunning = true
        return 456
    }

    private func customSettingsOutput() -> String {
        "Battery Power:\n\(settingsLines(batterySettings))\nAC Power:\n\(settingsLines(acSettings))\n"
    }

    private func settingsLines(_ settings: [BuoyPowerKey: Int]) -> String {
        BuoyPowerKey.allCases.compactMap { key in
            settings[key].map { " \(key.rawValue) \($0)" }
        }.joined(separator: "\n")
    }

    private func output(_ stdout: String) -> CommandOutput {
        CommandOutput(stdout: stdout, stderr: "", exitCode: 0)
    }
}
