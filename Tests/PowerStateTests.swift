import Foundation

@main
struct PowerStateTests {
    static func main() throws {
        try testOffWithGlobalSleepDisabledReportsPolicyIssue()
        try testOffWithACSleepDisabledReportsPolicyIssue()
        try testDisplaySleepNeverDoesNotDisableSystemSleep()
        try testOffWithBatterySleepDisabledReportsPolicyIssue()
        try testActiveAssertionRemainsTemporaryDiagnostic()
        try testUnreadableAssertionsDoNotChangeModeOrPolicy()
        try testFailedAssertionCommandDoesNotHideModeOrPolicy()
        try testPartialAssertionStateNeverReportsAllowed()
        try testUnknownSleepStateIsNeverReportedAllowed()
        try testOffWithLiveSleepAllowedIsVerified()
        try testEnabledMatchingSettingsIsConsistent()
        try testEnabledModeUnaffectedByAssertion()
        try testEnabledWithoutClosedLidDetectsSleepDisabledDrift()
        try testEnabledUnverifiedPolicyStillPresentsModeOn()
        try testEnabledDriftReportsMismatch()
        try testUnknownConfiguredKeyReportsIncompleteRestoreState()
        try testStoppedClamMonitorReportsMismatch()
        try testOffWithAssertionOnlyDoesNotMutate()
        try testOffWithoutRestorePointRepairsPersistentBlockers()
        try testOffFailsWhenACProfileCannotBeVerified()
        try testNoStateRepairFailuresStayTruthfulAndRetry()
        try testFailedRestoreVerificationKeepsState()
        try testOffNormalizesSavedSleepDisabled()
        try testApplyFailureKeepsPreMutationRestorePoint()
        try testApplyUsesActivePowerCapabilitySection()
        try testIncompleteRestorePointStillTurnsOffSafely()
        try testApplyThenDisableRestoresExactOriginalState()
        try testApplyOverOrphanedBlockerStillTurnsOffSafely()
        try testJSONCarriesLiveAndReconciledState()
        print("Power state tests passed.")
    }

    private static func testOffWithGlobalSleepDisabledReportsPolicyIssue() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 10

        let status = try harness.engine.status()
        expect(status.mode.enabled == false, "Expected Buoy ownership to remain off.")
        expect(status.mode.state == .disabled, "Buoy ownership must remain off even when macOS policy needs repair.")
        expect(status.mode.issues.contains(.sleepStillPrevented), "Expected a separate persistent policy issue.")
        expect(status.system.sleepAllowed == false, "Expected SleepDisabled=1 to prevent system sleep.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.modeValue == "Off", "Persistent policy drift must not replace the Off mode label.")
        expect(presentation.detail.localizedCaseInsensitiveContains("repair"), "Expected an explicit persistent policy repair message.")
    }

    private static func testOffWithACSleepDisabledReportsPolicyIssue() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 0

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == false, "Expected AC sleep=0 to disable idle system sleep.")
        expect(status.mode.state == .disabled, "AC sleep=0 must not redefine Buoy ownership.")
        expect(status.mode.issues.contains(.sleepStillPrevented), "Expected AC policy repair issue.")
    }

    private static func testDisplaySleepNeverDoesNotDisableSystemSleep() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.acSettings[.displaysleep] = 0

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == true, "Display sleep is independent from system sleep.")
        expect(status.mode.state == .disabled, "Display policy must not redefine Buoy ownership.")
        expect(status.mode.issues.isEmpty, "Display sleep=Never must not create a system-sleep repair issue.")
    }

    private static func testOffWithBatterySleepDisabledReportsPolicyIssue() throws {
        let harness = try Harness()
        harness.runner.powerSource = "Battery Power"
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.batterySettings[.sleep] = 0

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == false, "Expected active battery sleep=0 to disable idle system sleep.")
        expect(status.mode.state == .disabled, "Battery sleep=0 must not redefine Buoy ownership.")
        expect(status.mode.issues.contains(.sleepStillPrevented), "Expected battery policy repair issue.")
    }

    private static func testActiveAssertionRemainsTemporaryDiagnostic() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.sleepPreventingAssertions = ["PreventUserIdleSystemSleep"]

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == true, "Temporary assertions must not redefine persistent sleep policy.")
        expect(status.mode.state == .disabled, "Temporary assertions must not redefine Buoy mode.")
        expect(status.mode.issues.isEmpty, "Temporary assertions must not create a persistent mode issue.")
        expect(status.system.sleepPreventingAssertions == ["PreventUserIdleSystemSleep"], "Expected active assertions in status JSON.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.modeValue == "Off", "Assertion diagnostics must preserve the Off mode label.")
        expect(presentation.currentState.localizedCaseInsensitiveContains("temporarily"), "Expected temporary idle deferral wording.")
        expect(presentation.sourceDetail.localizedCaseInsensitiveContains("policy"), "Expected the persistent policy to remain visible.")
    }

    private static func testUnreadableAssertionsDoNotChangeModeOrPolicy() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.assertionsReadable = false

        let status = try harness.engine.status()
        expect(status.system.sleepAllowed == true, "Persistent policy remains verifiable without assertion diagnostics.")
        expect(status.mode.state == .disabled, "Unreadable assertions must not make Buoy mode unverified.")
        expect(status.system.sleepPreventingAssertions == nil, "Unreadable assertions should remain unavailable as diagnostics.")
    }

    private static func testFailedAssertionCommandDoesNotHideModeOrPolicy() throws {
        let harness = try Harness()
        harness.runner.failAssertionsCommand = true

        let status = try harness.engine.status()
        expect(status.mode.state == .disabled, "A diagnostic command failure must not hide known Buoy ownership.")
        expect(status.system.sleepAllowed == true, "A diagnostic command failure must not hide known persistent policy.")
        expect(status.system.sleepPreventingAssertions == nil, "Failed assertion diagnostics should be unavailable.")
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
        expect(status.mode.state == .disabled, "Known Buoy ownership stays off when macOS policy is unverified.")
        expect(status.mode.issues.contains(.sleepStateUnverified), "Expected a separate unverified policy issue.")

        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.modeValue == "Off", "Unverified policy must not replace the Off mode label.")
        expect(presentation.currentState.localizedCaseInsensitiveContains("unverified"), "Expected explicit unverified policy text.")
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
        let presentation = BuoyPowerPresenter.make(status: status)
        expect(presentation.modeValue == "On", "Expected ownership to be presented as On.")
        expect(presentation.sourceDetail.localizedCaseInsensitiveContains("keep-awake"), "Intentional On policy must not be presented as needing repair.")
    }

    private static func testEnabledModeUnaffectedByAssertion() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        harness.runner.sleepPreventingAssertions = ["PreventUserIdleSystemSleep"]
        try harness.store.save(enabledState(configured: harness.runner.acSettings))

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Temporary assertions must not turn enabled mode into a mismatch.")
        expect(status.system.sleepPreventingAssertions == ["PreventUserIdleSystemSleep"], "Expected the assertion diagnostic to remain available.")
    }

    private static func testEnabledWithoutClosedLidDetectsSleepDisabledDrift() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        harness.runner.sleepDisabled = 1
        try harness.store.save(enabledState(configured: harness.runner.acSettings))

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Closed-lid drift must not replace On ownership.")
        expect(status.mode.issues.contains(.managedSettingsDrifted), "Closed-lid-off mode must require SleepDisabled=0.")
    }

    private static func testEnabledUnverifiedPolicyStillPresentsModeOn() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = nil
        var configured = managedSettings(displaySleep: 10)
        configured[.sleep] = 10
        harness.runner.acSettings = configured
        try harness.store.save(enabledState(configured: configured))

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Policy verification health must not replace On ownership.")
        expect(status.mode.enabled, "Expected Buoy ownership to remain enabled.")
        expect(status.mode.issues.contains(.sleepStateUnverified), "Expected unverified policy health as a separate issue.")
        expect(BuoyPowerPresenter.make(status: status).modeValue == "On", "Policy health must not replace the On mode label.")
    }

    private static func testEnabledDriftReportsMismatch() throws {
        let harness = try Harness()
        let configured = managedSettings(displaySleep: 10)
        harness.runner.acSettings = configured
        harness.runner.acSettings[.sleep] = 15
        try harness.store.save(enabledState(configured: configured))

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Live AC drift must not replace On ownership.")
        expect(status.mode.issues.contains(.managedSettingsDrifted), "Expected managed_settings_drifted issue.")
        expect(BuoyPowerPresenter.make(status: status).modeValue == "On", "Configuration health must not replace the On mode label.")
    }

    private static func testUnknownConfiguredKeyReportsIncompleteRestoreState() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings)
        state.configuredValues["future_unknown_key"] = 1
        try harness.store.save(state)

        let status = try harness.engine.status()
        expect(status.mode.state == .enabled, "Incomplete restore health must not replace On ownership.")
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
        expect(status.mode.state == .enabled, "A stopped helper must not replace On ownership.")
        expect(status.mode.issues.contains(.closedLidMonitorStopped), "Expected closed_lid_monitor_stopped issue.")
    }

    private static func testOffWithAssertionOnlyDoesNotMutate() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 0
        harness.runner.acSettings[.sleep] = 10
        harness.runner.sleepPreventingAssertions = ["PreventUserIdleSystemSleep"]

        let lines = try harness.engine.disable(dryRun: false)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("temporary"), "Expected assertion-only activity to be informational.")
        expect(harness.runner.sudoCalls.isEmpty, "Assertion-only activity must not trigger privileged policy mutations.")
        expect(try harness.engine.status().mode.state == .disabled, "Mode must remain off.")
    }

    private static func testOffWithoutRestorePointRepairsPersistentBlockers() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 0
        harness.runner.acSettings[.displaysleep] = 0
        harness.runner.batterySettings[.sleep] = 0
        harness.runner.batterySettings[.displaysleep] = 0

        _ = try harness.engine.disable(dryRun: false)
        expect(harness.runner.sleepDisabled == 0, "Off must clear the global SleepDisabled override.")
        expect(harness.runner.acSettings[.sleep] == 10, "Off must repair AC sleep=Never.")
        expect(harness.runner.acSettings[.displaysleep] == 0, "Off must preserve the independent AC display-sleep preference.")
        expect(harness.runner.batterySettings[.sleep] == 10, "Off must repair battery sleep=Never.")
        expect(harness.runner.batterySettings[.displaysleep] == 0, "Off must preserve the independent battery display-sleep preference.")
        expect(!harness.runner.sudoCalls.isEmpty, "Persistent policy repair must use the privileged path.")
        let status = try harness.engine.status()
        expect(status.mode.state == .disabled, "Repair must finish with Buoy off.")
        expect(status.system.sleepAllowed == true, "Repair must finish with a sleep-enabled policy.")
    }

    private static func testOffFailsWhenACProfileCannotBeVerified() throws {
        let harness = try Harness()
        harness.runner.includeACProfile = false
        harness.runner.sleepDisabled = 1
        harness.runner.batterySettings[.sleep] = 0

        let message = expectError { try harness.engine.disable(dryRun: false) }
        expect(message.localizedCaseInsensitiveContains("AC power profile"), "Missing AC policy must block a successful Off report.")
        let status = try harness.engine.status()
        expect(status.mode.state == .disabled, "Buoy ownership remains Off even when policy verification fails.")
        expect(!status.mode.issues.isEmpty, "Missing AC policy must remain visible after the failed repair.")
    }

    private static func testNoStateRepairFailuresStayTruthfulAndRetry() throws {
        let failures: [(String, (FakeCommandRunner) -> Void)] = [
            ("SleepDisabled", { $0.failNextSleepDisabledWrite = true }),
            ("AC", { $0.failNextACWrite = true }),
            ("battery", { $0.failNextBatteryWrite = true })
        ]

        for (name, injectFailure) in failures {
            let harness = try Harness()
            harness.runner.sleepDisabled = 1
            harness.runner.acSettings[.sleep] = 0
            harness.runner.batterySettings[.sleep] = 0
            injectFailure(harness.runner)

            let message = expectError { try harness.engine.disable(dryRun: false) }
            expect(message.localizedCaseInsensitiveContains("simulated"), "\(name) repair failure must be returned instead of success.")
            let failedStatus = try harness.engine.status()
            expect(failedStatus.mode.state == .disabled, "\(name) failure must not change known Off ownership.")
            expect(failedStatus.mode.issues.contains(.sleepStillPrevented), "\(name) failure must leave the remaining blocker visible.")

            _ = try harness.engine.disable(dryRun: false)
            expect(harness.runner.sleepDisabled == 0, "\(name) retry must clear SleepDisabled.")
            expect(harness.runner.acSettings[.sleep] == 10, "\(name) retry must repair AC system sleep.")
            expect(harness.runner.batterySettings[.sleep] == 10, "\(name) retry must repair battery system sleep.")
            expect(try harness.engine.status().system.sleepAllowed == true, "\(name) retry must converge to a sleep-enabled policy.")
        }
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

    private static func testOffNormalizesSavedSleepDisabled() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings, originalSleep: 10)
        state.config?.clamEnabled = true
        state.clamOriginalSleepDisabled = 1
        try harness.store.save(state)

        let lines = try harness.engine.disable(dryRun: false)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("finite system sleep timers"), "Off must report the normalized safe policy.")
        expect(harness.runner.sleepDisabled == 0, "Off must never restore SleepDisabled=1.")
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
        expect(state.clamOriginalSleepDisabled == 0, "Expected the safe Off SleepDisabled baseline to be saved before helper launch.")
    }

    private static func testApplyUsesActivePowerCapabilitySection() throws {
        let harness = try Harness()
        harness.runner.powerSource = "Battery Power"

        let lines = try harness.engine.apply(config: BuoyConfig(), dryRun: true)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("would be applied"), "Apply must parse capabilities while running on battery.")
        expect(harness.runner.sudoCalls.isEmpty, "Dry-run capability verification must not mutate settings.")
    }

    private static func testIncompleteRestorePointStillTurnsOffSafely() throws {
        let harness = try Harness()
        harness.runner.acSettings = managedSettings(displaySleep: 10)
        var state = enabledState(configured: harness.runner.acSettings)
        state.originalValues.removeValue(forKey: BuoyPowerKey.womp.rawValue)
        try harness.store.save(state)

        let lines = try harness.engine.disable(dryRun: false)
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("restore point was incomplete"), "Expected an honest partial-restore warning.")
        expect(harness.runner.sleepDisabled == 0, "Incomplete restore state must not block safe system sleep.")
        expect(harness.runner.acSettings[.sleep] == 10, "Incomplete restore state must still restore a finite AC sleep timer.")
        expect(try harness.store.load() == nil, "Successful safe Off must clear stale active ownership.")
        expect(try harness.engine.status().mode.state == .disabled, "Incomplete restoration must still finish with Mode Off.")
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

        harness.runner.sleepPreventingAssertions = ["PreventUserIdleSystemSleep"]
        let lines = try harness.engine.disable(dryRun: false)
        expect(harness.runner.acSettings == originalAC, "Turn Off must restore every original managed AC value.")
        expect(harness.runner.sleepDisabled == 0, "Turn Off must restore the original SleepDisabled value.")
        expect(try harness.store.load() == nil, "Verified Turn Off must clear the restore state.")
        expect(try harness.engine.status().mode.state == .disabled, "Final state must be verified disabled.")
        expect(!lines.joined(separator: " ").localizedCaseInsensitiveContains("warning"), "Successful restoration must not warn.")
        expect(lines.joined(separator: " ").localizedCaseInsensitiveContains("temporary"), "External assertions should remain informational after restoration.")
    }

    private static func testApplyOverOrphanedBlockerStillTurnsOffSafely() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 0
        harness.runner.acSettings[.displaysleep] = 0

        _ = try harness.engine.apply(
            config: BuoyConfig(displaySleepMinutes: 7, clamEnabled: true, clamMinBattery: 25, clamPollSeconds: 20),
            dryRun: false
        )
        _ = try harness.engine.disable(dryRun: false)

        expect(harness.runner.sleepDisabled == 0, "Off must normalize an orphaned SleepDisabled baseline.")
        expect(harness.runner.acSettings[.sleep] == 10, "Off must not restore an orphaned sleep=Never baseline.")
        expect(harness.runner.acSettings[.displaysleep] == 0, "Off must restore the independent display-sleep preference exactly.")
        expect(try harness.store.load() == nil, "Safe restoration must clear Buoy ownership.")
    }

    private static func testJSONCarriesLiveAndReconciledState() throws {
        let harness = try Harness()
        harness.runner.sleepDisabled = 1
        harness.runner.acSettings[.sleep] = 10
        let data = try JSONEncoder().encode(harness.engine.status())
        let json = String(decoding: data, as: UTF8.self)

        expect(json.contains("\"state\":\"disabled\""), "Expected JSON mode state to reflect Buoy ownership.")
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
    var failAssertionsCommand = false
    var includeACProfile = true
    var failNextSleepDisabledWrite = false
    var failNextACWrite = false
    var failNextBatteryWrite = false
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
            return output("Capabilities for \(powerSource):\n\(keys)\n")
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
            if failAssertionsCommand {
                throw BuoyError.commandFailed("Simulated assertion command failure.")
            }
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
                if failNextSleepDisabledWrite {
                    failNextSleepDisabledWrite = false
                    throw BuoyError.commandFailed("Simulated SleepDisabled write failure.")
                }
                if applySudoMutations {
                    sleepDisabled = Int(arguments[2])
                }
                return output("")
            }
            if arguments.starts(with: ["pmset", "-c"]) || arguments.starts(with: ["pmset", "-b"]) {
                let isBattery = arguments[1] == "-b"
                if isBattery, failNextBatteryWrite {
                    failNextBatteryWrite = false
                    throw BuoyError.commandFailed("Simulated battery profile write failure.")
                }
                if !isBattery, failNextACWrite {
                    failNextACWrite = false
                    throw BuoyError.commandFailed("Simulated AC profile write failure.")
                }
                if applySudoMutations {
                    var index = 2
                    while index + 1 < arguments.count {
                        if let key = BuoyPowerKey(rawValue: arguments[index]), let value = Int(arguments[index + 1]) {
                            if isBattery {
                                batterySettings[key] = value
                            } else {
                                acSettings[key] = value
                            }
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
        let battery = "Battery Power:\n\(settingsLines(batterySettings))\n"
        guard includeACProfile else { return battery }
        return "\(battery)AC Power:\n\(settingsLines(acSettings))\n"
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
