import AppKit
import Foundation

private struct OverviewHistorySample {
    let capturedAt: Date
    let cpuPercent: Double
    let memoryPercent: Double
    let batteryPercent: Double?
    let wattageDraw: Double?
    let cpuTempCelsius: Double?
    let batteryTempCelsius: Double?
}

private struct OverviewProcessDisplayRow {
    let name: String
    let valueText: String
    let detailText: String
}

private struct OverviewPosture {
    let badge: String
    let title: String
    let detail: String
    let tone: DashboardMetricTone
}

public final class OverviewViewController: NSViewController, DashboardConsumer {
    private let currentTimestampLabel = NSTextField(labelWithString: "Awaiting first sample")
    private let historyWindowLabel = NSTextField(labelWithString: "Collecting samples")
    private let postureBadge = OverviewToneBadgeView()
    private let postureTitleLabel = NSTextField(labelWithString: "Waiting for live data")
    private let postureDetailLabel = NSTextField(wrappingLabelWithString: "Buoy will assemble the current machine story as soon as the first dashboard snapshot arrives.")

    private let cpuStateView = OverviewStateCellView(title: "CPU")
    private let memoryStateView = OverviewStateCellView(title: "Memory")
    private let diskStateView = OverviewStateCellView(title: "Disk")
    private let batteryStateView = OverviewStateCellView(title: "Battery")
    private let operationalNotesPanel = OverviewFactsPanelView(title: "Operational Notes")

    private let cpuTrendCard = OverviewTrendCardView()
    private let memoryTrendCard = OverviewTrendCardView()
    private let thermalTrendCard = OverviewTrendCardView()
    private let powerTrendCard = OverviewTrendCardView()

    private let cpuLeadersPanel = OverviewProcessListView(title: "Top CPU Processes")
    private let memoryLeadersPanel = OverviewProcessListView(title: "Top Memory Processes")
    private let machineFactsPanel = OverviewFactsPanelView(title: "Power And Thermal Facts")

    private var history: [OverviewHistorySample] = []
    private let historyWindow: TimeInterval = 8 * 60
    private let maxHistorySamples = 240

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        seedPlaceholderState()
    }

    private func buildLayout() {
        let (_, documentView) = installVerticalScrollContainer(in: view)

        currentTimestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        currentTimestampLabel.textColor = BuoyChrome.secondaryTextColor

        historyWindowLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        historyWindowLabel.textColor = BuoyChrome.secondaryTextColor

        postureTitleLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        postureTitleLabel.textColor = BuoyChrome.primaryTextColor
        postureTitleLabel.maximumNumberOfLines = 2

        postureDetailLabel.font = .systemFont(ofSize: 13)
        postureDetailLabel.textColor = BuoyChrome.secondaryTextColor
        postureDetailLabel.maximumNumberOfLines = 3

        let metricsStack = NSStackView(views: [cpuStateView, memoryStateView, diskStateView, batteryStateView])
        metricsStack.orientation = .vertical
        metricsStack.alignment = .leading
        metricsStack.spacing = 12
        [cpuStateView, memoryStateView, diskStateView, batteryStateView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: metricsStack.widthAnchor).isActive = true
        }

        let postureHeader = NSStackView(views: [postureBadge, postureTitleLabel])
        postureHeader.orientation = .horizontal
        postureHeader.alignment = .centerY
        postureHeader.spacing = 12

        let summaryColumn = NSStackView(views: [postureHeader, postureDetailLabel, metricsStack])
        summaryColumn.orientation = .vertical
        summaryColumn.alignment = .leading
        summaryColumn.spacing = 16
        postureDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        metricsStack.translatesAutoresizingMaskIntoConstraints = false
        postureDetailLabel.widthAnchor.constraint(equalTo: summaryColumn.widthAnchor).isActive = true
        metricsStack.widthAnchor.constraint(equalTo: summaryColumn.widthAnchor).isActive = true

        let currentStateBody = AdaptiveColumnsView(
            primary: summaryColumn,
            secondary: operationalNotesPanel,
            collapseWidth: 760,
            preferredSecondaryWidth: 320
        )

        let currentStage = OverviewStageView(
            sectionLabel: "Now",
            title: "Current Machine State",
            subtitle: "The machine right now, arranged to be trusted at a glance.",
            accessory: currentTimestampLabel
        )
        currentStage.pinContent(currentStateBody)

        let trendsGrid = AdaptiveGridView(minColumnWidth: 280, maxColumns: 2, rowSpacing: 14, columnSpacing: 14)
        trendsGrid.setItems([cpuTrendCard, memoryTrendCard, thermalTrendCard, powerTrendCard])

        let trendsStage = OverviewStageView(
            sectionLabel: "Behavior",
            title: "Recent Behavior",
            subtitle: "Short rolling histories show how the system has been behaving, not just what it says now.",
            accessory: historyWindowLabel
        )
        trendsStage.pinContent(trendsGrid)

        let inspectionGrid = AdaptiveGridView(minColumnWidth: 280, maxColumns: 3, rowSpacing: 14, columnSpacing: 14)
        inspectionGrid.setItems([cpuLeadersPanel, memoryLeadersPanel, machineFactsPanel])

        let inspectionStage = OverviewStageView(
            sectionLabel: "Inspection",
            title: "Lower-Priority Details",
            subtitle: "Deeper process and power detail stays lower in the layout so it remains available without competing."
        )
        inspectionStage.pinContent(inspectionGrid)

        let stack = NSStackView(views: [currentStage, trendsStage, inspectionStage])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        [currentStage, trendsStage, inspectionStage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let fillWidthConstraint = stack.widthAnchor.constraint(equalTo: documentView.widthAnchor, constant: -56)
        fillWidthConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 1220),
            fillWidthConstraint
        ])
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        appendHistory(snapshot)

        let topCPU = snapshot.processes.max { $0.cpuPercent < $1.cpuPercent }
        let topMemory = snapshot.processes.max { $0.memoryMB < $1.memoryMB }
        let posture = posture(for: snapshot, topCPU: topCPU)

        postureBadge.set(text: posture.badge, tone: posture.tone)
        postureTitleLabel.stringValue = posture.title
        postureDetailLabel.stringValue = posture.detail

        cpuStateView.set(
            value: percentString(snapshot.cpu.overallPercent, decimals: 0),
            detail: snapshot.cpu.frequencyGHz.map {
                String(format: "%.2f GHz | %d cores", $0, snapshot.cpu.perCorePercent.count)
            } ?? "\(snapshot.cpu.perCorePercent.count) cores",
            progress: snapshot.cpu.overallPercent,
            tone: tone(for: snapshot.cpu.overallPercent, warning: 70, critical: 90)
        )

        memoryStateView.set(
            value: percentString(snapshot.memory.usagePercent, decimals: 0),
            detail: String(format: "%.1f GB used of %.1f GB", snapshot.memory.usedGB, snapshot.memory.totalGB),
            progress: snapshot.memory.usagePercent,
            tone: tone(for: snapshot.memory.usagePercent, warning: 78, critical: 90)
        )

        diskStateView.set(
            value: percentString(snapshot.disk.usagePercent, decimals: 0),
            detail: "\(DashboardFormatters.bytes(DashboardFormatters.storageBytes(from: snapshot.disk.availableGB))) free on \(DashboardFormatters.abbreviatedPath(snapshot.disk.mountPoint))",
            progress: snapshot.disk.usagePercent,
            tone: tone(for: snapshot.disk.usagePercent, warning: 85, critical: 94)
        )

        if let batteryPercent = snapshot.power.batteryPercent {
            let batteryDetail = [
                snapshot.power.powerSource,
                snapshot.power.timeRemainingMinutes.map { DashboardFormatters.duration(minutes: $0) }
            ]
                .compactMap { $0 }
                .joined(separator: " | ")

            batteryStateView.set(
                value: "\(batteryPercent)%",
                detail: batteryDetail.isEmpty ? "Battery status available" : batteryDetail,
                progress: Double(batteryPercent),
                tone: batteryTone(for: snapshot)
            )
        } else if let wattage = snapshot.power.wattageDraw {
            batteryStateView.set(
                value: String(format: "%.1f W", wattage),
                detail: "\(snapshot.power.powerSource) draw",
                progress: 0,
                tone: .neutral
            )
        } else {
            batteryStateView.set(
                value: "N/A",
                detail: snapshot.power.powerSource,
                progress: 0,
                tone: .neutral
            )
        }

        operationalNotesPanel.setRows([
            ("Power", snapshot.power.powerSource),
            ("Thermal", snapshot.thermal.thermalLevel ?? "Nominal"),
            ("Top CPU", processSummary(topCPU, metric: { percentString($0.cpuPercent, decimals: 1) })),
            ("Top Memory", processSummary(topMemory, metric: { memoryFootprint($0.memoryMB) })),
            (snapshot.power.batteryPercent != nil ? "Charge" : "Draw", powerSummary(snapshot))
        ])

        updateTrendCards(for: snapshot)

        cpuLeadersPanel.setRows(processRows(from: snapshot.processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(6), metric: {
            percentString($0.cpuPercent, decimals: 1)
        }))
        memoryLeadersPanel.setRows(processRows(from: snapshot.processes.sorted { $0.memoryMB > $1.memoryMB }.prefix(6), metric: {
            memoryFootprint($0.memoryMB)
        }))

        machineFactsPanel.setRows([
            ("Power Source", snapshot.power.powerSource),
            ("Charge", snapshot.power.batteryPercent.map { "\($0)%" } ?? "No battery"),
            ("Time Remaining", DashboardFormatters.duration(minutes: snapshot.power.timeRemainingMinutes)),
            ("Condition", snapshot.power.condition ?? "Unavailable"),
            ("CPU Temp", snapshot.thermal.cpuTempCelsius.map { temperatureString($0) } ?? "Unavailable"),
            ("Battery Temp", snapshot.thermal.batteryTempCelsius.map { temperatureString($0) } ?? "Unavailable"),
            ("Thermal Pressure", snapshot.thermal.thermalLevel ?? "Nominal"),
            ("Wattage Draw", snapshot.power.wattageDraw.map { String(format: "%.2f W", $0) } ?? "Unavailable")
        ])

        currentTimestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
        historyWindowLabel.stringValue = historySummary()
    }

    private func seedPlaceholderState() {
        postureBadge.set(text: "Standby", tone: .neutral)

        cpuStateView.set(value: "0%", detail: "Waiting for live data", progress: 0, tone: .neutral)
        memoryStateView.set(value: "0%", detail: "Waiting for live data", progress: 0, tone: .neutral)
        diskStateView.set(value: "0%", detail: "Waiting for live data", progress: 0, tone: .neutral)
        batteryStateView.set(value: "N/A", detail: "Waiting for live data", progress: 0, tone: .neutral)

        operationalNotesPanel.setRows([("Status", "Waiting for the first machine snapshot")])
        machineFactsPanel.setRows([("Status", "Waiting for the first machine snapshot")])
        cpuLeadersPanel.setRows([])
        memoryLeadersPanel.setRows([])

        cpuTrendCard.set(
            title: "CPU Load",
            value: "No data",
            detail: "Collecting recent history.",
            samples: [],
            domain: nil,
            tone: .neutral
        )
        memoryTrendCard.set(
            title: "Memory Use",
            value: "No data",
            detail: "Collecting recent history.",
            samples: [],
            domain: nil,
            tone: .neutral
        )
        thermalTrendCard.set(
            title: "Thermal",
            value: "No data",
            detail: "Collecting temperature telemetry.",
            samples: [],
            domain: nil,
            tone: .neutral
        )
        powerTrendCard.set(
            title: "Power",
            value: "No data",
            detail: "Collecting power telemetry.",
            samples: [],
            domain: nil,
            tone: .neutral
        )
    }

    private func appendHistory(_ snapshot: DashboardSnapshot) {
        history.append(
            OverviewHistorySample(
                capturedAt: snapshot.capturedAt,
                cpuPercent: snapshot.cpu.overallPercent,
                memoryPercent: snapshot.memory.usagePercent,
                batteryPercent: snapshot.power.batteryPercent.map(Double.init),
                wattageDraw: snapshot.power.wattageDraw,
                cpuTempCelsius: snapshot.thermal.cpuTempCelsius,
                batteryTempCelsius: snapshot.thermal.batteryTempCelsius
            )
        )

        let cutoff = snapshot.capturedAt.addingTimeInterval(-historyWindow)
        history.removeAll { $0.capturedAt < cutoff }

        if history.count > maxHistorySamples {
            history.removeFirst(history.count - maxHistorySamples)
        }
    }

    private func updateTrendCards(for snapshot: DashboardSnapshot) {
        let cpuSamples = history.map(\.cpuPercent)
        cpuTrendCard.set(
            title: "CPU Load",
            value: percentString(snapshot.cpu.overallPercent, decimals: 0),
            detail: averagePeakSummary(samples: cpuSamples, formatter: { percentString($0, decimals: 0) }),
            samples: cpuSamples,
            domain: 0...100,
            tone: tone(for: snapshot.cpu.overallPercent, warning: 70, critical: 90)
        )

        let memorySamples = history.map(\.memoryPercent)
        memoryTrendCard.set(
            title: "Memory Use",
            value: percentString(snapshot.memory.usagePercent, decimals: 0),
            detail: averagePeakSummary(samples: memorySamples, formatter: { percentString($0, decimals: 0) }),
            samples: memorySamples,
            domain: 0...100,
            tone: tone(for: snapshot.memory.usagePercent, warning: 78, critical: 90)
        )

        let thermalSamples = history.compactMap { $0.cpuTempCelsius ?? $0.batteryTempCelsius }
        let currentThermal = snapshot.thermal.cpuTempCelsius ?? snapshot.thermal.batteryTempCelsius
        let thermalDetail: String
        if thermalSamples.isEmpty {
            thermalDetail = "No recent temperature telemetry."
        } else {
            thermalDetail = [
                snapshot.thermal.thermalLevel ?? "Nominal",
                "Peak \(temperatureString(thermalSamples.max() ?? 0))"
            ].joined(separator: " | ")
        }
        thermalTrendCard.set(
            title: "Thermal",
            value: currentThermal.map(temperatureString) ?? "Unavailable",
            detail: thermalDetail,
            samples: thermalSamples,
            domain: thermalDomain(for: thermalSamples),
            tone: thermalTone(for: snapshot)
        )

        if let batteryPercent = snapshot.power.batteryPercent {
            let batterySamples = history.compactMap(\.batteryPercent)
            powerTrendCard.set(
                title: "Battery",
                value: "\(batteryPercent)%",
                detail: [
                    snapshot.power.powerSource,
                    batterySamples.isEmpty ? nil : "Avg \(percentString(batterySamples.reduce(0, +) / Double(batterySamples.count), decimals: 0))"
                ]
                    .compactMap { $0 }
                    .joined(separator: " | "),
                samples: batterySamples,
                domain: 0...100,
                tone: batteryTone(for: snapshot)
            )
        } else if let wattageDraw = snapshot.power.wattageDraw {
            let wattageSamples = history.compactMap(\.wattageDraw)
            powerTrendCard.set(
                title: "Power Draw",
                value: String(format: "%.1f W", wattageDraw),
                detail: [
                    snapshot.power.powerSource,
                    wattageSamples.isEmpty ? nil : "Avg \(String(format: "%.1f W", wattageSamples.reduce(0, +) / Double(wattageSamples.count)))"
                ]
                    .compactMap { $0 }
                    .joined(separator: " | "),
                samples: wattageSamples,
                domain: wattageDomain(for: wattageSamples),
                tone: .accent
            )
        } else {
            powerTrendCard.set(
                title: "Power",
                value: "No data",
                detail: "Battery and wattage telemetry unavailable.",
                samples: [],
                domain: nil,
                tone: .neutral
            )
        }
    }

    private func posture(for snapshot: DashboardSnapshot, topCPU: ProcessInfoRow?) -> OverviewPosture {
        let thermalLabel = snapshot.thermal.thermalLevel ?? "Nominal"
        let mostActiveText = processSummary(topCPU, metric: { percentString($0.cpuPercent, decimals: 0) })

        if thermalTone(for: snapshot) != .accent {
            return OverviewPosture(
                badge: "Watch",
                title: "Thermal pressure is elevated",
                detail: "\(snapshot.power.powerSource). \(thermalLabel). Most active: \(mostActiveText).",
                tone: thermalTone(for: snapshot)
            )
        }

        if snapshot.cpu.overallPercent >= 85 || snapshot.memory.usagePercent >= 88 {
            return OverviewPosture(
                badge: "Busy",
                title: "Load is elevated right now",
                detail: "CPU \(percentString(snapshot.cpu.overallPercent, decimals: 0)) and memory \(percentString(snapshot.memory.usagePercent, decimals: 0)). Most active: \(mostActiveText).",
                tone: .warning
            )
        }

        if snapshot.disk.usagePercent >= 92 {
            return OverviewPosture(
                badge: "Tight",
                title: "Storage is getting tight",
                detail: "\(DashboardFormatters.bytes(DashboardFormatters.storageBytes(from: snapshot.disk.availableGB))) remain on \(DashboardFormatters.abbreviatedPath(snapshot.disk.mountPoint)).",
                tone: .warning
            )
        }

        if batteryTone(for: snapshot) != .accent && snapshot.power.batteryPercent != nil {
            return OverviewPosture(
                badge: "Battery",
                title: "Running on battery reserve",
                detail: "\(powerSummary(snapshot)). Thermal \(thermalLabel.lowercased()). Most active: \(mostActiveText).",
                tone: batteryTone(for: snapshot)
            )
        }

        let title: String
        if snapshot.power.powerSource.localizedCaseInsensitiveContains("AC") {
            title = "Stable on AC"
        } else if snapshot.power.batteryPercent != nil {
            title = "Running steadily on battery"
        } else {
            title = "System is steady"
        }

        return OverviewPosture(
            badge: "Ready",
            title: title,
            detail: "\(thermalLabel). Most active: \(mostActiveText).",
            tone: .accent
        )
    }

    private func processRows<S: Sequence>(
        from processes: S,
        metric: (ProcessInfoRow) -> String
    ) -> [OverviewProcessDisplayRow] where S.Element == ProcessInfoRow {
        let rows = Array(processes)
        guard !rows.isEmpty else { return [] }

        return rows.map {
            OverviewProcessDisplayRow(
                name: $0.name,
                valueText: metric($0),
                detailText: "PID \($0.pid) | \($0.user) | \($0.state)"
            )
        }
    }

    private func averagePeakSummary(
        samples: [Double],
        formatter: (Double) -> String
    ) -> String {
        guard !samples.isEmpty else { return "Collecting recent history." }

        let average = samples.reduce(0, +) / Double(samples.count)
        let peak = samples.max() ?? average
        return "Avg \(formatter(average)) | Peak \(formatter(peak))"
    }

    private func thermalDomain(for samples: [Double]) -> ClosedRange<Double>? {
        guard !samples.isEmpty else { return nil }
        let low = max(20, (samples.min() ?? 20) - 5)
        let high = max(low + 8, (samples.max() ?? low) + 5)
        return low...high
    }

    private func wattageDomain(for samples: [Double]) -> ClosedRange<Double>? {
        guard !samples.isEmpty else { return nil }
        let high = max(5, (samples.max() ?? 5) * 1.15)
        return 0...high
    }

    private func historySummary() -> String {
        guard let first = history.first, let last = history.last, history.count > 1 else {
            return "Collecting samples"
        }

        let duration = max(1, Int(last.capturedAt.timeIntervalSince(first.capturedAt)))
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return String(format: "Last %dm %02ds", minutes, seconds)
        }
        return "Last \(seconds)s"
    }

    private func tone(for value: Double, warning: Double, critical: Double) -> DashboardMetricTone {
        if value >= critical { return .critical }
        if value >= warning { return .warning }
        return .accent
    }

    private func thermalTone(for snapshot: DashboardSnapshot) -> DashboardMetricTone {
        if let thermalLevel = snapshot.thermal.thermalLevel?.lowercased() {
            if thermalLevel.contains("critical") {
                return .critical
            }
            if thermalLevel != "nominal" && thermalLevel != "normal" {
                return .warning
            }
        }

        if let cpuTemp = snapshot.thermal.cpuTempCelsius {
            return tone(for: cpuTemp, warning: 75, critical: 88)
        }

        return .accent
    }

    private func batteryTone(for snapshot: DashboardSnapshot) -> DashboardMetricTone {
        guard let batteryPercent = snapshot.power.batteryPercent else { return .neutral }
        if snapshot.power.powerSource.localizedCaseInsensitiveContains("AC") {
            return .accent
        }

        if batteryPercent <= 10 { return .critical }
        if batteryPercent <= 25 { return .warning }
        return .accent
    }

    private func powerSummary(_ snapshot: DashboardSnapshot) -> String {
        if let batteryPercent = snapshot.power.batteryPercent {
            let parts = [
                "\(batteryPercent)%",
                snapshot.power.timeRemainingMinutes.map { DashboardFormatters.duration(minutes: $0) }
            ]
                .compactMap { $0 }
            return parts.joined(separator: " | ")
        }

        if let wattage = snapshot.power.wattageDraw {
            return String(format: "%.2f W", wattage)
        }

        return "No power telemetry"
    }

    private func processSummary(
        _ process: ProcessInfoRow?,
        metric: (ProcessInfoRow) -> String
    ) -> String {
        guard let process else { return "Unavailable" }
        return "\(process.name) \(metric(process))"
    }

    private func percentString(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    private func temperatureString(_ value: Double) -> String {
        String(format: "%.1f C", value)
    }

    private func memoryFootprint(_ megabytes: Double) -> String {
        if megabytes >= 1024 {
            return String(format: "%.1f GB", megabytes / 1024.0)
        }
        if megabytes >= 100 {
            return String(format: "%.0f MB", megabytes)
        }
        return String(format: "%.1f MB", megabytes)
    }
}

private final class OverviewStageView: NSView {
    private let sectionLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let divider = NSView()
    private let accessoryContainer = NSView()

    init(sectionLabel: String, title: String, subtitle: String, accessory: NSView? = nil) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 16, fillColor: BuoyChrome.panelBackgroundColor, borderColor: BuoyChrome.borderColor)

        self.sectionLabel.stringValue = sectionLabel.uppercased()
        self.sectionLabel.font = .buoySectionLabelFont()
        self.sectionLabel.textColor = BuoyChrome.secondaryTextColor

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = BuoyChrome.primaryTextColor

        subtitleLabel.stringValue = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor
        subtitleLabel.maximumNumberOfLines = 2

        divider.wantsLayer = true
        divider.layer?.backgroundColor = BuoyChrome.separatorColor.cgColor

        let titleStack = NSStackView(views: [self.sectionLabel, titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 4

        let header = NSStackView(views: [titleStack, NSView(), accessoryContainer])
        header.orientation = .horizontal
        header.alignment = .top
        header.spacing = 16
        header.translatesAutoresizingMaskIntoConstraints = false

        divider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(header)
        addSubview(divider)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])

        setAccessory(accessory)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setAccessory(_ accessory: NSView?) {
        accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let accessory else {
            accessoryContainer.isHidden = true
            return
        }

        accessoryContainer.isHidden = false
        accessoryContainer.addSubview(accessory)
        accessory.pinEdges(to: accessoryContainer)
    }

    func pinContent(_ child: NSView, bottomInset: CGFloat = 20) {
        addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            child.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            child.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 18),
            child.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        ])
    }
}

private final class OverviewToneBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyBuoySurface(cornerRadius: 999, fillColor: BuoyChrome.accentFillColor, borderColor: BuoyChrome.accentBorderColor)

        label.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        label.textColor = BuoyChrome.accentColor
        addSubview(label)
        label.pinEdges(to: self, insets: NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let labelSize = label.fittingSize
        return NSSize(width: labelSize.width + 20, height: labelSize.height + 8)
    }

    func set(text: String, tone: DashboardMetricTone) {
        label.stringValue = text.uppercased()
        layer?.backgroundColor = tone.fillColor.cgColor
        layer?.borderColor = tone.color.withAlphaComponent(0.35).cgColor
        label.textColor = tone.color
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
    }
}

private final class OverviewStateCellView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "0%")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let barBackground = NSView()
    private let barFill = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?
    private var currentProgress: Double = 0
    private var currentTone: DashboardMetricTone = .accent

    init(title: String) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        valueLabel.textColor = BuoyChrome.primaryTextColor
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = BuoyChrome.secondaryTextColor
        detailLabel.maximumNumberOfLines = 2

        barBackground.wantsLayer = true
        barBackground.layer?.cornerRadius = 3
        barBackground.layer?.backgroundColor = BuoyChrome.gridColor.cgColor

        barFill.wantsLayer = true
        barFill.layer?.cornerRadius = 3
        barBackground.addSubview(barFill)
        barFill.translatesAutoresizingMaskIntoConstraints = false
        fillWidthConstraint = barFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            barFill.leadingAnchor.constraint(equalTo: barBackground.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barBackground.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barBackground.bottomAnchor)
        ])

        let header = NSStackView(views: [titleLabel, NSView(), valueLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

        let stack = NSStackView(views: [header, detailLabel, barBackground])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 98),
            barBackground.heightAnchor.constraint(equalToConstant: 6),
            barBackground.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
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
        fillWidthConstraint?.constant = clamped == 0 ? 0 : max(6, usableWidth * CGFloat(clamped / 100.0))
        barFill.layer?.backgroundColor = currentTone.color.cgColor
    }
}

private final class AdaptiveColumnsView: NSView {
    private let primary: NSView
    private let secondary: NSView
    private let collapseWidth: CGFloat
    private let preferredSecondaryWidth: CGFloat
    private let spacing: CGFloat

    private var horizontalConstraints: [NSLayoutConstraint] = []
    private var verticalConstraints: [NSLayoutConstraint] = []
    private var isCollapsed = false

    init(
        primary: NSView,
        secondary: NSView,
        collapseWidth: CGFloat,
        preferredSecondaryWidth: CGFloat,
        spacing: CGFloat = 18
    ) {
        self.primary = primary
        self.secondary = secondary
        self.collapseWidth = collapseWidth
        self.preferredSecondaryWidth = preferredSecondaryWidth
        self.spacing = spacing
        super.init(frame: .zero)

        primary.translatesAutoresizingMaskIntoConstraints = false
        secondary.translatesAutoresizingMaskIntoConstraints = false
        addSubview(primary)
        addSubview(secondary)

        primary.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        secondary.setContentCompressionResistancePriority(.required, for: .horizontal)
        secondary.setContentHuggingPriority(.required, for: .horizontal)

        horizontalConstraints = [
            primary.leadingAnchor.constraint(equalTo: leadingAnchor),
            primary.topAnchor.constraint(equalTo: topAnchor),
            primary.bottomAnchor.constraint(equalTo: bottomAnchor),
            secondary.leadingAnchor.constraint(equalTo: primary.trailingAnchor, constant: spacing),
            secondary.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondary.topAnchor.constraint(equalTo: topAnchor),
            secondary.bottomAnchor.constraint(equalTo: bottomAnchor),
            secondary.widthAnchor.constraint(equalToConstant: preferredSecondaryWidth)
        ]

        verticalConstraints = [
            primary.leadingAnchor.constraint(equalTo: leadingAnchor),
            primary.trailingAnchor.constraint(equalTo: trailingAnchor),
            primary.topAnchor.constraint(equalTo: topAnchor),
            secondary.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondary.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondary.topAnchor.constraint(equalTo: primary.bottomAnchor, constant: spacing),
            secondary.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]

        updateLayoutMode(force: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        updateLayoutMode()
    }

    private func updateLayoutMode(force: Bool = false) {
        let collapsed = bounds.width < collapseWidth
        guard force || collapsed != isCollapsed else { return }
        isCollapsed = collapsed

        NSLayoutConstraint.deactivate(horizontalConstraints + verticalConstraints)
        NSLayoutConstraint.activate(collapsed ? verticalConstraints : horizontalConstraints)
    }
}

private final class OverviewFactsPanelView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let rowsStack = NSStackView()
    private var rowViews: [NSView] = []

    init(title: String) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        rowsStack.orientation = .vertical
        rowsStack.spacing = 10

        let stack = NSStackView(views: [titleLabel, rowsStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setRows(_ values: [(String, String)]) {
        rowViews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews.removeAll()

        for (index, item) in values.enumerated() {
            let label = NSTextField(labelWithString: item.0)
            label.font = .systemFont(ofSize: 12)
            label.textColor = BuoyChrome.secondaryTextColor

            let value = NSTextField(labelWithString: item.1)
            value.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            value.textColor = BuoyChrome.primaryTextColor
            value.alignment = .right
            value.lineBreakMode = .byTruncatingMiddle

            let row = NSStackView(views: [label, NSView(), value])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 10
            rowsStack.addArrangedSubview(row)
            rowViews.append(row)

            if index < values.count - 1 {
                let divider = NSView()
                divider.wantsLayer = true
                divider.layer?.backgroundColor = BuoyChrome.gridColor.cgColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                rowsStack.addArrangedSubview(divider)
                rowViews.append(divider)
            }
        }
    }
}

private final class OverviewTrendCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "No data")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let chartView = OverviewLineChartView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)

        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        valueLabel.textColor = BuoyChrome.primaryTextColor

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = BuoyChrome.secondaryTextColor
        detailLabel.maximumNumberOfLines = 2

        let stack = NSStackView(views: [titleLabel, valueLabel, chartView, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.heightAnchor.constraint(equalToConstant: 108).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func set(
        title: String,
        value: String,
        detail: String,
        samples: [Double],
        domain: ClosedRange<Double>?,
        tone: DashboardMetricTone
    ) {
        titleLabel.stringValue = title.uppercased()
        valueLabel.stringValue = value
        detailLabel.stringValue = detail
        chartView.set(samples: samples, domain: domain, tone: tone)
    }
}

private final class OverviewLineChartView: NSView {
    private var samples: [Double] = []
    private var domain: ClosedRange<Double>?
    private var tone: DashboardMetricTone = .accent

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func set(samples: [Double], domain: ClosedRange<Double>?, tone: DashboardMetricTone) {
        self.samples = samples
        self.domain = domain
        self.tone = tone
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).addClip()
        BuoyChrome.contentBackgroundColor.withAlphaComponent(0.55).setFill()
        rect.fill()

        let gridPath = NSBezierPath()
        for fraction in [0.25, 0.5, 0.75] {
            let y = rect.minY + rect.height * fraction
            gridPath.move(to: NSPoint(x: rect.minX, y: y))
            gridPath.line(to: NSPoint(x: rect.maxX, y: y))
        }
        gridPath.lineWidth = 1
        BuoyChrome.gridColor.withAlphaComponent(0.65).setStroke()
        gridPath.stroke()

        guard samples.count > 1, let domain else { return }

        let points = plotPoints(in: rect, domain: domain)
        guard let firstPoint = points.first, let lastPoint = points.last else { return }

        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: firstPoint.x, y: rect.minY))
        points.forEach { fillPath.line(to: $0) }
        fillPath.line(to: NSPoint(x: lastPoint.x, y: rect.minY))
        fillPath.close()
        tone.fillColor.withAlphaComponent(0.7).setFill()
        fillPath.fill()

        let linePath = NSBezierPath()
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round
        linePath.lineWidth = 2
        linePath.move(to: firstPoint)
        points.dropFirst().forEach { linePath.line(to: $0) }
        tone.color.setStroke()
        linePath.stroke()

        let marker = NSBezierPath(ovalIn: NSRect(x: lastPoint.x - 3.5, y: lastPoint.y - 3.5, width: 7, height: 7))
        tone.color.setFill()
        marker.fill()
    }

    private func plotPoints(in rect: NSRect, domain: ClosedRange<Double>) -> [NSPoint] {
        guard !samples.isEmpty else { return [] }

        let span = max(domain.upperBound - domain.lowerBound, 1)
        let usableWidth = max(rect.width, 1)
        return samples.enumerated().map { index, value in
            let xRatio = samples.count == 1 ? 1.0 : Double(index) / Double(samples.count - 1)
            let normalized = min(max((value - domain.lowerBound) / span, 0), 1)
            let x = rect.minX + usableWidth * CGFloat(xRatio)
            let y = rect.minY + rect.height * CGFloat(normalized)
            return NSPoint(x: x, y: y)
        }
    }
}

private final class OverviewProcessListView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let rowsStack = NSStackView()
    private var rowViews: [NSView] = []

    init(title: String) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        rowsStack.orientation = .vertical
        rowsStack.spacing = 12

        let stack = NSStackView(views: [titleLabel, rowsStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setRows(_ rows: [OverviewProcessDisplayRow]) {
        rowViews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews.removeAll()

        guard !rows.isEmpty else {
            let placeholder = NSTextField(wrappingLabelWithString: "Waiting for process data.")
            placeholder.font = .systemFont(ofSize: 12)
            placeholder.textColor = BuoyChrome.secondaryTextColor
            rowsStack.addArrangedSubview(placeholder)
            rowViews.append(placeholder)
            return
        }

        for (index, row) in rows.enumerated() {
            let nameLabel = NSTextField(labelWithString: row.name)
            nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
            nameLabel.textColor = BuoyChrome.primaryTextColor
            nameLabel.lineBreakMode = .byTruncatingTail

            let valueLabel = NSTextField(labelWithString: row.valueText)
            valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            valueLabel.textColor = BuoyChrome.primaryTextColor
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)

            let detailLabel = NSTextField(labelWithString: row.detailText)
            detailLabel.font = .systemFont(ofSize: 11)
            detailLabel.textColor = BuoyChrome.secondaryTextColor
            detailLabel.lineBreakMode = .byTruncatingMiddle

            let header = NSStackView(views: [nameLabel, NSView(), valueLabel])
            header.orientation = .horizontal
            header.alignment = .centerY
            header.spacing = 8

            let rowStack = NSStackView(views: [header, detailLabel])
            rowStack.orientation = .vertical
            rowStack.alignment = .leading
            rowStack.spacing = 4
            rowsStack.addArrangedSubview(rowStack)
            rowViews.append(rowStack)

            if index < rows.count - 1 {
                let divider = NSView()
                divider.wantsLayer = true
                divider.layer?.backgroundColor = BuoyChrome.gridColor.cgColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                rowsStack.addArrangedSubview(divider)
                rowViews.append(divider)
            }
        }
    }
}
