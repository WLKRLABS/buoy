import AppKit
import Foundation

enum BuoyChrome {
    static let windowBackgroundColor = dynamicColor(
        name: "BuoyWindowBackground",
        light: 0xEFE9DB,
        dark: 0x0F1214
    )
    static let sidebarBackgroundColor = dynamicColor(
        name: "BuoySidebarBackground",
        light: 0xE3DCCB,
        dark: 0x0A0D0F
    )
    static let panelBackgroundColor = dynamicColor(
        name: "BuoyPanelBackground",
        light: 0xFAF5E8,
        dark: 0x171C20
    )
    static let elevatedBackgroundColor = dynamicColor(
        name: "BuoyElevatedBackground",
        light: 0xF5EFDD,
        dark: 0x1D2328
    )
    static let buttonBackgroundColor = dynamicColor(
        name: "BuoyButtonBackground",
        light: 0xF0E7D2,
        dark: 0x11161A
    )
    static let contentBackgroundColor = dynamicColor(
        name: "BuoyContentBackground",
        light: 0xF7F2E3,
        dark: 0x12171B
    )
    static let borderColor = dynamicColor(
        name: "BuoyBorder",
        light: 0xB7AE98,
        dark: 0x333A41
    )
    static let gridColor = dynamicColor(
        name: "BuoyGrid",
        light: 0xCBC1AB,
        dark: 0x2A3137
    )
    static let accentColor = dynamicColor(
        name: "BuoyAccent",
        light: 0x587244,
        dark: 0x9ABB72
    )
    static let accentFillColor = dynamicColor(
        name: "BuoyAccentFill",
        light: 0xD5E0C6,
        dark: 0x23321E
    )
    static let accentBorderColor = dynamicColor(
        name: "BuoyAccentBorder",
        light: 0x748C5E,
        dark: 0x6A8452
    )
    static let primaryTextColor = dynamicColor(
        name: "BuoyPrimaryText",
        light: 0x1D2327,
        dark: 0xE8E4DA
    )
    static let secondaryTextColor = dynamicColor(
        name: "BuoySecondaryText",
        light: 0x6B6A5F,
        dark: 0x99A29B
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
        cornerRadius: CGFloat = 14,
        fillColor: NSColor = BuoyChrome.panelBackgroundColor,
        borderColor: NSColor = BuoyChrome.borderColor
    ) {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = 1
        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = fillColor.cgColor
        layer?.masksToBounds = true
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

final class SidebarSectionButton: NSButton {
    private let baseTitle: String
    private let symbolName: String

    var compactMode = false {
        didSet { refreshLayoutMode() }
    }

    var isSectionSelected = false {
        didSet { refreshAppearance() }
    }

    init(title: String, symbol: String) {
        self.baseTitle = title
        self.symbolName = symbol
        super.init(frame: .zero)

        setButtonType(.momentaryPushIn)
        isBordered = false
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        imageScaling = .scaleProportionallyDown
        bezelStyle = .shadowlessSquare
        focusRingType = .none
        contentTintColor = BuoyChrome.secondaryTextColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        refreshLayoutMode()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func refreshLayoutMode() {
        title = compactMode ? "" : baseTitle.uppercased()
        imagePosition = compactMode ? .imageOnly : .imageLeading
        alignment = compactMode ? .center : .left
        font = compactMode
            ? .systemFont(ofSize: 13, weight: .semibold)
            : .monospacedSystemFont(ofSize: 11, weight: .semibold)
        refreshAppearance()
    }

    private func refreshAppearance() {
        applyBuoySurface(
            cornerRadius: 10,
            fillColor: isSectionSelected ? BuoyChrome.accentFillColor : BuoyChrome.buttonBackgroundColor,
            borderColor: isSectionSelected ? BuoyChrome.accentBorderColor : BuoyChrome.borderColor
        )
        contentTintColor = isSectionSelected ? BuoyChrome.accentColor : BuoyChrome.secondaryTextColor

        let textColor = isSectionSelected ? BuoyChrome.primaryTextColor : BuoyChrome.secondaryTextColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: textColor,
                .kern: 0.6
            ]
        )
    }
}

final class DashboardSectionView: NSBox {
    init(title: String) {
        super.init(frame: .zero)
        boxType = .custom
        cornerRadius = 16
        borderWidth = 1
        borderColor = BuoyChrome.borderColor
        fillColor = BuoyChrome.panelBackgroundColor
        titlePosition = .noTitle

        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = BuoyChrome.secondaryTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(label)

        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = BuoyChrome.borderColor.cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(rule)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 14),
            rule.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            rule.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -16),
            rule.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func pinContent(_ child: NSView, top: CGFloat = 40, bottom: CGFloat = 16) {
        child.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 16),
            child.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -16),
            child.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: top),
            child.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -bottom)
        ])
    }
}

final class DashboardTableContainer: NSView {
    let tableView = NSTableView()
    let scrollView = NSScrollView()

    init(columns: [(id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat)]) {
        super.init(frame: .zero)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.gridColor = BuoyChrome.gridColor
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 28
        tableView.allowsEmptySelection = true
        tableView.rowSizeStyle = .default
        tableView.headerView = NSTableHeaderView()

        for column in columns {
            let tableColumn = NSTableColumn(identifier: column.id)
            tableColumn.title = column.title.uppercased()
            tableColumn.width = column.width
            tableColumn.minWidth = min(column.width, 80)
            tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView
        applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.contentBackgroundColor)

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
}
