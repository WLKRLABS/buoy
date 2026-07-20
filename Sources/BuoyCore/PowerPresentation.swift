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
        switch status.system.sleepAllowed {
        case .some(false):
            currentState = "Prevented now\(sourceSuffix)"
            computerSleep = "Prevented"
            sourceDetail = "System sleep currently prevented"
        case .some(true):
            currentState = "Allowed now\(sourceSuffix)"
            computerSleep = "Allowed"
            sourceDetail = "System sleep currently allowed"
        case .none:
            currentState = "Unverified"
            computerSleep = "Unverified"
            sourceDetail = "Sleep state unverified"
        }

        let displaySleep: String
        if status.system.powerSource == "AC Power", let minutes = status.managedAC[BuoyPowerKey.displaysleep.rawValue] {
            displaySleep = minutes == 0 ? "Never" : "After \(minutes) min"
        } else {
            displaySleep = "System profile"
        }

        let closedLid: String
        switch status.system.sleepDisabled {
        case 1:
            closedLid = "Sleep disabled"
        case 0:
            closedLid = "Override off"
        default:
            closedLid = "Unverified"
        }

        let title: String
        let detail: String
        let modeValue: String
        let modeDetail: String
        switch status.mode.state {
        case .enabled:
            title = status.system.sleepAllowed == false ? "System sleep is prevented" : "Buoy mode is enabled"
            detail = "Buoy owns the saved power policy. The live state shown below is authoritative for the current power source."
            modeValue = "Enabled"
            modeDetail = status.system.sleepAllowed == false
                ? "Live settings prevent system sleep"
                : "Current profile permits system sleep"
        case .disabled:
            title = "System sleep is allowed"
            detail = "Buoy is off and the live macOS power profile currently allows system sleep."
            modeValue = "Off"
            modeDetail = "Live sleep settings verified"
        case .sleepPrevented:
            if status.system.sleepAllowed == false {
                title = "Sleep is still prevented"
                detail = "Buoy restore state is off, but live macOS settings or assertions still prevent system sleep."
                modeDetail = "Buoy off · system sleep prevented"
            } else {
                title = "A sleep-disabled profile remains"
                detail = "Buoy restore state is off, but a live macOS power profile still disables system sleep."
                modeDetail = "Buoy off · disabled profile remains"
            }
            modeValue = "Sleep Prevented"
        case .configurationMismatch:
            if status.mode.issues.contains(.closedLidMonitorStopped) {
                title = "Closed-lid monitor stopped"
                detail = "Buoy is enabled, but its helper or live power settings no longer match the saved configuration."
                modeDetail = "Saved and live settings disagree"
            } else {
                title = "Buoy configuration mismatch"
                detail = "The saved Buoy policy and live macOS power settings disagree. Refresh or retry the intended action."
                modeDetail = "Saved and live settings disagree"
            }
            modeValue = "Mismatch"
        case .unverified:
            title = "Sleep state unverified"
            detail = "Buoy could not confirm the live macOS sleep settings, so it will not claim that sleep is restored."
            modeValue = "Unverified"
            modeDetail = "Live sleep state unavailable"
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
