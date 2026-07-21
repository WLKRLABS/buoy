import Foundation

public final class BuoyEngine {
    private static let safeSleepMinutes = 10

    public let runner: CommandRunning
    public let stateStore: StateStore
    public let environment: [String: String]
    public let executablePath: String

    public init(
        runner: CommandRunning = SystemCommandRunner(),
        stateStore: StateStore = StateStore(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executablePath: String = CommandLine.arguments.first ?? buoyCommandName
    ) {
        self.runner = runner
        self.stateStore = stateStore
        self.environment = environment
        self.executablePath = executablePath
    }

    public func apply(config: BuoyConfig, dryRun: Bool) throws -> [String] {
        try Self.validate(config: config)

        let supportedKeys = try supportedACKeys()
        let currentSettings = try currentACSettings()
        let desiredSettings = PMSetParser.desiredValues(supported: supportedKeys, config: config)

        guard !desiredSettings.isEmpty else {
            throw BuoyError.commandFailed("No supported AC settings were found to manage on this Mac.")
        }

        var state = try stateStore.load() ?? PersistedState()
        if !state.modeEnabled {
            state = PersistedState()
        }
        if state.originalValues.isEmpty {
            state.originalValues = Self.sleepEnabledSettings(from: currentSettings).mapKeys(\.rawValue)
        }
        state.modeEnabled = true
        state.enabledAt = state.enabledAt ?? Self.nowUTC()
        state.config = config
        state.configuredValues = desiredSettings.mapKeys(\.rawValue)
        try Self.validateRestorePoint(state)

        var messages: [String] = []
        if try currentPowerSource() != "AC Power" {
            messages.append("Warning: You are not currently on AC power. The settings still apply to AC and will take effect when plugged in.")
        }

        if dryRun {
            messages.append("Buoy would be applied with display sleep \(config.displaySleepMinutes) minute(s).")
            messages.append(config.clamEnabled
                ? "Closed-lid awake mode would be enabled while charging or above \(config.clamMinBattery)% battery."
                : "Closed-lid awake mode would be disabled.")
            return messages
        }

        try sudoValidate()
        if config.clamEnabled {
            guard try currentSleepDisabled() != nil else {
                throw BuoyError.commandFailed("Unable to read SleepDisabled; no power settings were changed.")
            }
            state.clamOriginalSleepDisabled = 0
        }

        // Keep the restore point durable before the first power mutation. If a
        // later command fails, status reports drift and `off` can still recover.
        try stateStore.save(state)
        try setACSettings(desiredSettings)

        if config.clamEnabled {
            state = try enableClamMonitor(config: config, state: state)
        } else {
            state = try disableClamMonitor(state: state, dryRun: false)
        }

        try stateStore.save(state)

        messages.append("Buoy mode applied.")
        messages.append("Display sleep on AC is set to \(config.displaySleepMinutes) minute(s); full system idle sleep on AC is disabled.")
        messages.append(config.clamEnabled
            ? "Closed-lid awake mode is enabled while charging or above \(config.clamMinBattery)% battery."
            : "Closed-lid awake mode is disabled.")
        return messages
    }

    public func disable(dryRun: Bool) throws -> [String] {
        guard let state = try stateStore.load(), state.modeEnabled else {
            let currentStatus = try status()
            let needsRepair = currentStatus.mode.issues.contains(.sleepStillPrevented)
            let policyUnverified = currentStatus.mode.issues.contains(.sleepStateUnverified)

            if !needsRepair, !policyUnverified, currentStatus.system.sleepAllowed == true {
                return Self.offMessages(status: currentStatus, changed: false)
            }
            if dryRun {
                return ["Buoy mode is off; the persistent sleep policy would be repaired where needed and verified."]
            }

            try sudoValidate()
            try repairPersistentSleepPolicy()
            try verifySleepEnabledPolicy()
            return Self.offMessages(status: try status(), changed: true)
        }

        let restorePointIsComplete = (try? Self.validateRestorePoint(state)) != nil
        let savedState = state
        let restorableSettings = Self.sleepEnabledSettings(from: Self.restoreSettings(from: state))

        if dryRun {
            var messages = ["Buoy mode would be turned off and saved settings restored with persistent sleep blockers normalized."]
            if !restorePointIsComplete {
                messages.append("Warning: the restore point is incomplete; only saved keys can be restored before sleep is re-enabled.")
            }
            return messages
        }

        try sudoValidate()
        _ = try disableClamMonitor(state: state, dryRun: false)
        try setACSettings(restorableSettings)
        try repairPersistentSleepPolicy()
        if restorePointIsComplete {
            try verifyRestoration(from: savedState)
        } else if !restorableSettings.isEmpty {
            try verifyRestoredACSettings(restorableSettings)
        }
        try verifySleepEnabledPolicy()
        try stateStore.clear()

        let restoredStatus = try status()
        guard restoredStatus.mode.state == .disabled, restoredStatus.system.sleepAllowed == true else {
            throw BuoyError.commandFailed("Buoy restore state remained enabled after Turn Off.")
        }
        var messages = Self.offMessages(status: restoredStatus, changed: true)
        if !restorePointIsComplete {
            messages.append("Warning: the restore point was incomplete; saved keys were restored and unsaved non-sleep settings were left unchanged.")
        }
        return messages
    }

    public func status() throws -> BuoyStatus {
        let state = try stateStore.load()
        let monitorRunning = try state?.clamMonitorPID.flatMap(isMonitorRunning(pid:)) ?? false
        let config = state?.config
        let batteryStatus = try currentBatteryStatus()
        let powerSource = PMSetParser.currentPowerSource(batteryStatus)
        let batteryPercent = PMSetParser.currentBatteryPercentage(batteryStatus)
        let hasInternalBattery = PMSetParser.hasInternalBattery(batteryStatus)
        let sleepDisabled = try currentSleepDisabled()
        let sleepPreventingAssertions: [String]?
        do {
            sleepPreventingAssertions = try currentSleepPreventingAssertions()
        } catch {
            sleepPreventingAssertions = nil
        }
        let customSettings = try currentCustomSettings()
        let managedAC = PMSetParser.parseCustomSettings(customSettings)
        let managedBattery = PMSetParser.parseCustomSettings(customSettings, section: "Battery Power:")
        let activeSettings: [BuoyPowerKey: Int]
        switch powerSource {
        case "AC Power":
            activeSettings = PMSetParser.parseCustomSettings(customSettings, section: "AC Power:")
        case "Battery Power":
            activeSettings = PMSetParser.parseCustomSettings(customSettings, section: "Battery Power:")
        default:
            activeSettings = [:]
        }
        let systemSleepMinutes = activeSettings[.sleep]
        let displaySleepMinutes = activeSettings[.displaysleep]
        let sleepAllowed = Self.sleepAllowed(
            sleepDisabled: sleepDisabled,
            systemSleepMinutes: systemSleepMinutes
        )
        let issues = Self.modeIssues(
            state: state,
            monitorRunning: monitorRunning,
            powerSource: powerSource,
            batteryPercent: batteryPercent,
            hasInternalBattery: hasInternalBattery,
            sleepDisabled: sleepDisabled,
            sleepAllowed: sleepAllowed,
            managedAC: managedAC,
            managedBattery: managedBattery
        )

        return BuoyStatus(
            product: BuoyProductInfo(
                name: buoyProductName,
                version: buoyVersion,
                command: buoyCommandName
            ),
            mode: BuoyModeStatus(
                enabled: state?.modeEnabled ?? false,
                state: Self.modeState(modeEnabled: state?.modeEnabled ?? false),
                issues: issues,
                enabledAt: state?.enabledAt,
                displaySleepMinutes: config?.displaySleepMinutes
            ),
            clam: BuoyClamStatus(
                enabled: config?.clamEnabled ?? false,
                minBattery: config?.clamMinBattery,
                pollSeconds: config?.clamPollSeconds,
                monitorPID: state?.clamMonitorPID,
                monitorRunning: monitorRunning
            ),
            system: BuoySystemStatus(
                powerSource: powerSource,
                batteryPercent: batteryPercent,
                sleepDisabled: sleepDisabled,
                systemSleepMinutes: systemSleepMinutes,
                displaySleepMinutes: displaySleepMinutes,
                sleepAllowed: sleepAllowed,
                sleepPreventingAssertions: sleepPreventingAssertions
            ),
            paths: BuoyPathStatus(
                stateFile: stateStore.stateFileURL.path
            ),
            managedAC: managedAC.mapKeys(\.rawValue),
            configured: state?.configuredValues ?? [:],
            original: state?.originalValues ?? [:]
        )
    }

    public func doctor() -> DoctorStatus {
        DoctorStatus(
            macOS: true,
            pmset: FileManager.default.isExecutableFile(atPath: "/usr/bin/pmset"),
            osascript: FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript"),
            swift: !(environment["SWIFT_EXEC"] ?? "").isEmpty || FileManager.default.isExecutableFile(atPath: "/usr/bin/swift"),
            xcodebuild: FileManager.default.isExecutableFile(atPath: "/usr/bin/xcodebuild"),
            stateDir: stateStore.stateDirectoryURL.path,
            stateFile: stateStore.stateFileURL.path
        )
    }

    public func screenOff(dryRun: Bool) throws -> [String] {
        if dryRun {
            return [
                "Dry run: pmset displaysleepnow",
                "Display would turn off immediately; moving the mouse or pressing a key will wake it."
            ]
        }

        _ = try runner.run(executable: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        return ["Display sleeping now; move the mouse or press a key to wake it."]
    }

    public func install(targetDirectory: URL, dryRun: Bool) throws -> [String] {
        let fileManager = FileManager.default
        let commandURL = targetDirectory.appendingPathComponent(buoyCommandName)

        if dryRun {
            return [
                "Dry run: mkdir -p \(targetDirectory.path)",
                "Dry run: copy \(executablePath) to \(commandURL.path)"
            ]
        }

        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
        if fileManager.fileExists(atPath: commandURL.path) {
            try fileManager.removeItem(at: commandURL)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: executablePath), to: commandURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)

        return [
            "Installed CLI at \(commandURL.path)"
        ]
    }

    public func appendProjectToPATH(dryRun: Bool) throws -> [String] {
        let projectRoot = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let line = #"export PATH="$PATH:\#(projectRoot.path)""#
        let rcFile = ShellProfiles.rcFile()

        if let existing = try? String(contentsOf: rcFile, encoding: .utf8), existing.contains(projectRoot.path) {
            return ["PATH already contains \(projectRoot.path) in \(rcFile.path)."]
        }

        if dryRun {
            return ["Dry run: append '\(line)' to \(rcFile.path)"]
        }

        let block = "\n# buoy path\n\(line)\n"
        if FileManager.default.fileExists(atPath: rcFile.path) {
            let handle = try FileHandle(forWritingTo: rcFile)
            try handle.seekToEnd()
            handle.write(Data(block.utf8))
            try handle.close()
        } else {
            try block.write(to: rcFile, atomically: true, encoding: .utf8)
        }

        return ["Appended \(projectRoot.path) to PATH in \(rcFile.path). Restart or source that file."]
    }

    public func runClamMonitor(stateFilePath: String, minBattery: Int, pollSeconds: Int) throws {
        try Self.validateClam(minBattery: minBattery, pollSeconds: pollSeconds)
        let monitorStore = StateStore(stateFileURL: URL(fileURLWithPath: stateFilePath))

        while true {
            guard let state = try monitorStore.load(), state.modeEnabled, let config = state.config, config.clamEnabled else {
                exit(0)
            }

            let desired = try desiredSleepDisabled(minBattery: minBattery)
            let current = try currentSleepDisabled()
            if current != desired {
                _ = try runner.run(executable: "/usr/bin/pmset", arguments: ["disablesleep", "\(desired)"])
            }
            Thread.sleep(forTimeInterval: TimeInterval(pollSeconds))
        }
    }

    private func supportedACKeys() throws -> Set<BuoyPowerKey> {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "cap"])
        return PMSetParser.parseCapabilities(output.stdout)
    }

    private func currentACSettings() throws -> [BuoyPowerKey: Int] {
        PMSetParser.parseCustomSettings(try currentCustomSettings())
    }

    private func currentCustomSettings() throws -> String {
        try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "custom"]).stdout
    }

    private func currentPowerSource() throws -> String {
        PMSetParser.currentPowerSource(try currentBatteryStatus())
    }

    private func currentBatteryStatus() throws -> String {
        try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "batt"]).stdout
    }

    private func currentHasInternalBattery() throws -> Bool? {
        PMSetParser.hasInternalBattery(try currentBatteryStatus())
    }

    private func currentSleepDisabled() throws -> Int? {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g"])
        return PMSetParser.currentSleepDisabled(output.stdout)
    }

    private func currentSleepPreventingAssertions() throws -> [String]? {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "assertions"])
        return PMSetParser.sleepPreventingAssertions(output.stdout)
    }

    private func sudoValidate() throws {
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["-v"], interactive: true)
    }

    private func setACSettings(_ values: [BuoyPowerKey: Int]) throws {
        try setPowerSettings(values, sourceFlag: "-c")
    }

    private func setPowerSettings(_ values: [BuoyPowerKey: Int], sourceFlag: String) throws {
        guard !values.isEmpty else { return }
        var arguments = ["pmset", sourceFlag]
        for key in BuoyPowerKey.allCases {
            guard let value = values[key] else { continue }
            arguments.append(key.rawValue)
            arguments.append(String(value))
        }
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: arguments, interactive: true)
    }

    private func setSleepDisabled(_ value: Int) throws {
        _ = try runner.run(
            executable: "/usr/bin/sudo",
            arguments: ["pmset", "disablesleep", "\(value)"],
            interactive: true
        )
    }

    private func enableClamMonitor(config: BuoyConfig, state: PersistedState) throws -> PersistedState {
        var newState = state
        guard newState.clamOriginalSleepDisabled == 0 else {
            throw BuoyError.commandFailed("Closed-lid mode has no safe SleepDisabled Off baseline.")
        }
        let desired = try desiredSleepDisabled(minBattery: config.clamMinBattery)
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["pmset", "disablesleep", "\(desired)"], interactive: true)

        if let existingPID = newState.clamMonitorPID, try isMonitorRunning(pid: existingPID) {
            _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["kill", "\(existingPID)"], interactive: true)
        }

        let pid = try runner.runDetached(
            executable: "/usr/bin/sudo",
            arguments: [
                "env",
                "BUOY_STATE_DIR=\(stateStore.stateDirectoryURL.path)",
                executablePath,
                "__clam-monitor",
                stateStore.stateFileURL.path,
                String(config.clamMinBattery),
                String(config.clamPollSeconds)
            ],
            environment: nil
        )
        newState.clamMonitorPID = Int(pid)
        return newState
    }

    private func disableClamMonitor(state: PersistedState, dryRun: Bool) throws -> PersistedState {
        var newState = state
        if let monitorPID = newState.clamMonitorPID, try isMonitorRunning(pid: monitorPID), !dryRun {
            _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["kill", "\(monitorPID)"], interactive: true)
        }
        if !dryRun {
            try setSleepDisabled(0)
        }
        newState.clamMonitorPID = nil
        newState.clamOriginalSleepDisabled = nil
        if var config = newState.config {
            config.clamEnabled = false
            newState.config = config
        }
        return newState
    }

    private func desiredSleepDisabled(minBattery: Int) throws -> Int {
        let batteryStatus = try currentBatteryStatus()
        return Self.desiredSleepDisabled(
            powerSource: PMSetParser.currentPowerSource(batteryStatus),
            batteryPercent: PMSetParser.currentBatteryPercentage(batteryStatus),
            minBattery: minBattery
        )
    }

    private func isMonitorRunning(pid: Int) throws -> Bool {
        let output = try runner.run(
            executable: "/bin/ps",
            arguments: ["-p", "\(pid)", "-o", "command="],
            allowNonZeroExit: true
        )
        return output.exitCode == 0 && output.stdout.contains("__clam-monitor")
    }

    private static func restoreSettings(from state: PersistedState) -> [BuoyPowerKey: Int] {
        var values: [BuoyPowerKey: Int] = [:]
        for key in BuoyPowerKey.allCases {
            if let value = state.originalValues[key.rawValue] {
                values[key] = value
            }
        }
        return values
    }

    private static func sleepEnabledSettings(from settings: [BuoyPowerKey: Int]) -> [BuoyPowerKey: Int] {
        var values = settings
        if let sleep = values[.sleep], sleep <= 0 {
            values[.sleep] = safeSleepMinutes
        }
        return values
    }

    private func repairPersistentSleepPolicy() throws {
        try setSleepDisabled(0)

        let customSettings = try currentCustomSettings()
        let ac = PMSetParser.parseCustomSettings(customSettings, section: "AC Power:")
        let battery = PMSetParser.parseCustomSettings(customSettings, section: "Battery Power:")
        try setPowerSettings(Self.repairValues(for: ac), sourceFlag: "-c")
        if !battery.isEmpty {
            try setPowerSettings(Self.repairValues(for: battery), sourceFlag: "-b")
        }
    }

    private static func repairValues(for settings: [BuoyPowerKey: Int]) -> [BuoyPowerKey: Int] {
        var values: [BuoyPowerKey: Int] = [:]
        if let sleep = settings[.sleep], sleep <= 0 {
            values[.sleep] = safeSleepMinutes
        }
        return values
    }

    private func verifySleepEnabledPolicy() throws {
        guard try currentSleepDisabled() == 0 else {
            throw BuoyError.commandFailed("SleepDisabled could not be turned off.")
        }

        let customSettings = try currentCustomSettings()
        let ac = PMSetParser.parseCustomSettings(customSettings, section: "AC Power:")
        guard !ac.isEmpty, (ac[.sleep] ?? 0) > 0 else {
            throw BuoyError.commandFailed("The AC power profile could not be verified with a finite system sleep timer.")
        }

        let battery = PMSetParser.parseCustomSettings(customSettings, section: "Battery Power:")
        guard let hasInternalBattery = try currentHasInternalBattery() else {
            throw BuoyError.commandFailed("Internal battery presence could not be verified.")
        }
        if hasInternalBattery {
            guard !battery.isEmpty, (battery[.sleep] ?? 0) > 0 else {
                throw BuoyError.commandFailed("The battery power profile could not be verified with a finite system sleep timer.")
            }
        }
    }

    private func verifyRestoration(from state: PersistedState) throws {
        try Self.validateRestorePoint(state)
        let expectedAC = Self.sleepEnabledSettings(from: Self.restoreSettings(from: state))
        guard !expectedAC.isEmpty else {
            throw BuoyError.commandFailed(
                "The saved AC restore point is incomplete. Buoy kept the state file for manual recovery."
            )
        }

        try verifyRestoredACSettings(expectedAC)

        guard try currentSleepDisabled() == 0 else {
            throw BuoyError.commandFailed(
                "SleepDisabled restoration could not be verified. Buoy kept the restore state so Turn Off can be retried."
            )
        }
    }

    private func verifyRestoredACSettings(_ expectedAC: [BuoyPowerKey: Int]) throws {
        let actualAC = try currentACSettings()
        let mismatchedKeys = expectedAC.compactMap { key, expected -> String? in
            actualAC[key] == expected ? nil : key.rawValue
        }.sorted()
        if !mismatchedKeys.isEmpty {
            throw BuoyError.commandFailed(
                "Power restoration could not be verified for: \(mismatchedKeys.joined(separator: ", ")). Buoy kept the restore state so Turn Off can be retried."
            )
        }
    }

    private static func sleepAllowed(
        sleepDisabled: Int?,
        systemSleepMinutes: Int?
    ) -> Bool? {
        if sleepDisabled == 1 || systemSleepMinutes == 0 {
            return false
        }
        guard sleepDisabled == 0, let systemSleepMinutes else {
            return nil
        }
        return systemSleepMinutes > 0
    }

    private static func modeState(modeEnabled: Bool) -> BuoyModeState {
        modeEnabled ? .enabled : .disabled
    }

    private static func modeIssues(
        state: PersistedState?,
        monitorRunning: Bool,
        powerSource: String,
        batteryPercent: Int?,
        hasInternalBattery: Bool?,
        sleepDisabled: Int?,
        sleepAllowed: Bool?,
        managedAC: [BuoyPowerKey: Int],
        managedBattery: [BuoyPowerKey: Int]
    ) -> [BuoyModeIssue] {
        guard let state, state.modeEnabled else {
            if sleepAllowed == false || sleepDisabled == 1
                || managedAC[.sleep] == 0
                || (hasInternalBattery != false && managedBattery[.sleep] == 0) {
                return [.sleepStillPrevented]
            }
            let batteryIncomplete = hasInternalBattery != false
                && managedBattery[.sleep] == nil
            if sleepDisabled == nil
                || managedAC[.sleep] == nil
                || hasInternalBattery == nil
                || batteryIncomplete || sleepAllowed == nil {
                return [.sleepStateUnverified]
            }
            return []
        }

        var issues: [BuoyModeIssue] = []
        let configuredKeys = Set(state.configuredValues.keys.compactMap(BuoyPowerKey.init(rawValue:)))
        let originalKeys = Set(state.originalValues.keys.compactMap(BuoyPowerKey.init(rawValue:)))
        let hasUnknownConfiguredKeys = configuredKeys.count != state.configuredValues.count
        if state.config == nil || configuredKeys.isEmpty || hasUnknownConfiguredKeys || !configuredKeys.isSubset(of: originalKeys) {
            issues.append(.restoreStateIncomplete)
        }

        let configuredValues = state.configuredValues.compactMap { rawKey, value -> (BuoyPowerKey, Int)? in
            guard let key = BuoyPowerKey(rawValue: rawKey) else { return nil }
            return (key, value)
        }
        if configuredValues.contains(where: { managedAC[$0.0] != $0.1 }) {
            issues.append(.managedSettingsDrifted)
        }

        if let config = state.config {
            if config.clamEnabled {
                if state.clamOriginalSleepDisabled != 0 {
                    issues.append(.restoreStateIncomplete)
                }
                if !monitorRunning {
                    issues.append(.closedLidMonitorStopped)
                }
                if sleepDisabled == nil {
                    issues.append(.sleepStateUnverified)
                } else if let sleepDisabled {
                    if powerSource == "Battery Power", batteryPercent == nil {
                        issues.append(.sleepStateUnverified)
                    } else {
                        let desired = desiredSleepDisabled(
                            powerSource: powerSource,
                            batteryPercent: batteryPercent,
                            minBattery: config.clamMinBattery
                        )
                        if sleepDisabled != desired {
                            issues.append(.managedSettingsDrifted)
                        }
                    }
                }
            } else if sleepDisabled == nil {
                issues.append(.sleepStateUnverified)
            } else if sleepDisabled != 0 {
                issues.append(.managedSettingsDrifted)
            }
        }

        if sleepAllowed == nil {
            issues.append(.sleepStateUnverified)
        }

        return issues.reduce(into: []) { unique, issue in
            if !unique.contains(issue) {
                unique.append(issue)
            }
        }.sorted { $0.rawValue < $1.rawValue }
    }

    private static func desiredSleepDisabled(
        powerSource: String,
        batteryPercent: Int?,
        minBattery: Int
    ) -> Int {
        if powerSource == "AC Power" {
            return 1
        }
        return (batteryPercent ?? 0) > minBattery ? 1 : 0
    }

    private static func validateRestorePoint(_ state: PersistedState) throws {
        let configuredKeys = Set(state.configuredValues.keys.compactMap(BuoyPowerKey.init(rawValue:)))
        let originalKeys = Set(state.originalValues.keys.compactMap(BuoyPowerKey.init(rawValue:)))
        let missingKeys = configuredKeys.subtracting(originalKeys).map(\.rawValue).sorted()
        let hasUnknownConfiguredKeys = configuredKeys.count != state.configuredValues.count

        guard !configuredKeys.isEmpty, !hasUnknownConfiguredKeys, missingKeys.isEmpty else {
            let detail: String
            if configuredKeys.isEmpty {
                detail = "no managed keys were saved"
            } else if hasUnknownConfiguredKeys {
                detail = "unknown managed keys were saved"
            } else {
                detail = "missing \(missingKeys.joined(separator: ", "))"
            }
            throw BuoyError.commandFailed(
                "The AC restore point is incomplete (\(detail)); no power settings were changed."
            )
        }
    }

    private static func offMessages(status: BuoyStatus, changed: Bool) -> [String] {
        var messages = [changed ? "Buoy mode turned off." : "Buoy mode is already off."]
        messages.append("SleepDisabled is off and finite system sleep timers are enabled.")
        if let assertions = status.system.sleepPreventingAssertions, !assertions.isEmpty {
            messages.append("Info: temporary macOS wake requests remain active: \(assertions.joined(separator: ", ")).")
        }
        return messages
    }

    private static func validate(config: BuoyConfig) throws {
        guard (1...180).contains(config.displaySleepMinutes) else {
            throw BuoyError.invalidArgument("Display sleep must be between 1 and 180 minutes.")
        }
        try validateClam(minBattery: config.clamMinBattery, pollSeconds: config.clamPollSeconds)
    }

    private static func validateClam(minBattery: Int, pollSeconds: Int) throws {
        guard (0...100).contains(minBattery) else {
            throw BuoyError.invalidArgument("Closed-lid battery threshold must be between 0 and 100.")
        }
        guard (5...3600).contains(pollSeconds) else {
            throw BuoyError.invalidArgument("Closed-lid poll interval must be between 5 and 3600 seconds.")
        }
    }

    private static func nowUTC() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private extension Dictionary where Key == BuoyPowerKey, Value == Int {
    func mapKeys<T: Hashable>(_ transform: (BuoyPowerKey) -> T) -> [T: Int] {
        reduce(into: [T: Int]()) { partialResult, element in
            partialResult[transform(element.key)] = element.value
        }
    }
}
