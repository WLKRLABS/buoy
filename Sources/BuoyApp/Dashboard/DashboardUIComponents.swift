import AppKit
import Foundation

enum BuoySpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
}

enum DashboardMetricTone {
    case neutral
    case accent
    case warning
    case critical

    var color: NSColor {
        switch self {
        case .neutral:
            return BuoyChrome.secondaryTextColor
        case .accent:
            return BuoyChrome.accentColor
        case .warning:
            return BuoyChrome.warningColor
        case .critical:
            return BuoyChrome.criticalColor
        }
    }

    var fillColor: NSColor {
        switch self {
        case .neutral:
            return BuoyChrome.accentFillColor.withAlphaComponent(0.38)
        case .accent:
            return BuoyChrome.accentFillColor
        case .warning:
            return BuoyChrome.warningFillColor
        case .critical:
            return BuoyChrome.criticalFillColor
        }
    }
}

enum BuoyChrome {
    static let windowBackgroundColor = dynamicColor(
        name: "BuoyWindowBackground",
        light: 0xEEF1EF,
        dark: 0x111416
    )
    static let sidebarBackgroundColor = dynamicColor(
        name: "BuoySidebarBackground",
        light: 0xE5EAE7,
        dark: 0x161A1C
    )
    static let panelBackgroundColor = dynamicColor(
        name: "BuoyPanelBackground",
        light: 0xF9FBFA,
        dark: 0x1B2022
    )
    static let elevatedBackgroundColor = dynamicColor(
        name: "BuoyElevatedBackground",
        light: 0xF4F7F5,
        dark: 0x202629
    )
    static let buttonBackgroundColor = dynamicColor(
        name: "BuoyButtonBackground",
        light: 0xEDF2EF,
        dark: 0x181D1F
    )
    static let contentBackgroundColor = dynamicColor(
        name: "BuoyContentBackground",
        light: 0xF6F8F7,
        dark: 0x181D1F
    )
    static let tableBackgroundColor = dynamicColor(
        name: "BuoyTableBackground",
        light: 0xFCFDFC,
        dark: 0x15191B
    )
    static let borderColor = dynamicColor(
        name: "BuoyBorder",
        light: 0xCAD2CE,
        dark: 0x2F373A
    )
    static let separatorColor = dynamicColor(
        name: "BuoySeparator",
        light: 0xD7DEDB,
        dark: 0x293034
    )
    static let gridColor = dynamicColor(
        name: "BuoyGrid",
        light: 0xD8DEDB,
        dark: 0x262D30
    )
    static let accentColor = dynamicColor(
        name: "BuoyAccent",
        light: 0x4F6D58,
        dark: 0xA5C191
    )
    static let accentFillColor = dynamicColor(
        name: "BuoyAccentFill",
        light: 0xDCE7DC,
        dark: 0x253128
    )
    static let accentBorderColor = dynamicColor(
        name: "BuoyAccentBorder",
        light: 0x7F9B82,
        dark: 0x64775D
    )
    static let warningColor = dynamicColor(
        name: "BuoyWarning",
        light: 0xA46E27,
        dark: 0xD0AE6A
    )
    static let warningFillColor = dynamicColor(
        name: "BuoyWarningFill",
        light: 0xF0E2C6,
        dark: 0x362A18
    )
    static let criticalColor = dynamicColor(
        name: "BuoyCritical",
        light: 0xA1554B,
        dark: 0xD68B7E
    )
    static let criticalFillColor = dynamicColor(
        name: "BuoyCriticalFill",
        light: 0xF0D6D2,
        dark: 0x33211E
    )
    static let primaryTextColor = dynamicColor(
        name: "BuoyPrimaryText",
        light: 0x1C2325,
        dark: 0xE8ECE9
    )
    static let secondaryTextColor = dynamicColor(
        name: "BuoySecondaryText",
        light: 0x66706C,
        dark: 0x99A49F
    )
    static let tertiaryTextColor = dynamicColor(
        name: "BuoyTertiaryText",
        light: 0x8A9591,
        dark: 0x7A8681
    )

    static func applyWindowBackground(to view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = windowBackgroundColor.cgColor
    }

    private static func dynamicColor(name: String, light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension NSView {
    func applyBuoySurface(
        cornerRadius: CGFloat = 10,
        fillColor: NSColor = BuoyChrome.panelBackgroundColor,
        borderColor: NSColor = BuoyChrome.borderColor,
        borderWidth: CGFloat = 1
    ) {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = borderWidth
        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = fillColor.cgColor
        layer?.masksToBounds = true
    }

    func pinEdges(
        to other: NSView,
        insets: NSEdgeInsets = NSEdgeInsetsZero
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

extension NSFont {
    static func buoySectionLabelFont() -> NSFont {
        .monospacedSystemFont(ofSize: 11, weight: .semibold)
    }

    static func buoyMetricValueFont() -> NSFont {
        .monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
    }
}

final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

func installVerticalScrollContainer(in hostView: NSView) -> (scrollView: NSScrollView, documentView: NSView) {
    let scrollView = NSScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.scrollerStyle = .overlay
    hostView.addSubview(scrollView)

    let documentView = FlippedContentView()
    documentView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = documentView

    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: hostView.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
        documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
        documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
    ])

    return (scrollView, documentView)
}

func installDashboardDocumentStack(
    in hostView: NSView,
    maxWidth: CGFloat = 1220,
    topInset: CGFloat = 24,
    horizontalInset: CGFloat = 28,
    bottomInset: CGFloat = 24,
    spacing: CGFloat = 18
) -> (scrollView: NSScrollView, documentView: NSView, stack: NSStackView) {
    let (scrollView, documentView) = installVerticalScrollContainer(in: hostView)

    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    documentView.addSubview(stack)

    let fillWidthConstraint = stack.widthAnchor.constraint(equalTo: documentView.widthAnchor, constant: -(horizontalInset * 2))
    fillWidthConstraint.priority = .defaultHigh

    NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: topInset),
        stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -bottomInset),
        stack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
        stack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: horizontalInset),
        stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -horizontalInset),
        stack.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
        fillWidthConstraint
    ])

    return (scrollView, documentView, stack)
}

final class AdaptiveGridView: NSView {
    private let rootStack = NSStackView()
    private let minColumnWidth: CGFloat
    private let maxColumns: Int
    private let rowSpacing: CGFloat
    private let columnSpacing: CGFloat
    private var lastColumnCount = 0
    private var items: [NSView] = []

    init(minColumnWidth: CGFloat, maxColumns: Int, rowSpacing: CGFloat = 12, columnSpacing: CGFloat = 12) {
        self.minColumnWidth = minColumnWidth
        self.maxColumns = maxColumns
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
        super.init(frame: .zero)

        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = rowSpacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        rootStack.fittingSize
    }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    func setItems(_ views: [NSView]) {
        items = views
        rebuildIfNeeded(force: true)
    }

    private func rebuildIfNeeded(force: Bool = false) {
        let columnCount = max(1, min(maxColumns, calculatedColumns(for: bounds.width)))
        guard force || columnCount != lastColumnCount else { return }
        lastColumnCount = columnCount

        rootStack.arrangedSubviews.forEach { row in
            rootStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        guard !items.isEmpty else { return }

        for index in stride(from: 0, to: items.count, by: columnCount) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.distribution = .fillEqually
            row.spacing = columnSpacing
            row.translatesAutoresizingMaskIntoConstraints = false

            let endIndex = min(index + columnCount, items.count)
            items[index..<endIndex].forEach { row.addArrangedSubview($0) }

            if endIndex - index < columnCount {
                for _ in (endIndex - index)..<columnCount {
                    let spacer = NSView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(spacer)
                }
            }

            rootStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true
        }

        invalidateIntrinsicContentSize()
    }

    private func calculatedColumns(for width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let availableWidth = max(width, minColumnWidth)
        let rawColumns = Int((availableWidth + columnSpacing) / (minColumnWidth + columnSpacing))
        return max(1, rawColumns)
    }
}

final class DashboardStageView: NSView {
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

final class DashboardSplitColumnsView: NSView {
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

final class DashboardFactsPanelView: NSView {
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

final class DashboardMetricRowView: NSView {
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
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        valueLabel.textColor = BuoyChrome.primaryTextColor
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

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

final class DashboardMetricCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let accentStrip = NSView()

    init(title: String, tone: DashboardMetricTone = .accent) {
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

        accentStrip.wantsLayer = true
        accentStrip.layer?.cornerRadius = 1.5

        let stack = NSStackView(views: [titleLabel, valueLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentStrip)
        addSubview(stack)

        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 116),
            accentStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            accentStrip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            accentStrip.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            accentStrip.heightAnchor.constraint(equalToConstant: 3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: accentStrip.bottomAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        set(value: "—", detail: "", tone: tone)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func set(value: String, detail: String, tone: DashboardMetricTone = .accent) {
        valueLabel.stringValue = value
        detailLabel.stringValue = detail
        accentStrip.layer?.backgroundColor = tone.color.cgColor
    }
}

final class DashboardSectionView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let divider = NSView()
    private let headerStack = NSStackView()
    private let titleStack = NSStackView()
    private let accessoryContainer = NSView()

    init(title: String, subtitle: String? = nil, accessory: NSView? = nil) {
        super.init(frame: .zero)
        applyBuoySurface()

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .buoySectionLabelFont()
        titleLabel.textColor = BuoyChrome.secondaryTextColor

        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.isHidden = subtitle == nil

        divider.wantsLayer = true
        divider.layer?.backgroundColor = BuoyChrome.separatorColor.cgColor

        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(NSView())
        headerStack.addArrangedSubview(accessoryContainer)

        accessoryContainer.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerStack)
        addSubview(divider)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
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

    func pinContent(_ child: NSView, top: CGFloat = 50, bottom: CGFloat = 16) {
        addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            child.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            child.topAnchor.constraint(equalTo: topAnchor, constant: top),
            child.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottom)
        ])
    }
}

final class DashboardTableContainer: NSView {
    let tableView = NSTableView()
    let scrollView = NSScrollView()

    init(columns: [(id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat)]) {
        super.init(frame: .zero)
        applyBuoySurface(cornerRadius: 8, fillColor: BuoyChrome.tableBackgroundColor)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        addSubview(scrollView)

        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.gridColor = BuoyChrome.gridColor
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 30
        tableView.allowsEmptySelection = true
        tableView.rowSizeStyle = .default
        tableView.selectionHighlightStyle = .regular
        tableView.headerView = NSTableHeaderView()

        for column in columns {
            let tableColumn = NSTableColumn(identifier: column.id)
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = min(column.width, 80)
            tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = .systemFont(ofSize: 11, weight: .semibold)
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

enum DashboardFormatters {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    static func number(_ value: Double?, unit: String, decimals: Int = 1) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(decimals)f %@", value, unit)
    }

    static func memoryMB(_ value: Double?) -> String {
        number(value, unit: "MB", decimals: 1)
    }

    static func duration(minutes: Int?) -> String {
        guard let minutes, minutes >= 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    static func timestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }

    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func storageBytes(from gigabytes: Double) -> Int64 {
        Int64(gigabytes * 1_073_741_824.0)
    }
}
