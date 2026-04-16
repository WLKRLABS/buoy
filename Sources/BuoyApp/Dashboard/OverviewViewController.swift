import AppKit
import Foundation

public final class OverviewViewController: NSViewController, DashboardConsumer {
    private let cpuGauge = GaugeView(title: "CPU")
    private let memGauge = GaugeView(title: "Memory")
    private let diskGauge = GaugeView(title: "Disk")
    private let batteryGauge = GaugeView(title: "Battery")
    private let gaugesGrid = AdaptiveGridView(minColumnWidth: 170, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let listsGrid = AdaptiveGridView(minColumnWidth: 280, maxColumns: 2, rowSpacing: 12, columnSpacing: 12)
    private let topCPULabel = NSTextField(labelWithString: "Top CPU")
    private let topMemLabel = NSTextField(labelWithString: "Top Memory")
    private let topCPUText = NSTextField(wrappingLabelWithString: "")
    private let topMemText = NSTextField(wrappingLabelWithString: "")
    private let timestampLabel = NSTextField(labelWithString: "—")

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        [topCPULabel, topMemLabel].forEach {
            $0.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
            $0.textColor = BuoyChrome.secondaryTextColor
        }
        [topCPUText, topMemText].forEach {
            $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            $0.maximumNumberOfLines = 0
            $0.textColor = BuoyChrome.primaryTextColor
        }

        gaugesGrid.setItems([cpuGauge, memGauge, diskGauge, batteryGauge])
        listsGrid.setItems([
            makeBox(title: topCPULabel, content: topCPUText),
            makeBox(title: topMemLabel, content: topMemText)
        ])

        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        let stack = NSStackView(views: [gaugesGrid, listsGrid, timestampLabel])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: documentView.widthAnchor, constant: -40)
        ])
    }

    private func makeBox(title: NSTextField, content: NSTextField) -> NSView {
        let box = NSView()
        box.applyBuoySurface(cornerRadius: 14)

        let stack = NSStackView(views: [title, content])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14)
        ])

        return box
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        cpuGauge.setValue(snapshot.cpu.overallPercent, unit: "%")
        memGauge.setValue(snapshot.memory.usagePercent, unit: "%")
        diskGauge.setValue(snapshot.disk.usagePercent, unit: "%")
        if let batteryPercent = snapshot.power.batteryPercent {
            batteryGauge.setValue(Double(batteryPercent), unit: "%")
        } else {
            batteryGauge.setValue(0, unit: "—")
        }

        let topCPU = snapshot.processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5)
        topCPUText.stringValue = topCPU.map {
            String(format: "%-20s %6.1f%%", ($0.name as NSString).utf8String!, $0.cpuPercent)
        }.joined(separator: "\n")

        let topMem = snapshot.processes.sorted { $0.memoryMB > $1.memoryMB }.prefix(5)
        topMemText.stringValue = topMem.map {
            String(format: "%-20s %7.1f MB", ($0.name as NSString).utf8String!, $0.memoryMB)
        }.joined(separator: "\n")

        timestampLabel.stringValue = "LAST UPDATED \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }
}

final class GaugeView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private var percent: Double = 0

    init(title: String) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 14)

        titleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = BuoyChrome.secondaryTextColor
        titleLabel.stringValue = title.uppercased()

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        valueLabel.textColor = BuoyChrome.primaryTextColor

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 118),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setValue(_ value: Double, unit: String) {
        percent = value
        if unit == "—" {
            valueLabel.stringValue = "—"
        } else {
            valueLabel.stringValue = String(format: "%.0f%@", value, unit)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset: CGFloat = 16
        let barHeight: CGFloat = 6
        let width = bounds.width - (inset * 2)
        let y = inset

        let backgroundBar = NSBezierPath(roundedRect: NSRect(x: inset, y: y, width: width, height: barHeight), xRadius: 3, yRadius: 3)
        BuoyChrome.gridColor.setFill()
        backgroundBar.fill()

        let clampedPercent = max(0, min(100, percent))
        let fillWidth = width * CGFloat(clampedPercent / 100.0)
        guard fillWidth > 0 else { return }

        let filledBar = NSBezierPath(roundedRect: NSRect(x: inset, y: y, width: fillWidth, height: barHeight), xRadius: 3, yRadius: 3)
        BuoyChrome.accentColor.setFill()
        filledBar.fill()
    }
}
