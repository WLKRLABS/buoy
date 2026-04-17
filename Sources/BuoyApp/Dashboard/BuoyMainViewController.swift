import AppKit
import Foundation

enum BuoyDashboardSection: Int, CaseIterable {
    case power
    case overview
    case system
    case processes
    case services
    case network
    case storage

    static let navigationOrder: [BuoyDashboardSection] = [
        .overview,
        .power,
        .system,
        .processes,
        .services,
        .network,
        .storage
    ]

    var storageIdentifier: String {
        switch self {
        case .overview: return "overview"
        case .power: return "power"
        case .system: return "system"
        case .processes: return "processes"
        case .services: return "services"
        case .network: return "network"
        case .storage: return "storage"
        }
    }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .power: return "Power"
        case .system: return "System"
        case .processes: return "Processes"
        case .services: return "Services"
        case .network: return "Network"
        case .storage: return "Storage"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Live CPU, memory, disk, battery, and thermal state at a glance."
        case .power:
            return "Configure Buoy mode, closed-lid behavior, display sleep, and recovery actions."
        case .system:
            return "Inspect the raw machine snapshot with a dense operator-friendly readout."
        case .processes:
            return "Filter active processes by load, user, and name."
        case .services:
            return "Review launchd services, their state, and where they live."
        case .network:
            return "Monitor listening services, interfaces, and network presence."
        case .storage:
            return "Break down disk usage, review access grants, and target cleanup safely."
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .power: return "bolt.fill"
        case .system: return "cpu"
        case .processes: return "list.bullet.rectangle"
        case .services: return "gearshape.2"
        case .network: return "network"
        case .storage: return "internaldrive"
        }
    }

    var hotkeyHint: String {
        guard let index = Self.navigationOrder.firstIndex(of: self) else { return "" }
        return "⌘\(index + 1)"
    }
}

private protocol BuoySidebarSelectionDelegate: AnyObject {
    func sidebarDidSelect(section: BuoyDashboardSection)
}

private final class SidebarSectionRowView: NSTableRowView {
    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected ? .emphasized : .normal
    }

    override func drawSelection(in dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 8, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        BuoyChrome.accentFillColor.setFill()
        path.fill()

        BuoyChrome.accentBorderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class SidebarSectionCellView: NSTableCellView {
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        symbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        symbolView.contentTintColor = BuoyChrome.secondaryTextColor
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = BuoyChrome.primaryTextColor

        shortcutLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        shortcutLabel.textColor = BuoyChrome.tertiaryTextColor
        shortcutLabel.alignment = .right

        let stack = NSStackView(views: [symbolView, titleLabel, NSView(), shortcutLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        addSubview(stack)
        stack.pinEdges(
            to: self,
            insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(section: BuoyDashboardSection, selected: Bool) {
        symbolView.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)
        symbolView.contentTintColor = selected ? BuoyChrome.accentColor : BuoyChrome.secondaryTextColor
        titleLabel.stringValue = section.title
        titleLabel.textColor = selected ? BuoyChrome.primaryTextColor : BuoyChrome.primaryTextColor
        shortcutLabel.stringValue = section.hotkeyHint
        shortcutLabel.textColor = selected ? BuoyChrome.accentColor : BuoyChrome.tertiaryTextColor
        toolTip = "\(section.title) \(section.hotkeyHint)"
    }
}

private final class BuoySidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    weak var delegate: BuoySidebarSelectionDelegate?

    private let titleLabel = NSTextField(labelWithString: buoyProductName)
    private let subtitleLabel = NSTextField(labelWithString: "Quiet machine utility for power users.")
    private let footerLabel = NSTextField(wrappingLabelWithString: "Cmd+1-7 sections | Cmd+[ / Cmd+] cycle | Cmd+W close")
    private let versionLabel = NSTextField(labelWithString: "v\(buoyVersion)")
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let sections = BuoyDashboardSection.navigationOrder
    private var selectedSection: BuoyDashboardSection = .overview
    private var isApplyingProgrammaticSelection = false

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        select(section: selectedSection)
    }

    func select(section: BuoyDashboardSection) {
        selectedSection = section
        guard isViewLoaded, let row = sections.firstIndex(of: section) else { return }

        if tableView.selectedRow != row {
            // NSTableView posts selection-change notifications for code-driven selects too.
            isApplyingProgrammaticSelection = true
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            isApplyingProgrammaticSelection = false
        }

        tableView.scrollRowToVisible(row)
        tableView.reloadData()
    }

    private func buildLayout() {
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = BuoyChrome.primaryTextColor

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor

        versionLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        versionLabel.textColor = BuoyChrome.tertiaryTextColor

        footerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        footerLabel.textColor = BuoyChrome.secondaryTextColor
        footerLabel.maximumNumberOfLines = 2

        let headerTopRow = NSStackView(views: [titleLabel, NSView(), versionLabel])
        headerTopRow.orientation = .horizontal
        headerTopRow.alignment = .centerY

        let headerStack = NSStackView(views: [headerTopRow, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        column.width = 220
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = tableView

        let rootStack = NSStackView(views: [headerStack, scrollView, footerLabel])
        rootStack.orientation = .vertical
        rootStack.spacing = 18
        view.addSubview(rootStack)
        rootStack.pinEdges(
            to: view,
            insets: NSEdgeInsets(top: 20, left: 16, bottom: 16, right: 16)
        )
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        38
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SidebarSectionRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < sections.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("SidebarSectionCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? SidebarSectionCellView ?? {
            let view = SidebarSectionCellView()
            view.identifier = identifier
            return view
        }()
        let section = sections[row]
        cell.configure(section: section, selected: section == selectedSection)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < sections.count else { return }
        let section = sections[row]
        selectedSection = section

        guard !isApplyingProgrammaticSelection else { return }

        tableView.reloadData()
        delegate?.sidebarDidSelect(section: section)
    }
}

private final class DashboardContentHostViewController: NSViewController {
    private let eyebrowLabel = NSTextField(labelWithString: "BUOY UTILITY")
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let symbolView = NSImageView()
    private let divider = NSView()
    private let contentContainer = NSView()
    private var currentController: NSViewController?

    override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    func display(section: BuoyDashboardSection, controller: NSViewController) {
        eyebrowLabel.stringValue = "BUOY UTILITY"
        titleLabel.stringValue = section.title
        subtitleLabel.stringValue = section.subtitle
        symbolView.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)

        guard currentController !== controller else { return }

        currentController?.view.removeFromSuperview()
        currentController?.removeFromParent()
        currentController = controller

        addChild(controller)
        contentContainer.addSubview(controller.view)
        controller.view.pinEdges(to: contentContainer)
    }

    private func buildLayout() {
        eyebrowLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        eyebrowLabel.textColor = BuoyChrome.secondaryTextColor

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = BuoyChrome.primaryTextColor

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor
        subtitleLabel.maximumNumberOfLines = 2

        symbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        symbolView.contentTintColor = BuoyChrome.accentColor

        divider.wantsLayer = true
        divider.layer?.backgroundColor = BuoyChrome.separatorColor.cgColor

        let titleRow = NSStackView(views: [symbolView, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10

        let headerStack = NSStackView(views: [eyebrowLabel, titleRow, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        headerStack.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        view.addSubview(divider)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            headerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            divider.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            divider.heightAnchor.constraint(equalToConstant: 1),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

final class BuoyMainViewController: NSSplitViewController, BuoySidebarSelectionDelegate {
    public let coordinator = RefreshCoordinator()

    private struct SectionEntry {
        let section: BuoyDashboardSection
        let controller: NSViewController
    }

    private static let selectionDefaultsKey = "buoy.dashboard.section.identifier"

    private let powerVC: BuoyViewController
    private let overviewVC = OverviewViewController()
    private let systemVC = SystemMetricsViewController()
    private let processesVC = ProcessesViewController()
    private let servicesVC = ServicesViewController()
    private let networkVC = NetworkViewController()
    private let storageVC = StorageViewController()
    private let sidebarController = BuoySidebarViewController()
    private let hostController = DashboardContentHostViewController()

    private lazy var entries: [SectionEntry] = [
        SectionEntry(section: .overview, controller: overviewVC),
        SectionEntry(section: .power, controller: powerVC),
        SectionEntry(section: .system, controller: systemVC),
        SectionEntry(section: .processes, controller: processesVC),
        SectionEntry(section: .services, controller: servicesVC),
        SectionEntry(section: .network, controller: networkVC),
        SectionEntry(section: .storage, controller: storageVC)
    ]

    private(set) var selectedSection: BuoyDashboardSection = BuoyMainViewController.restoredSection()

    init(powerVC: BuoyViewController) {
        self.powerVC = powerVC
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        systemVC.coordinator = coordinator
        let consumers: [DashboardConsumer] = [overviewVC, systemVC, processesVC, servicesVC, networkVC]
        consumers.forEach { coordinator.addConsumer($0) }

        configureSplitView()
        selectSection(selectedSection)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            coordinator.attach(window: window)
        }
        coordinator.start()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        coordinator.stop()
    }

    func selectSection(_ section: BuoyDashboardSection) {
        guard let entry = entries.first(where: { $0.section == section }) else { return }
        selectedSection = section
        UserDefaults.standard.set(section.storageIdentifier, forKey: Self.selectionDefaultsKey)
        UserDefaults.standard.set(section.rawValue, forKey: "buoy.dashboard.section")
        sidebarController.select(section: section)
        hostController.display(section: section, controller: entry.controller)
    }

    func selectNextSection() {
        guard let index = BuoyDashboardSection.navigationOrder.firstIndex(of: selectedSection) else { return }
        let next = BuoyDashboardSection.navigationOrder[(index + 1) % BuoyDashboardSection.navigationOrder.count]
        selectSection(next)
    }

    func selectPreviousSection() {
        guard let index = BuoyDashboardSection.navigationOrder.firstIndex(of: selectedSection) else { return }
        let previousIndex = index == 0 ? BuoyDashboardSection.navigationOrder.count - 1 : index - 1
        selectSection(BuoyDashboardSection.navigationOrder[previousIndex])
    }

    func sidebarDidSelect(section: BuoyDashboardSection) {
        selectSection(section)
    }

    private static func restoredSection() -> BuoyDashboardSection {
        if let stored = UserDefaults.standard.string(forKey: selectionDefaultsKey),
           let section = BuoyDashboardSection.allCases.first(where: { $0.storageIdentifier == stored }) {
            return section
        }

        let legacyRawValue = UserDefaults.standard.integer(forKey: "buoy.dashboard.section")
        return BuoyDashboardSection(rawValue: legacyRawValue) ?? .overview
    }

    private func configureSplitView() {
        guard splitViewItems.isEmpty else { return }

        sidebarController.delegate = self

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 260
        sidebarItem.canCollapse = false

        let contentItem = NSSplitViewItem(viewController: hostController)
        contentItem.minimumThickness = 560

        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)

        splitView.dividerStyle = .thin
    }
}
