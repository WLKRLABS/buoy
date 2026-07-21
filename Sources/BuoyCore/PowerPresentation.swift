import Foundation

public struct BuoyPowerPresentation: Equatable {
    public var title: String
    public var detail: String
    public var currentState: String
    public var computerSleep: String
    public var displaySleep: String
    public var closedLid: String
    public var modeValue: String
    public var modeDetail: String
    public var sourceDetail: String
}

public enum BuoyPowerPresenter {
    public static func make(status: BuoyStatus?) -> BuoyPowerPresentation {
        guard let status else {
            return BuoyPowerPresentation(
                title: "Checking power state",
                detail: "Buoy is reading the live macOS power settings.",
                currentState: "Checking...",
                computerSleep: "Unverified",
                displaySleep: "Unverified",
                closedLid: "Unverified",
                modeValue: "Checking",
                modeDetail: "Waiting for live power state",
                sourceDetail: "Sleep state unverified"
            )
        }

        let sourceSuffix: String
        switch status.system.powerSource {
        case "AC Power":
            sourceSuffix = " on AC"
        case "Battery Power":
            sourceSuffix = " on battery"
        default:
            sourceSuffix = ""
        }

        let currentState: String
        let computerSleep: String
        let sourceDetail: String
        let assertions = status.system.sleepPreventingAssertions ?? []
        let hasTemporaryWakeRequest = !assertions.isEmpty
        let hasStrongWakeRequest = assertions.contains("PreventSystemSleep") || assertions.contains("KernelPreventSleep")
        let policyNeedsRepair = status.mode.issues.contains(.sleepStillPrevented)
        let policyIsUnverified = status.mode.issues.contains(.sleepStateUnverified)
        if policyNeedsRepair {
            currentState = "Sleep policy needs repair"
            computerSleep = status.system.sleepDisabled == 1 || status.system.systemSleepMinutes == 0
                ? "Never"
                : status.system.systemSleepMinutes.map { "After \($0) min" } ?? "Unverified"
            sourceDetail = "Sleep policy needs repair"
        } else if policyIsUnverified {
            currentState = "Sleep policy unverified"
            computerSleep = status.system.systemSleepMinutes.map { "After \($0) min" } ?? "Unverified"
            sourceDetail = "Sleep policy unverified"
        } else if status.system.sleepAllowed == false {
            currentState = status.system.sleepDisabled == 1
                ? "Closed-lid override active"
                : "Idle sleep set to Never\(sourceSuffix)"
            computerSleep = "Never"
            sourceDetail = status.mode.enabled
                ? "Buoy keep-awake policy active"
                : "Sleep policy needs repair"
        } else if status.system.sleepAllowed == true {
            if hasStrongWakeRequest {
                currentState = "Temporary system wake request active"
            } else if hasTemporaryWakeRequest {
                currentState = "Idle sleep temporarily deferred\(sourceSuffix)"
            } else if let minutes = status.system.systemSleepMinutes {
                currentState = "Sleep after \(minutes) min\(sourceSuffix)"
            } else {
                currentState = "Sleep policy enabled\(sourceSuffix)"
            }
            computerSleep = status.system.systemSleepMinutes.map { "After \($0) min" } ?? "Enabled"
            sourceDetail = hasTemporaryWakeRequest
                ? "Sleep policy enabled · temporary activity"
                : "Sleep policy enabled"
        } else {
            currentState = "Sleep policy unverified"
            computerSleep = "Unverified"
            sourceDetail = "Sleep policy unverified"
        }

        let displaySleep: String
        if let minutes = status.system.displaySleepMinutes {
            displaySleep = minutes == 0 ? "Never" : "After \(minutes) min"
        } else {
            displaySleep = "System profile"
        }

        let closedLid: String
        switch status.system.sleepDisabled {
        case 1:
            closedLid = "Kept awake"
        case 0:
            closedLid = "Sleeps normally"
        default:
            closedLid = "Unverified"
        }

        let title: String
        let detail: String
        let modeValue: String
        let modeDetail: String
        switch status.mode.state {
        case .enabled:
            title = "Buoy mode is on"
            modeValue = "On"
            if status.mode.issues.contains(.closedLidMonitorStopped) {
                detail = "Buoy is on, but the closed-lid helper stopped. Retry Apply Settings or turn the mode off."
                modeDetail = "Buoy on · closed-lid helper needs attention"
            } else if status.mode.issues.contains(.managedSettingsDrifted)
                || status.mode.issues.contains(.restoreStateIncomplete) {
                detail = "Buoy is on, but its saved and live power settings need attention."
                modeDetail = "Buoy on · configuration needs attention"
            } else if status.mode.issues.contains(.sleepStateUnverified) {
                detail = "Buoy is on, but the live macOS sleep policy could not be verified."
                modeDetail = "Buoy on · sleep policy unverified"
            } else {
                detail = "Buoy is keeping the AC power profile awake. The display and closed-lid options follow the settings below."
                modeDetail = "Buoy is managing the keep-awake policy"
            }
        case .disabled:
            title = "Buoy mode is off"
            if status.mode.issues.contains(.sleepStillPrevented) {
                detail = "Buoy is not keeping this Mac awake, but a persistent macOS sleep setting still needs repair. Click Repair Sleep to fix it."
            } else if policyIsUnverified {
                detail = "Buoy mode is off, but the persistent macOS sleep policy is unverified. Click Repair Sleep to retry."
            } else if hasStrongWakeRequest {
                detail = "Sleep policy is enabled, but a temporary system wake request is active."
            } else if hasTemporaryWakeRequest {
                detail = "Sleep policy is enabled. Automatic idle sleep is temporarily deferred by app or system activity; lid-close sleep still works."
            } else {
                detail = "Buoy is not keeping this Mac awake. Sleep timers and lid-close sleep are enabled."
            }
            modeValue = "Off"
            if status.mode.issues.contains(.sleepStillPrevented) {
                modeDetail = "Buoy off · sleep policy needs repair"
            } else if status.mode.issues.contains(.sleepStateUnverified) {
                modeDetail = "Buoy off · sleep policy unverified"
            } else {
                modeDetail = "Buoy is not keeping this Mac awake"
            }
        case .sleepPrevented:
            title = "Buoy mode is off"
            detail = "Buoy is not keeping this Mac awake, but a persistent macOS sleep setting still needs repair. Click Repair Sleep to fix it."
            modeValue = "Off"
            modeDetail = "Buoy off · sleep policy needs repair"
        case .configurationMismatch:
            if status.mode.issues.contains(.closedLidMonitorStopped) {
                title = "Closed-lid monitor stopped"
                detail = "Buoy is enabled, but its helper or live power settings no longer match the saved configuration."
                modeDetail = "Buoy on · saved and live settings disagree"
            } else {
                title = "Buoy configuration mismatch"
                detail = "The saved Buoy policy and live macOS power settings disagree. Refresh or retry the intended action."
                modeDetail = "Buoy on · saved and live settings disagree"
            }
            modeValue = "On"
        case .unverified:
            title = "Buoy mode is on"
            detail = "Buoy is enabled, but the live macOS sleep policy could not be verified."
            modeValue = "On"
            modeDetail = "Buoy on · sleep policy unverified"
        }

        return BuoyPowerPresentation(
            title: title,
            detail: detail,
            currentState: currentState,
            computerSleep: computerSleep,
            displaySleep: displaySleep,
            closedLid: closedLid,
            modeValue: modeValue,
            modeDetail: modeDetail,
            sourceDetail: sourceDetail
        )
    }
}
