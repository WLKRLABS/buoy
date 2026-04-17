import AppKit
import Foundation

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

@main
enum BuoyAppMain {
    private static var retainedDelegate: BuoyAppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = BuoyAppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}

final class BuoyAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: BuoyWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidFinishRestoringWindows(_:)),
            name: NSApplication.didFinishRestoringWindowsNotification,
            object: NSApp
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppIcon()
        configureMainMenu()
        showMainWindow()

        // LaunchServices/AppKit can finish window restoration after didFinishLaunching.
        // Re-show on the next runloop so this utility always opens its single main window.
        DispatchQueue.main.async { [weak self] in
            self?.showMainWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if controller?.window?.isVisible != true {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func handleDidFinishRestoringWindows(_ notification: Notification) {
        if controller?.window?.isVisible != true {
            showMainWindow()
        }
    }

    private func showMainWindow() {
        if controller == nil {
            controller = BuoyWindowController()
        }

        controller?.showWindow(nil)
        controller?.ensureWindowFitsVisibleFrame()
        controller?.window?.makeKeyAndOrderFront(nil)
        controller?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.controller?.ensureWindowFitsVisibleFrame()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.controller?.ensureWindowFitsVisibleFrame()
        }
    }

    private func applyAppIcon() {
        guard
            let iconURL = Bundle.main.resourceURL?.appendingPathComponent("buoy-icon.png"),
            let iconImage = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        appMenu.addItem(withTitle: "About \(buoyProductName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit \(buoyProductName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let closeItem = NSMenuItem(title: "Close Window", action: #selector(closeMainWindow(_:)), keyEquivalent: "w")
        closeItem.keyEquivalentModifierMask = [.command]
        closeItem.target = self
        fileMenu.addItem(closeItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        for (index, section) in BuoyDashboardSection.navigationOrder.enumerated() {
            let item = NSMenuItem(title: section.title, action: #selector(selectSectionFromMenu(_:)), keyEquivalent: "\(index + 1)")
            item.keyEquivalentModifierMask = [.command]
            item.tag = section.rawValue
            item.target = self
            viewMenu.addItem(item)
        }

        viewMenu.addItem(.separator())

        let previousItem = NSMenuItem(title: "Previous Section", action: #selector(selectPreviousSection(_:)), keyEquivalent: "[")
        previousItem.keyEquivalentModifierMask = [.command]
        previousItem.target = self
        viewMenu.addItem(previousItem)

        let nextItem = NSMenuItem(title: "Next Section", action: #selector(selectNextSection(_:)), keyEquivalent: "]")
        nextItem.keyEquivalentModifierMask = [.command]
        nextItem.target = self
        viewMenu.addItem(nextItem)

        NSApp.mainMenu = mainMenu
    }

    @objc
    private func closeMainWindow(_ sender: Any?) {
        controller?.window?.performClose(sender)
    }

    @objc
    private func selectSectionFromMenu(_ sender: NSMenuItem) {
        guard let section = BuoyDashboardSection(rawValue: sender.tag) else { return }
        if controller == nil {
            controller = BuoyWindowController()
        }
        controller?.showWindow(nil)
        controller?.selectSection(section)
    }

    @objc
    private func selectNextSection(_ sender: Any?) {
        if controller == nil {
            controller = BuoyWindowController()
        }
        showMainWindow()
        controller?.selectNextSection()
    }

    @objc
    private func selectPreviousSection(_ sender: Any?) {
        if controller == nil {
            controller = BuoyWindowController()
        }
        showMainWindow()
        controller?.selectPreviousSection()
    }
}

final class BuoyWindowController: NSWindowController, NSWindowDelegate {
    private let bridge = ShellBridge()
    private let contentController = BuoyViewController()
    private lazy var mainController = BuoyMainViewController(powerVC: contentController)
    private var isApplyingVisibleFrameClamp = false
    private var hasScheduledVisibleFrameClamp = false

    init() {
        let initialFrame = Self.initialWindowFrame()
        let window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = buoyProductName
        window.setFrame(initialFrame, display: false)
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.disableSnapshotRestoration()
        window.minSize = NSSize(width: 920, height: 620)
        window.backgroundColor = BuoyChrome.windowBackgroundColor
        window.tabbingMode = .disallowed
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("BuoyToolbar"))
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        super.init(window: window)
        contentController.bridge = bridge
        window.delegate = self
        window.contentViewController = mainController
        window.setFrame(initialFrame, display: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func initialWindowFrame() -> NSRect {
        let preferred = NSSize(width: 1180, height: 760)
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: preferred)
        }

        let visible = screen.visibleFrame
        let width = min(preferred.width, max(720, visible.width - 48))
        let height = min(preferred.height, max(520, visible.height - 48))
        let x = visible.midX - (width / 2)
        let y = visible.midY - (height / 2)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    func selectSection(_ section: BuoyDashboardSection) {
        mainController.selectSection(section)
    }

    func selectNextSection() {
        mainController.selectNextSection()
    }

    func selectPreviousSection() {
        mainController.selectPreviousSection()
    }

    func ensureWindowFitsVisibleFrame() {
        applyVisibleFrameClampIfNeeded()
    }

    // Avoid re-entering AppKit's layout/resize pass by deferring clamp work.
    private func scheduleEnsureWindowFitsVisibleFrame() {
        guard !hasScheduledVisibleFrameClamp else { return }
        hasScheduledVisibleFrameClamp = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasScheduledVisibleFrameClamp = false
            self.applyVisibleFrameClampIfNeeded()
        }
    }

    private func applyVisibleFrameClampIfNeeded() {
        guard let window, !isApplyingVisibleFrameClamp else { return }

        let frame = clampedFrame(for: window, proposedFrame: window.frame)
        guard !window.frame.equalTo(frame) else { return }

        isApplyingVisibleFrameClamp = true
        defer { isApplyingVisibleFrameClamp = false }
        window.setFrame(frame, display: true, animate: false)
    }

    private func clampedFrame(for window: NSWindow, proposedFrame: NSRect) -> NSRect {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? proposedFrame
        let horizontalMargin: CGFloat = 48
        let verticalMargin: CGFloat = 72
        let maxWidth = max(window.minSize.width, visible.width - horizontalMargin)
        let maxHeight = max(window.minSize.height, visible.height - verticalMargin)

        var frame = proposedFrame
        frame.size.width = min(frame.width, maxWidth)
        frame.size.height = min(frame.height, maxHeight)

        if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
        }
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
        }
        if frame.maxY > visible.maxY {
            frame.origin.y = visible.maxY - frame.height
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }
        return frame
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        clampedFrame(
            for: sender,
            proposedFrame: NSRect(origin: sender.frame.origin, size: frameSize)
        ).size
    }

    func windowDidResize(_ notification: Notification) {
        scheduleEnsureWindowFitsVisibleFrame()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        scheduleEnsureWindowFitsVisibleFrame()
    }
}

final class BuoyViewController: NSViewController {
    var bridge: ShellBridge?

    private let modeCard = DashboardMetricCardView(title: "Mode")
    private let sourceCard = DashboardMetricCardView(title: "Power Source")
    private let batteryCard = DashboardMetricCardView(title: "Battery")
    private let lidCard = DashboardMetricCardView(title: "Closed Lid")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 210, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let detailGrid = AdaptiveGridView(minColumnWidth: 360, maxColumns: 2, rowSpacing: 12, columnSpacing: 12)

    private lazy var enabledSwitch = makeSwitch(title: "Enable Buoy mode")
    private lazy var clamSwitch = makeSwitch(title: "Allow closed-lid awake mode")
    private let displaySleepSlider = NSSlider(value: 10, minValue: 1, maxValue: 60, target: nil, action: nil)
    private let displaySleepValue = NSTextField(labelWithString: "10 min")
    private let batterySlider = NSSlider(value: 25, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let batteryValue = NSTextField(labelWithString: "25%")
    private let pollSlider = NSSlider(value: 20, minValue: 5, maxValue: 120, target: nil, action: nil)
    private let pollValue = NSTextField(labelWithString: "20 sec")
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private lazy var applyButton = makeButton(title: "Apply", action: #selector(applyPressed), tone: .accent)
    private lazy var turnOffButton = makeButton(title: "Turn Off", action: #selector(turnOffPressed), tone: .critical)
    private lazy var screenOffButton = makeButton(title: "Sleep Display", action: #selector(screenOffPressed), tone: .neutral)
    private lazy var refreshButton = makeButton(title: "Refresh", action: #selector(refreshPressed), tone: .neutral)

    private let behaviorSymbolView = NSImageView()
    private let behaviorTitleLabel = NSTextField(labelWithString: "Checking policy")
    private let behaviorDetailLabel = NSTextField(wrappingLabelWithString: "Buoy is reading the current power state.")
    private let currentBehaviorValueLabel = NSTextField(labelWithString: "Checking...")
    private let computerBehaviorValueLabel = NSTextField(labelWithString: "Restore normal sleep")
    private let displayBehaviorValueLabel = NSTextField(labelWithString: "System default")
    private let lidBehaviorValueLabel = NSTextField(labelWithString: "Normal sleep")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Loading status...")
    private let footerLabel = NSTextField(wrappingLabelWithString: "Buoy remains fully scriptable through the CLI. The readout below matches the installed `buoy` binary.")

    private var currentStatus: BuoyStatus?
    private var isBusy = false {
        didSet { updateBusyState() }
    }

    override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        buildLayout()
        wireActions()
        refreshStatus()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyAppearance()
    }

    private func configureAppearance() {
        footerLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        footerLabel.maximumNumberOfLines = 2
        footerLabel.textColor = BuoyChrome.secondaryTextColor

        behaviorTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        behaviorTitleLabel.textColor = BuoyChrome.primaryTextColor

        behaviorDetailLabel.font = .systemFont(ofSize: 12)
        behaviorDetailLabel.maximumNumberOfLines = 0
        behaviorDetailLabel.textColor = BuoyChrome.secondaryTextColor

        [currentBehaviorValueLabel, computerBehaviorValueLabel, displayBehaviorValueLabel, lidBehaviorValueLabel].forEach {
            $0.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            $0.alignment = .right
            $0.lineBreakMode = .byTruncatingMiddle
            $0.textColor = BuoyChrome.primaryTextColor
        }

        behaviorSymbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        behaviorSymbolView.imageScaling = .scaleProportionallyDown

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.maximumNumberOfLines = 0
        statusLabel.textColor = BuoyChrome.primaryTextColor

        appearancePopup.addItems(withTitles: AppearanceMode.allCases.map(\.rawValue))
        appearancePopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue)
        applyAppearance()
    }

    private func buildLayout() {
        let (_, _, stack) = installDashboardDocumentStack(in: view)

        summaryGrid.setItems([modeCard, sourceCard, batteryCard, lidCard])

        let currentStage = DashboardStageView(
            sectionLabel: "Current",
            title: "Current Policy",
            subtitle: "Live state, power source, battery floor, and the effective sleep behavior."
        )
        let currentBody = DashboardSplitColumnsView(
            primary: summaryGrid,
            secondary: makeBehaviorSummary(),
            collapseWidth: 940,
            preferredSecondaryWidth: 360
        )
        currentStage.pinContent(currentBody)

        let controlsStage = DashboardStageView(
            sectionLabel: "Controls",
            title: "Configuration And Actions",
            subtitle: "Set the policy deliberately, then apply or restore with explicit actions."
        )
        let controlsBody = DashboardSplitColumnsView(
            primary: makeConfigurationView(),
            secondary: makeActionPanel(),
            collapseWidth: 940,
            preferredSecondaryWidth: 320
        )
        controlsStage.pinContent(controlsBody)

        let inspectStage = DashboardStageView(
            sectionLabel: "Inspect",
            title: "CLI Readout",
            subtitle: "Plain-text status from the installed command line tool remains available as the lower inspection layer."
        )
        inspectStage.pinContent(makeReadoutPanel())

        stack.addArrangedSubview(currentStage)
        stack.addArrangedSubview(controlsStage)
        stack.addArrangedSubview(inspectStage)
        [currentStage, controlsStage, inspectStage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        inspectStage.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
    }

    private func wireActions() {
        displaySleepSlider.target = self
        displaySleepSlider.action = #selector(sliderChanged(_:))
        batterySlider.target = self
        batterySlider.action = #selector(sliderChanged(_:))
        pollSlider.target = self
        pollSlider.action = #selector(sliderChanged(_:))
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)
        clamSwitch.target = self
        clamSwitch.action = #selector(enabledChanged)

        updateSliderLabels()
        updateBusyState()
        updateBehaviorSummary()
    }

    private func makeSwitch(title: String) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.setButtonType(.switch)
        button.font = .systemFont(ofSize: 13, weight: .medium)
        return button
    }

    private func makeButton(title: String, action: Selector, tone: DashboardMetricTone) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.contentTintColor = tone.color
        return button
    }

    private func makeConfigurationView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.addArrangedSubview(enabledSwitch)
        stack.addArrangedSubview(clamSwitch)
        stack.addArrangedSubview(makeSliderRow(title: "Display sleep", slider: displaySleepSlider, valueLabel: displaySleepValue))
        stack.addArrangedSubview(makeSliderRow(title: "Battery floor", slider: batterySlider, valueLabel: batteryValue))
        stack.addArrangedSubview(makeSliderRow(title: "Poll interval", slider: pollSlider, valueLabel: pollValue))
        stack.addArrangedSubview(makeAppearanceRow())
        return stack
    }

    private func makeBehaviorSummary() -> NSView {
        let titleStack = NSStackView(views: [behaviorTitleLabel, behaviorDetailLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 4

        let header = NSStackView(views: [behaviorSymbolView, titleStack])
        header.orientation = .horizontal
        header.alignment = .top
        header.spacing = 12

        let facts = NSStackView(views: [
            makeBehaviorRow(title: "Current state", valueLabel: currentBehaviorValueLabel),
            makeBehaviorRow(title: "Computer sleep", valueLabel: computerBehaviorValueLabel),
            makeBehaviorRow(title: "Display sleep", valueLabel: displayBehaviorValueLabel),
            makeBehaviorRow(title: "Closed lid", valueLabel: lidBehaviorValueLabel)
        ])
        facts.orientation = .vertical
        facts.spacing = 10

        let container = NSView()
        container.applyBuoySurface(cornerRadius: 8, fillColor: BuoyChrome.elevatedBackgroundColor)

        let stack = NSStackView(views: [header, facts])
        stack.orientation = .vertical
        stack.spacing = 12
        container.addSubview(stack)
        stack.pinEdges(
            to: container,
            insets: NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        )
        return container
    }

    private func makeBehaviorRow(title: String, valueLabel: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = BuoyChrome.secondaryTextColor

        let row = NSStackView(views: [label, NSView(), valueLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = BuoyChrome.primaryTextColor

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.alignment = .right
        valueLabel.textColor = BuoyChrome.secondaryTextColor

        let header = NSStackView(views: [titleLabel, NSView(), valueLabel])
        header.orientation = .horizontal
        header.alignment = .centerY

        let stack = NSStackView(views: [header, slider])
        stack.orientation = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeAppearanceRow() -> NSView {
        let title = NSTextField(labelWithString: "Appearance")
        title.font = .systemFont(ofSize: 12)
        title.textColor = BuoyChrome.primaryTextColor

        let stack = NSStackView(views: [title, NSView(), appearancePopup])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        return stack
    }

    private func makeActionLayout() -> NSView {
        let primaryRow = NSStackView(views: [applyButton, refreshButton, screenOffButton, NSView()])
        primaryRow.orientation = .horizontal
        primaryRow.alignment = .centerY
        primaryRow.spacing = 10

        let destructiveRow = NSStackView(views: [NSView(), turnOffButton])
        destructiveRow.orientation = .horizontal
        destructiveRow.alignment = .centerY
        destructiveRow.spacing = 10

        let stack = NSStackView(views: [primaryRow, destructiveRow])
        stack.orientation = .vertical
        stack.spacing = 10
        return stack
    }

    private func makeActionPanel() -> NSView {
        let note = NSTextField(wrappingLabelWithString: "Apply commits the current sliders and toggles in one privileged step. Turn Off restores the saved normal AC sleep settings.")
        note.font = .systemFont(ofSize: 12)
        note.textColor = BuoyChrome.secondaryTextColor
        note.maximumNumberOfLines = 0

        let footer = NSTextField(wrappingLabelWithString: "Sleep Display stays non-destructive. Refresh rehydrates the state from the installed `buoy` binary.")
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = BuoyChrome.secondaryTextColor
        footer.maximumNumberOfLines = 0

        let content = NSStackView(views: [makeActionLayout(), note, footer])
        content.orientation = .vertical
        content.spacing = 12

        let panel = NSView()
        panel.applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)
        panel.addSubview(content)
        content.pinEdges(to: panel, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return panel
    }

    private func makeReadoutPanel() -> NSView {
        let content = NSStackView(views: [statusLabel, footerLabel])
        content.orientation = .vertical
        content.spacing = 12

        let panel = NSView()
        panel.applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)
        panel.addSubview(content)
        content.pinEdges(to: panel, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return panel
    }

    private func updateSliderLabels() {
        displaySleepValue.stringValue = "\(Int(displaySleepSlider.doubleValue)) min"
        batteryValue.stringValue = "\(Int(batterySlider.doubleValue))%"
        pollValue.stringValue = "\(Int(pollSlider.doubleValue)) sec"
    }

    private func updateBusyState() {
        let controls: [NSControl] = [
            enabledSwitch, clamSwitch, displaySleepSlider, batterySlider, pollSlider,
            appearancePopup, applyButton, turnOffButton, screenOffButton, refreshButton
        ]
        controls.forEach { $0.isEnabled = !isBusy }
    }

    @objc
    private func sliderChanged(_ sender: NSSlider) {
        updateSliderLabels()
        updateBehaviorSummary()
    }

    @objc
    private func enabledChanged() {
        clamSwitch.isEnabled = enabledSwitch.state == .on
        updateBehaviorSummary()
    }

    @objc
    private func appearanceChanged() {
        UserDefaults.standard.set(appearancePopup.titleOfSelectedItem ?? AppearanceMode.system.rawValue, forKey: "appearance_mode")
        applyAppearance()
    }

    private func applyAppearance() {
        guard let selected = appearancePopup.titleOfSelectedItem, let mode = AppearanceMode(rawValue: selected) else { return }
        switch mode {
        case .system:
            view.window?.appearance = nil
            NSApp.appearance = nil
        case .light:
            let appearance = NSAppearance(named: .aqua)
            view.window?.appearance = appearance
            NSApp.appearance = appearance
        case .dark:
            let appearance = NSAppearance(named: .darkAqua)
            view.window?.appearance = appearance
            NSApp.appearance = appearance
        }
        updateBehaviorSummary()
    }

    private func updateBehaviorSummary() {
        let serverModeEnabled = enabledSwitch.state == .on
        let closedLidEnabled = serverModeEnabled && clamSwitch.state == .on
        let displaySleepMinutes = Int(displaySleepSlider.doubleValue)
        let batteryFloor = Int(batterySlider.doubleValue)

        let currentPowerSource: String
        switch currentStatus?.system.powerSource {
        case "AC Power":
            currentPowerSource = "on AC"
        case "Battery Power":
            currentPowerSource = "on battery"
        default:
            currentPowerSource = ""
        }

        if let sleepDisabled = currentStatus?.system.sleepDisabled {
            currentBehaviorValueLabel.stringValue = sleepDisabled == 1
                ? currentPowerSource.isEmpty ? "Awake now" : "Awake now \(currentPowerSource)"
                : "Sleep allowed now"
        } else {
            currentBehaviorValueLabel.stringValue = "Checking..."
        }

        if serverModeEnabled {
            behaviorTitleLabel.stringValue = closedLidEnabled ? "Awake on AC and with the lid closed" : "Awake on AC"
            behaviorDetailLabel.stringValue = closedLidEnabled
                ? "Buoy prevents computer sleep while plugged in and can also hold the Mac awake with the lid closed while charging or above \(batteryFloor)% battery."
                : "Buoy prevents computer sleep while plugged in. The display can still sleep after \(displaySleepMinutes) minutes."
            computerBehaviorValueLabel.stringValue = "Keep awake on AC"
            displayBehaviorValueLabel.stringValue = "After \(displaySleepMinutes) min"
            lidBehaviorValueLabel.stringValue = closedLidEnabled ? "Awake above \(batteryFloor)%" : "Normal sleep"
            behaviorSymbolView.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Awake on AC")
            behaviorSymbolView.contentTintColor = BuoyChrome.accentColor
        } else {
            behaviorTitleLabel.stringValue = "Normal sleep restored"
            behaviorDetailLabel.stringValue = "When Buoy mode is off, Buoy stops holding the Mac awake and restores the saved AC power settings."
            computerBehaviorValueLabel.stringValue = "Restore normal sleep"
            displayBehaviorValueLabel.stringValue = "System default"
            lidBehaviorValueLabel.stringValue = "System default"
            behaviorSymbolView.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Normal sleep restored")
            behaviorSymbolView.contentTintColor = BuoyChrome.secondaryTextColor
        }

        updateSummaryCards()
    }

    private func updateSummaryCards() {
        let enabled = enabledSwitch.state == .on
        let sleepValue = currentStatus?.mode.displaySleepMinutes ?? Int(displaySleepSlider.doubleValue)
        let batteryPercent = currentStatus?.system.batteryPercent
        let powerSource = currentStatus?.system.powerSource ?? "Unknown"

        modeCard.set(
            value: enabled ? "Enabled" : "Off",
            detail: enabled ? "Display sleeps after \(sleepValue) min" : "Restores normal AC sleep behavior",
            tone: enabled ? .accent : .neutral
        )
        sourceCard.set(
            value: powerSource,
            detail: currentStatus?.system.sleepDisabled == 1 ? "Sleep currently prevented" : "Sleep currently allowed",
            tone: powerSource == "AC Power" ? .accent : .neutral
        )
        batteryCard.set(
            value: batteryPercent.map { "\($0)%" } ?? "No battery",
            detail: "Closed-lid floor \(Int(batterySlider.doubleValue))%",
            tone: (batteryPercent ?? 100) < 20 ? .warning : .accent
        )
        lidCard.set(
            value: clamSwitch.state == .on && enabled ? "Awake" : "Normal",
            detail: clamSwitch.state == .on && enabled ? "Poll every \(Int(pollSlider.doubleValue)) sec" : "Closed lid follows system default",
            tone: clamSwitch.state == .on && enabled ? .accent : .neutral
        )
    }

    @objc
    private func applyPressed() {
        guard let bridge else { return }
        isBusy = true

        if enabledSwitch.state == .off {
            bridge.runPrivileged(arguments: ["off"]) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleCommandResult(result)
                }
            }
            return
        }

        var arguments = [
            "apply",
            "--display-sleep", "\(Int(displaySleepSlider.doubleValue))",
            "--clam-min-battery", "\(Int(batterySlider.doubleValue))",
            "--clam-poll-seconds", "\(Int(pollSlider.doubleValue))"
        ]
        if clamSwitch.state == .on {
            arguments.append("--clam")
        }

        bridge.runPrivileged(arguments: arguments) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func turnOffPressed() {
        guard let bridge else { return }
        isBusy = true
        bridge.runPrivileged(arguments: ["off"]) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func screenOffPressed() {
        guard let bridge else { return }
        isBusy = true
        bridge.run(arguments: ["screen-off"]) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func refreshPressed() {
        refreshStatus()
    }

    private func refreshStatus() {
        guard let bridge else { return }
        isBusy = true
        bridge.fetchStatus { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let status):
                    self.currentStatus = status
                    self.render(status: status)
                case .failure(let error):
                    self.statusLabel.stringValue = "Status unavailable.\n\(error.localizedDescription)"
                    self.updateBehaviorSummary()
                }
            }
        }
    }

    private func render(status: BuoyStatus) {
        enabledSwitch.state = status.mode.enabled ? .on : .off
        clamSwitch.state = status.clam.enabled ? .on : .off
        clamSwitch.isEnabled = status.mode.enabled
        displaySleepSlider.doubleValue = Double(status.mode.displaySleepMinutes ?? 10)
        batterySlider.doubleValue = Double(status.clam.minBattery ?? 25)
        pollSlider.doubleValue = Double(status.clam.pollSeconds ?? 20)
        updateSliderLabels()
        updateBehaviorSummary()

        var lines: [String] = []
        lines.append("power       \(status.system.powerSource)")
        if let battery = status.system.batteryPercent {
            lines.append("battery     \(battery)%")
        }
        if let sleepDisabled = status.system.sleepDisabled {
            lines.append("sleep now   \(sleepDisabled == 1 ? "prevented" : "allowed")")
        }
        lines.append("mode        \(status.mode.enabled ? "enabled" : "disabled")")
        if let displaySleep = status.mode.displaySleepMinutes {
            lines.append("display     \(displaySleep) min")
        }
        if status.clam.enabled {
            lines.append("closed lid  on")
            if let pid = status.clam.monitorPID {
                lines.append("monitor     \(status.clam.monitorRunning ? "pid \(pid)" : "stopped")")
            }
        } else {
            lines.append("closed lid  off")
        }
        statusLabel.stringValue = lines.joined(separator: "\n")
        updateSummaryCards()
    }

    private func handleCommandResult(_ result: Result<String, Error>) {
        isBusy = false
        switch result {
        case .success(let output):
            if !output.isEmpty {
                statusLabel.stringValue = output
            }
            refreshStatus()
        case .failure(let error):
            statusLabel.stringValue = "Command failed.\n\(error.localizedDescription)"
        }
    }
}

final class ShellBridge {
    private let queue = DispatchQueue(label: "buoy.shell", qos: .userInitiated)

    func fetchStatus(completion: @escaping (Result<BuoyStatus, Error>) -> Void) {
        run(arguments: ["status", "--json"]) { result in
            switch result {
            case .success(let output):
                do {
                    let decoder = JSONDecoder()
                    let status = try decoder.decode(BuoyStatus.self, from: Data(output.utf8))
                    completion(.success(status))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func run(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let output = try self.execute(arguments: arguments)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func runPrivileged(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let output = try self.executePrivileged(arguments: arguments)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func execute(arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: resolvedCLIPath())
        task.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        task.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw BuoyError.commandFailed(stderr.isEmpty ? stdout : stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func executePrivileged(arguments: [String]) throws -> String {
        let command = ([resolvedCLIPath()] + arguments).map(shellEscape(_:)).joined(separator: " ")
        let script = #"do shell script "\#(appleScriptEscape(command))" with administrator privileges"#

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        task.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw BuoyError.commandFailed(stderr.isEmpty ? stdout : stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedCLIPath() -> String {
        let fileManager = FileManager.default

        if let bundled = Bundle.main.path(forResource: buoyCommandName, ofType: nil, inDirectory: "bin") {
            return bundled
        }

        let candidates = [
            "/usr/local/bin/\(buoyCommandName)",
            "\(NSHomeDirectory())/.local/bin/\(buoyCommandName)",
            "/opt/homebrew/bin/\(buoyCommandName)"
        ]

        if let first = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return first
        }

        return buoyCommandName
    }

    private func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
