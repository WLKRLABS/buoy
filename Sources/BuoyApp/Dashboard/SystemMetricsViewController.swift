import AppKit
import Foundation

public final class SystemMetricsViewController: NSViewController, DashboardConsumer {
    private let textView = NSTextView()
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let intervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cpuCard = DashboardMetricCardView(title: "CPU")
    private let memoryCard = DashboardMetricCardView(title: "Memory")
    private let diskCard = DashboardMetricCardView(title: "Disk")
    private let thermalCard = DashboardMetricCardView(title: "Thermal")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 210, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
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
        let (_, documentView) = installVerticalScrollContainer(in: view)

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

        summaryGrid.setItems([cpuCard, memoryCard, diskCard, thermalCard])

        let summarySection = DashboardSectionView(
            title: "Live System Snapshot",
            subtitle: "Core machine state with the active refresh cadence.",
            accessory: accessory
        )
        summarySection.pinContent(summaryGrid)

        let readoutSection = DashboardSectionView(
            title: "Raw Readout",
            subtitle: "Dense operator view for exact CPU, memory, disk, power, and thermal values."
        )
        readoutSection.pinContent(scroll)

        let stack = NSStackView(views: [summarySection, readoutSection])
        stack.orientation = .vertical
        stack.spacing = 12
        documentView.addSubview(stack)
        stack.pinEdges(
            to: documentView,
            insets: NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        )

        readoutSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
    }

    @objc private func intervalChanged() {
        let idx = intervalPopup.indexOfSelectedItem
        guard idx >= 0, idx < RefreshInterval.allCases.count else { return }
        coordinator?.setInterval(RefreshInterval.allCases[idx])
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        cpuCard.set(
            value: String(format: "%.1f%%", snapshot.cpu.overallPercent),
            detail: snapshot.cpu.frequencyGHz.map { String(format: "%.2f GHz | %d cores", $0, snapshot.cpu.perCorePercent.count) } ?? "\(snapshot.cpu.perCorePercent.count) cores",
            tone: snapshot.cpu.overallPercent > 80 ? .warning : .accent
        )
        memoryCard.set(
            value: String(format: "%.1f%%", snapshot.memory.usagePercent),
            detail: String(format: "%.2f GB used of %.2f GB", snapshot.memory.usedGB, snapshot.memory.totalGB),
            tone: snapshot.memory.usagePercent > 85 ? .warning : .accent
        )
        diskCard.set(
            value: String(format: "%.1f%%", snapshot.disk.usagePercent),
            detail: String(format: "%.2f GB free on %@", snapshot.disk.availableGB, DashboardFormatters.abbreviatedPath(snapshot.disk.mountPoint)),
            tone: snapshot.disk.usagePercent > 90 ? .warning : .accent
        )

        let thermalText: String
        if let temperature = snapshot.thermal.cpuTempCelsius {
            thermalText = String(format: "%.1f °C CPU", temperature)
        } else {
            thermalText = "Unavailable"
        }
        thermalCard.set(
            value: snapshot.thermal.thermalLevel ?? "Nominal",
            detail: thermalText,
            tone: snapshot.thermal.thermalLevel == nil || snapshot.thermal.thermalLevel == "Nominal" ? .accent : .warning
        )

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
