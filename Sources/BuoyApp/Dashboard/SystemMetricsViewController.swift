import AppKit
import Foundation

public final class SystemMetricsViewController: NSViewController, DashboardConsumer {
    private let textView = NSTextView()
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let intervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cpuRow = DashboardMetricRowView(title: "CPU")
    private let memoryRow = DashboardMetricRowView(title: "Memory")
    private let diskRow = DashboardMetricRowView(title: "Disk")
    private let thermalRow = DashboardMetricRowView(title: "Thermal")
    private let factsPanel = DashboardFactsPanelView(title: "Machine Facts")
    weak var coordinator: RefreshCoordinator?

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        if coordinator == nil, let main = parent as? BuoyMainViewController {
            coordinator = main.coordinator
        }
        syncPopup()
    }

    private func syncPopup() {
        guard let coord = coordinator else { return }
        if let idx = RefreshInterval.allCases.firstIndex(of: coord.currentInterval) {
            intervalPopup.selectItem(at: idx)
        }
    }

    private func buildLayout() {
        let (_, _, stack) = installDashboardDocumentStack(in: view)

        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.drawsBackground = false
        textView.textColor = BuoyChrome.primaryTextColor
        textView.textContainerInset = NSSize(width: 4, height: 10)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = textView

        let refreshLabel = NSTextField(labelWithString: "Refresh")
        refreshLabel.font = .systemFont(ofSize: 12)
        refreshLabel.textColor = BuoyChrome.secondaryTextColor

        intervalPopup.addItems(withTitles: RefreshInterval.allCases.map(\.label))
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)

        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        let accessory = NSStackView(views: [refreshLabel, intervalPopup, timestampLabel])
        accessory.orientation = .horizontal
        accessory.alignment = .centerY
        accessory.spacing = 8

        let metricsStack = NSStackView(views: [cpuRow, memoryRow, diskRow, thermalRow])
        metricsStack.orientation = .vertical
        metricsStack.alignment = .width
        metricsStack.spacing = 12
        [cpuRow, memoryRow, diskRow, thermalRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: metricsStack.widthAnchor).isActive = true
        }

        let snapshotStage = DashboardStageView(
            sectionLabel: "Snapshot",
            title: "Current System State",
            subtitle: "Exact machine readouts surfaced as a compact operator board.",
            accessory: accessory
        )
        let snapshotBody = DashboardSplitColumnsView(
            primary: metricsStack,
            secondary: factsPanel,
            collapseWidth: 860,
            preferredSecondaryWidth: 320
        )
        snapshotStage.pinContent(snapshotBody)

        let readoutStage = DashboardStageView(
            sectionLabel: "Inspect",
            title: "Raw Readout",
            subtitle: "Dense operator text stays lower in the layout so the exact values remain available without dominating the page."
        )
        readoutStage.pinContent(scroll)

        stack.addArrangedSubview(snapshotStage)
        stack.addArrangedSubview(readoutStage)
        [snapshotStage, readoutStage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        readoutStage.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
    }

    @objc private func intervalChanged() {
        let idx = intervalPopup.indexOfSelectedItem
        guard idx >= 0, idx < RefreshInterval.allCases.count else { return }
        coordinator?.setInterval(RefreshInterval.allCases[idx])
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        cpuRow.set(
            value: String(format: "%.1f%%", snapshot.cpu.overallPercent),
            detail: snapshot.cpu.frequencyGHz.map { String(format: "%.2f GHz | %d cores", $0, snapshot.cpu.perCorePercent.count) } ?? "\(snapshot.cpu.perCorePercent.count) cores",
            progress: snapshot.cpu.overallPercent,
            tone: snapshot.cpu.overallPercent > 80 ? .warning : .accent
        )
        memoryRow.set(
            value: String(format: "%.1f%%", snapshot.memory.usagePercent),
            detail: String(format: "%.2f GB used of %.2f GB", snapshot.memory.usedGB, snapshot.memory.totalGB),
            progress: snapshot.memory.usagePercent,
            tone: snapshot.memory.usagePercent > 85 ? .warning : .accent
        )
        diskRow.set(
            value: String(format: "%.1f%%", snapshot.disk.usagePercent),
            detail: String(format: "%.2f GB free on %@", snapshot.disk.availableGB, DashboardFormatters.abbreviatedPath(snapshot.disk.mountPoint)),
            progress: snapshot.disk.usagePercent,
            tone: snapshot.disk.usagePercent > 90 ? .warning : .accent
        )

        let thermalText: String
        if let temperature = snapshot.thermal.cpuTempCelsius {
            thermalText = String(format: "%.1f °C CPU", temperature)
        } else {
            thermalText = "Unavailable"
        }
        thermalRow.set(
            value: snapshot.thermal.thermalLevel ?? "Nominal",
            detail: thermalText,
            progress: snapshot.thermal.cpuTempCelsius ?? 0,
            tone: snapshot.thermal.thermalLevel == nil || snapshot.thermal.thermalLevel == "Nominal" ? .accent : .warning
        )

        factsPanel.setRows([
            ("Refresh", coordinator?.currentInterval.label ?? RefreshInterval.twoSeconds.label),
            ("Power Source", snapshot.power.powerSource),
            ("Charge", snapshot.power.batteryPercent.map { "\($0)%" } ?? "No battery"),
            ("Time Remaining", DashboardFormatters.duration(minutes: snapshot.power.timeRemainingMinutes)),
            ("Condition", snapshot.power.condition ?? "Unavailable"),
            ("CPU Temp", snapshot.thermal.cpuTempCelsius.map { String(format: "%.1f C", $0) } ?? "Unavailable"),
            ("Battery Temp", snapshot.thermal.batteryTempCelsius.map { String(format: "%.1f C", $0) } ?? "Unavailable"),
            ("Wattage", snapshot.power.wattageDraw.map { String(format: "%.2f W", $0) } ?? "Unavailable")
        ])

        var lines: [String] = []
        lines.append("══ CPU ═════════════════════════════════")
        lines.append(String(format: "overall      %6.1f %%", snapshot.cpu.overallPercent))
        if let frequency = snapshot.cpu.frequencyGHz {
            lines.append(String(format: "frequency    %6.2f GHz", frequency))
        } else {
            lines.append("frequency    unavailable")
        }
        for (index, value) in snapshot.cpu.perCorePercent.enumerated() {
            lines.append(String(format: "core %02d      %6.1f %%", index, value))
        }

        lines.append("")
        lines.append("══ MEMORY ═════════════════════════════")
        lines.append(String(format: "total        %7.2f GB", snapshot.memory.totalGB))
        lines.append(String(format: "used         %7.2f GB", snapshot.memory.usedGB))
        lines.append(String(format: "available    %7.2f GB", snapshot.memory.availableGB))
        lines.append(String(format: "pressure     %6.1f %%", snapshot.memory.usagePercent))

        lines.append("")
        lines.append("══ DISK ═══════════════════════════════")
        lines.append("mount        \(snapshot.disk.mountPoint)")
        lines.append(String(format: "total        %7.2f GB", snapshot.disk.totalGB))
        lines.append(String(format: "used         %7.2f GB", snapshot.disk.usedGB))
        lines.append(String(format: "available    %7.2f GB", snapshot.disk.availableGB))
        lines.append(String(format: "pressure     %6.1f %%", snapshot.disk.usagePercent))

        lines.append("")
        lines.append("══ POWER ══════════════════════════════")
        lines.append("source       \(snapshot.power.powerSource)")
        lines.append("charge       \(snapshot.power.batteryPercent.map { "\($0) %" } ?? "n/a")")
        lines.append("status       \(chargingStatus(for: snapshot.power))")
        lines.append("time left    \(DashboardFormatters.duration(minutes: snapshot.power.timeRemainingMinutes))")
        lines.append("condition    \(snapshot.power.condition ?? "—")")
        lines.append("wattage      \(snapshot.power.wattageDraw.map { String(format: "%.2f W", $0) } ?? "—")")

        lines.append("")
        lines.append("══ THERMAL ════════════════════════════")
        lines.append("cpu temp     \(snapshot.thermal.cpuTempCelsius.map { String(format: "%.1f °C", $0) } ?? "unavailable")")
        lines.append("battery temp \(snapshot.thermal.batteryTempCelsius.map { String(format: "%.1f °C", $0) } ?? "unavailable")")
        lines.append("pressure     \(snapshot.thermal.thermalLevel ?? "Nominal")")

        textView.string = lines.joined(separator: "\n")
        timestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }

    private func chargingStatus(for power: PowerSnapshot) -> String {
        if power.isCharging {
            return "Charging"
        }
        if power.batteryPercent == 100, power.powerSource.localizedCaseInsensitiveContains("AC") {
            return "Charged"
        }
        return "Not charging"
    }
}
