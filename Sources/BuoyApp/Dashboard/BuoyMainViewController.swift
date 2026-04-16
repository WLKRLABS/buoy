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

    var title: String {
        switch self {
        case .power: return "Power"
        case .overview: return "Overview"
        case .system: return "System"
        case .processes: return "Processes"
        case .services: return "Services"
        case .network: return "Network"
        case .storage: return "Storage"
        }
    }

    var subtitle: String {
        switch self {
        case .power:
            return "Control Buoy mode, lid behavior, sleep timing, and local appearance."
        case .overview:
            return "Watch the machine at a glance with live CPU, memory, disk, and battery signals."
        case .system:
            return "Inspect raw system metrics in a dense, terminal-like readout."
        case .processes:
            return "Filter the active process list by name, user, and load."
        case .services:
            return "Review launchd services, their status, and where they live."
        case .network:
            return "Check listening ports and the current interface map."
        case .storage:
            return "Scan disk usage, review access grants, and find large cleanup targets."
        }
    }

    var symbolName: String {
        switch self {
        case .power: return "bolt.fill"
        case .overview: return "gauge"
        case .system: return "cpu"
        case .processes: return "list.bullet.rectangle"
        case .services: return "gearshape.2"
        case .network: return "network"
        case .storage: return "internaldrive"
        }
    }

    var hotkeyHint: String {
        "⌘\(rawValue + 1)"
    }
}

/// Custom root controller that replaces the cramped toolbar tabs with a resilient sidebar shell.
final class BuoyMainViewController: NSViewController {
    public let coordinator = RefreshCoordinator()

    private struct SectionEntry {
        let section: BuoyDashboardSection
        let controller: NSViewController
    }

    private let powerVC: BuoyViewController
    private let overviewVC = OverviewViewController()
    private let systemVC = SystemMetricsViewController()
    private let processesVC = ProcessesViewController()
    private let servicesVC = ServicesViewController()
    private let networkVC = NetworkViewController()
    private let storageVC = StorageViewController()

    private lazy var entries: [SectionEntry] = [
        SectionEntry(section: .power, controller: powerVC),
        SectionEntry(section: .overview, controller: overviewVC),
        SectionEntry(section: .system, controller: systemVC),
        SectionEntry(section: .processes, controller: processesVC),
        SectionEntry(section: .services, controller: servicesVC),
        SectionEntry(section: .network, controller: networkVC),
        SectionEntry(section: .storage, controller: storageVC)
    ]

    private let shellStack = NSStackView()
    private let sidebarView = NSView()
    private let navStack = NSStackView()
    private let mainStack = NSStackView()
    private let headerView = NSView()
    private let headerTopStack = NSStackView()
    private let headerTextStack = NSStackView()
    private let headerMetaStack = NSStackView()
    private let headerSpacer = NSView()
    private let headerRule = NSView()
    private let contentSurface = NSView()
    private let contentContainer = NSView()

    private let brandEyebrowLabel = NSTextField(labelWithString: "BUOY")
    private let brandTitleLabel = NSTextField(labelWithString: buoyProductName)
    private let brandSubtitleLabel = NSTextField(labelWithString: "Retro control surface for a working Mac.")
    private let sidebarHintLabel = NSTextField(wrappingLabelWithString: "⌘1–7 switch sections\n⌘[ / ⌘] cycle\n⌘W close window\n⌘Q quit app")

    private let sectionEyebrowLabel = NSTextField(labelWithString: "SECTION")
    private let sectionTitleLabel = NSTextField(labelWithString: "")
    private let sectionSubtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let sectionShortcutLabel = NSTextField(labelWithString: "")
    private let sectionHintLabel = NSTextField(labelWithString: "Keyboard-first navigation")

    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var currentController: NSViewController?
    private var navButtons: [BuoyDashboardSection: SidebarSectionButton] = [:]
    private var navHintLabels: [BuoyDashboardSection: NSTextField] = [:]
    private var isSidebarCompact = false

    private(set) var selectedSection: BuoyDashboardSection = {
        let rawValue = UserDefaults.standard.integer(forKey: "buoy.dashboard.section")
        return BuoyDashboardSection(rawValue: rawValue) ?? .power
    }()

    init(powerVC: BuoyViewController) {
        self.powerVC = powerVC
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        systemVC.coordinator = coordinator
        let consumers: [DashboardConsumer] = [overviewVC, systemVC, processesVC, servicesVC, networkVC]
        consumers.forEach { coordinator.addConsumer($0) }
        entries.map(\.controller).forEach(addChild)

        configureTypography()
        buildLayout()
        selectSection(selectedSection)
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            coordinator.attach(window: window)
        }
        coordinator.start()
    }

    public override func viewWillDisappear() {
        super.viewWillDisappear()
        coordinator.stop()
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        updateResponsiveChrome()
    }

    func selectSection(_ section: BuoyDashboardSection) {
        guard let entry = entries.first(where: { $0.section == section }) else { return }

        selectedSection = section
        UserDefaults.standard.set(section.rawValue, forKey: "buoy.dashboard.section")
        swapContent(to: entry.controller)
        refreshSelectionState()
    }

    func selectNextSection() {
        let ordered = BuoyDashboardSection.allCases
        guard let index = ordered.firstIndex(of: selectedSection) else { return }
        selectSection(ordered[(index + 1) % ordered.count])
    }

    func selectPreviousSection() {
        let ordered = BuoyDashboardSection.allCases
        guard let index = ordered.firstIndex(of: selectedSection) else { return }
        let previousIndex = index == 0 ? ordered.count - 1 : index - 1
        selectSection(ordered[previousIndex])
    }

    private func configureTypography() {
        brandEyebrowLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        brandEyebrowLabel.textColor = BuoyChrome.secondaryTextColor

        brandTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        brandTitleLabel.textColor = BuoyChrome.primaryTextColor

        brandSubtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        brandSubtitleLabel.textColor = BuoyChrome.secondaryTextColor

        sidebarHintLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        sidebarHintLabel.textColor = BuoyChrome.secondaryTextColor
        sidebarHintLabel.maximumNumberOfLines = 0

        sectionEyebrowLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        sectionEyebrowLabel.textColor = BuoyChrome.secondaryTextColor

        sectionTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        sectionTitleLabel.textColor = BuoyChrome.primaryTextColor

        sectionSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        sectionSubtitleLabel.textColor = BuoyChrome.secondaryTextColor
        sectionSubtitleLabel.maximumNumberOfLines = 0

        sectionShortcutLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        sectionShortcutLabel.textColor = BuoyChrome.accentColor
        sectionShortcutLabel.alignment = .right

        sectionHintLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        sectionHintLabel.textColor = BuoyChrome.secondaryTextColor
        sectionHintLabel.alignment = .right
    }

    private func buildLayout() {
        shellStack.orientation = .horizontal
        shellStack.spacing = 16
        shellStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shellStack)

        sidebarView.applyBuoySurface(cornerRadius: 22, fillColor: BuoyChrome.sidebarBackgroundColor)
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarWidthConstraint = sidebarView.widthAnchor.constraint(equalToConstant: 216)
        sidebarWidthConstraint?.isActive = true

        let brandStack = NSStackView(views: [brandEyebrowLabel, brandTitleLabel, brandSubtitleLabel])
        brandStack.orientation = .vertical
        brandStack.alignment = .leading
        brandStack.spacing = 4

        navStack.orientation = .vertical
        navStack.spacing = 8
        navStack.alignment = .leading

        for section in BuoyDashboardSection.allCases {
            let button = SidebarSectionButton(title: section.title, symbol: section.symbolName)
            button.target = self
            button.action = #selector(sidebarSectionPressed(_:))
            button.tag = section.rawValue

            let hintLabel = NSTextField(labelWithString: section.hotkeyHint)
            hintLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
            hintLabel.textColor = BuoyChrome.secondaryTextColor

            let row = NSStackView(views: [button, hintLabel])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false

            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 92).isActive = true
            navStack.addArrangedSubview(row)
            navButtons[section] = button
            navHintLabels[section] = hintLabel
        }

        let sidebarStack = NSStackView(views: [brandStack, navStack, NSView(), sidebarHintLabel])
        sidebarStack.orientation = .vertical
        sidebarStack.spacing = 18
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(sidebarStack)

        NSLayoutConstraint.activate([
            sidebarStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 16),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -16),
            sidebarStack.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 18),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: -18)
        ])

        headerView.applyBuoySurface(cornerRadius: 18, fillColor: BuoyChrome.elevatedBackgroundColor)
        contentSurface.applyBuoySurface(cornerRadius: 18, fillColor: BuoyChrome.contentBackgroundColor)

        headerTextStack.orientation = .vertical
        headerTextStack.alignment = .leading
        headerTextStack.spacing = 6
        headerTextStack.addArrangedSubview(sectionEyebrowLabel)
        headerTextStack.addArrangedSubview(sectionTitleLabel)
        headerTextStack.addArrangedSubview(sectionSubtitleLabel)

        headerMetaStack.orientation = .vertical
        headerMetaStack.alignment = .trailing
        headerMetaStack.spacing = 4
        headerMetaStack.addArrangedSubview(sectionShortcutLabel)
        headerMetaStack.addArrangedSubview(sectionHintLabel)

        headerTopStack.orientation = .horizontal
        headerTopStack.alignment = .top
        headerTopStack.spacing = 12
        headerTopStack.translatesAutoresizingMaskIntoConstraints = false
        headerTopStack.addArrangedSubview(headerTextStack)
        headerTopStack.addArrangedSubview(headerSpacer)
        headerTopStack.addArrangedSubview(headerMetaStack)

        headerRule.wantsLayer = true
        headerRule.layer?.backgroundColor = BuoyChrome.borderColor.cgColor
        headerRule.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(headerTopStack)
        headerView.addSubview(headerRule)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentSurface.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            headerTopStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 18),
            headerTopStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -18),
            headerTopStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            headerRule.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 18),
            headerRule.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -18),
            headerRule.topAnchor.constraint(equalTo: headerTopStack.bottomAnchor, constant: 14),
            headerRule.heightAnchor.constraint(equalToConstant: 1),
            headerRule.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            contentContainer.leadingAnchor.constraint(equalTo: contentSurface.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentSurface.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: contentSurface.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentSurface.bottomAnchor)
        ])

        mainStack.orientation = .vertical
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(headerView)
        mainStack.addArrangedSubview(contentSurface)

        shellStack.addArrangedSubview(sidebarView)
        shellStack.addArrangedSubview(mainStack)

        sidebarView.setContentHuggingPriority(.required, for: .horizontal)
        sidebarView.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            shellStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            shellStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            shellStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            shellStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 116)
        ])
    }

    private func swapContent(to controller: NSViewController) {
        guard currentController !== controller else { return }

        currentController?.view.removeFromSuperview()
        currentController = controller

        let childView = controller.view
        childView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(childView)

        NSLayoutConstraint.activate([
            childView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            childView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            childView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    private func refreshSelectionState() {
        let section = selectedSection
        sectionEyebrowLabel.stringValue = "SECTION \(section.rawValue + 1)"
        sectionTitleLabel.stringValue = section.title
        sectionSubtitleLabel.stringValue = section.subtitle
        sectionShortcutLabel.stringValue = section.hotkeyHint

        for (candidate, button) in navButtons {
            button.isSectionSelected = candidate == section
            button.toolTip = "\(candidate.title) \(candidate.hotkeyHint)"
        }
    }

    private func updateResponsiveChrome() {
        let width = view.bounds.width
        let compactSidebar = width < 980

        if compactSidebar != isSidebarCompact {
            isSidebarCompact = compactSidebar
            sidebarWidthConstraint?.constant = compactSidebar ? 84 : 216
            brandSubtitleLabel.isHidden = compactSidebar
            sidebarHintLabel.isHidden = compactSidebar
            navButtons.values.forEach { $0.compactMode = compactSidebar }
            navHintLabels.values.forEach { $0.isHidden = compactSidebar }
            navStack.alignment = compactSidebar ? .centerX : .leading
            brandTitleLabel.stringValue = compactSidebar ? "B" : buoyProductName
        }

        let compactHeader = width < 840
        headerTopStack.orientation = compactHeader ? .vertical : .horizontal
        headerSpacer.isHidden = compactHeader
        headerMetaStack.alignment = compactHeader ? .leading : .trailing
        sectionShortcutLabel.alignment = compactHeader ? .left : .right
        sectionHintLabel.alignment = compactHeader ? .left : .right
    }

    @objc
    private func sidebarSectionPressed(_ sender: NSButton) {
        guard let section = BuoyDashboardSection(rawValue: sender.tag) else { return }
        selectSection(section)
    }
}
