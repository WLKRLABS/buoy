import AppKit
import Foundation

public final class OverviewViewController: NSViewController, DashboardConsumer {
    private let cpuCard = OverviewGaugeCardView(title: "CPU")
    private let memoryCard = OverviewGaugeCardView(title: "Memory")
    private let diskCard = OverviewGaugeCardView(title: "Disk")
    private let batteryCard = OverviewGaugeCardView(title: "Battery")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 200, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let leadersGrid = AdaptiveGridView(minColumnWidth: 320, maxColumns: 2, rowSpacing: 12, columnSpacing: 12)
    private let powerFacts = OverviewFactsView()
    private let topCPUText = NSTextField(wrappingLabelWithString: "Waiting for live data.")
    private let topMemoryText = NSTextField(wrappingLabelWithString: "Waiting for live data.")
    private let timestampLabel = NSTextField(labelWithString: "—")

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        let (_, documentView) = installVerticalScrollContainer(in: view)

        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        [topCPUText, topMemoryText].forEach {
            $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            $0.maximumNumberOfLines = 8
            $0.textColor = BuoyChrome.primaryTextColor
        }

        summaryGrid.setItems([cpuCard, memoryCard, diskCard, batteryCard])

        let summarySection = DashboardSectionView(
            title: "Live Summary",
            subtitle: "Most important machine signals, condensed for quick scanning.",
            accessory: timestampLabel
        )
        summarySection.pinContent(summaryGrid)

        leadersGrid.setItems([
            OverviewListPanel(title: "Top CPU Processes", content: topCPUText),
            OverviewListPanel(title: "Top Memory Processes", content: topMemoryText)
        ])

        let leadersSection = DashboardSectionView(
            title: "Activity Leaders",
            subtitle: "Current outliers by processor and memory pressure."
        )
        leadersSection.pinContent(leadersGrid)

        let powerSection = DashboardSectionView(
            title: "Power And Thermal",
            subtitle: "Power source, battery condition, and thermal pressure."
        )
        powerSection.pinContent(powerFacts)

        let stack = NSStackView(views: [summarySection, leadersSection, powerSection])
        stack.orientation = .vertical
        stack.spacing = 12
        documentView.addSubview(stack)
        stack.pinEdges(
            to: documentView,
            insets: NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        )
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        cpuCard.set(
            value: String(format: "%.0f%%", snapshot.cpu.overallPercent),
            detail: snapshot.cpu.frequencyGHz.map { String(format: "%.2f GHz | %d cores", $0, snapshot.cpu.perCorePercent.count) } ?? "\(snapshot.cpu.perCorePercent.count) cores",
            progress: snapshot.cpu.overallPercent,
            tone: snapshot.cpu.overallPercent > 80 ? .warning : .accent
        )

        memoryCard.set(
            value: String(format: "%.0f%%", snapshot.memory.usagePercent),
            detail: String(format: "%.1f GB used of %.1f GB", snapshot.memory.usedGB, snapshot.memory.totalGB),
            progress: snapshot.memory.usagePercent,
            tone: snapshot.memory.usagePercent > 85 ? .warning : .accent
        )

        diskCard.set(
            value: String(format: "%.0f%%", snapshot.disk.usagePercent),
            detail: String(format: "%.1f GB free on %@", snapshot.disk.availableGB, DashboardFormatters.abbreviatedPath(snapshot.disk.mountPoint)),
            progress: snapshot.disk.usagePercent,
            tone: snapshot.disk.usagePercent > 90 ? .warning : .accent
        )

        if let batteryPercent = snapshot.power.batteryPercent {
            let batteryDetail = [
                snapshot.power.powerSource,
                snapshot.power.timeRemainingMinutes.map { DashboardFormatters.duration(minutes: $0) }
            ]
                .compactMap { $0 }
                .joined(separator: " | ")
            batteryCard.set(
                value: "\(batteryPercent)%",
                detail: batteryDetail.isEmpty ? "Battery status available" : batteryDetail,
                progress: Double(batteryPercent),
                tone: batteryPercent < 20 ? .warning : .accent
            )
        } else {
            batteryCard.set(
                value: "—",
                detail: snapshot.power.powerSource,
                progress: 0,
                tone: .neutral
            )
        }

        let topCPU = snapshot.processes
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(6)
            .map { String(format: "%-18s %6.1f%%", ($0.name as NSString).utf8String!, $0.cpuPercent) }
            .joined(separator: "\n")
        topCPUText.stringValue = topCPU.isEmpty ? "No process data." : topCPU

        let topMemory = snapshot.processes
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(6)
            .map { String(format: "%-18s %7.1f MB", ($0.name as NSString).utf8String!, $0.memoryMB) }
            .joined(separator: "\n")
        topMemoryText.stringValue = topMemory.isEmpty ? "No process data." : topMemory

        powerFacts.setRows([
            ("Power Source", snapshot.power.powerSource),
            ("Charge", snapshot.power.batteryPercent.map { "\($0)%" } ?? "No battery"),
            ("Time Remaining", DashboardFormatters.duration(minutes: snapshot.power.timeRemainingMinutes)),
            ("Condition", snapshot.power.condition ?? "—"),
            ("CPU Temperature", snapshot.thermal.cpuTempCelsius.map { String(format: "%.1f °C", $0) } ?? "Unavailable"),
            ("Battery Temperature", snapshot.thermal.batteryTempCelsius.map { String(format: "%.1f °C", $0) } ?? "Unavailable"),
            ("Thermal Pressure", snapshot.thermal.thermalLevel ?? "Nominal"),
            ("Wattage Draw", snapshot.power.wattageDraw.map { String(format: "%.2f W", $0) } ?? "—")
        ])

        timestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }
}

private final class OverviewGaugeCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let barBackground = NSView()
    private let barFill = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?
    private var currentProgress: Double = 0
    private var currentTone: DashboardMetricTone = .accent

    init(title: String) {
        super.init(frame: .zero)
        applyBuoySurface()

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        valueLabel.font = .buoyMetricValueFont()
        valueLabel.textColor = BuoyChrome.primaryTextColor

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = BuoyChrome.secondaryTextColor
        detailLabel.maximumNumberOfLines = 2

        barBackground.wantsLayer = true
        barBackground.layer?.cornerRadius = 3
        barBackground.layer?.backgroundColor = BuoyChrome.gridColor.cgColor

        barFill.wantsLayer = true
        barFill.layer?.cornerRadius = 3
        barFill.layer?.backgroundColor = BuoyChrome.accentColor.cgColor

        barBackground.addSubview(barFill)
        barFill.translatesAutoresizingMaskIntoConstraints = false
        fillWidthConstraint = barFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            barFill.leadingAnchor.constraint(equalTo: barBackground.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barBackground.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barBackground.bottomAnchor)
        ])

        let stack = NSStackView(views: [titleLabel, valueLabel, detailLabel, barBackground])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        addSubview(stack)
        stack.pinEdges(
            to: self,
            insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
            barBackground.heightAnchor.constraint(equalToConstant: 6),
            barBackground.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        barFill.layer?.cornerRadius = 3
        updateBarFill()
    }

    func set(value: String, detail: String, progress: Double, tone: DashboardMetricTone) {
        valueLabel.stringValue = value
        detailLabel.stringValue = detail
        currentProgress = progress
        currentTone = tone
        updateBarFill()
    }

    private func updateBarFill() {
        let clamped = min(max(currentProgress, 0), 100)
        let usableWidth = max(0, barBackground.bounds.width)
        fillWidthConstraint?.constant = clamped == 0 ? 0 : max(6, usableWidth * CGFloat(clamped / 100))
        barFill.layer?.backgroundColor = currentTone.color.cgColor
    }
}

private final class OverviewListPanel: NSView {
    init(title: String, content: NSTextField) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 8, fillColor: BuoyChrome.elevatedBackgroundColor)

        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        let stack = NSStackView(views: [titleLabel, content])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        addSubview(stack)
        stack.pinEdges(
            to: self,
            insets: NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

private final class OverviewFactsView: NSView {
    private let stack = NSStackView()
    private var rows: [NSView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        stack.orientation = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.pinEdges(to: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setRows(_ values: [(String, String)]) {
        rows.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rows.removeAll()

        for (labelText, valueText) in values {
            let label = NSTextField(labelWithString: labelText)
            label.font = .systemFont(ofSize: 12)
            label.textColor = BuoyChrome.secondaryTextColor

            let value = NSTextField(labelWithString: valueText)
            value.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            value.textColor = BuoyChrome.primaryTextColor
            value.alignment = .right
            value.lineBreakMode = .byTruncatingMiddle

            let row = NSStackView(views: [label, NSView(), value])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            stack.addArrangedSubview(row)
            rows.append(row)
        }
    }
}
