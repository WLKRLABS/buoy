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

        for section in BuoyDashboardSection.allCases {
            let item = NSMenuItem(title: section.title, action: #selector(selectSectionFromMenu(_:)), keyEquivalent: "\(section.rawValue + 1)")
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
        window.minSize = NSSize(width: 720, height: 520)
        window.backgroundColor = BuoyChrome.windowBackgroundColor
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

    private let titleLabel = NSTextField(labelWithString: buoyProductName)
    private let subtitleLabel = NSTextField(labelWithString: "Keep this Mac server-ready while plugged in.")
    private let controlsPanel = NSBox()
    private let statusPanel = NSBox()
    private let behaviorPanel = NSBox()

    private lazy var enabledSwitch = makeSwitch(title: "Server mode")
    private lazy var clamSwitch = makeSwitch(title: "Closed-lid awake")
    private let displaySleepSlider = NSSlider(value: 10, minValue: 1, maxValue: 60, target: nil, action: nil)
    private let displaySleepValue = NSTextField(labelWithString: "10 min")
    private let batterySlider = NSSlider(value: 25, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let batteryValue = NSTextField(labelWithString: "25%")
    private let pollSlider = NSSlider(value: 20, minValue: 5, maxValue: 120, target: nil, action: nil)
    private let pollValue = NSTextField(labelWithString: "20 sec")
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private lazy var applyButton = makeButton(title: "Apply", action: #selector(applyPressed))
    private lazy var turnOffButton = makeButton(title: "Turn Off", action: #selector(turnOffPressed))
    private lazy var screenOffButton = makeButton(title: "Sleep Display", action: #selector(screenOffPressed))
    private lazy var refreshButton = makeButton(title: "Refresh", action: #selector(refreshPressed))

    private let behaviorSymbolView = NSImageView()
    private let behaviorTitleLabel = NSTextField(labelWithString: "Checking sleep behavior")
    private let behaviorDetailLabel = NSTextField(wrappingLabelWithString: "Buoy is reading the current power state.")
    private let currentBehaviorValueLabel = NSTextField(labelWithString: "Checking...")
    private let computerBehaviorValueLabel = NSTextField(labelWithString: "Restore normal sleep")
    private let displayBehaviorValueLabel = NSTextField(labelWithString: "System default")
    private let lidBehaviorValueLabel = NSTextField(labelWithString: "Normal sleep")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Loading status...")
    private let footerLabel = NSTextField(wrappingLabelWithString: "Buoy stays scriptable through the CLI. Use ⌘1–7 to move between sections without leaving the keyboard.")

    private var currentStatus: BuoyStatus?
    private var isBusy = false {
        didSet { updateBusyState() }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        buildLayout()
        wireActions()
        refreshColorPalette()
        refreshStatus()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyAppearance()
    }

    private func configureAppearance() {
        titleLabel.font = NSFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = BuoyChrome.primaryTextColor
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor

        footerLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        footerLabel.maximumNumberOfLines = 0
        footerLabel.textColor = BuoyChrome.secondaryTextColor

        behaviorTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        behaviorDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        behaviorDetailLabel.maximumNumberOfLines = 0
        [currentBehaviorValueLabel, computerBehaviorValueLabel, displayBehaviorValueLabel, lidBehaviorValueLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            $0.alignment = .right
            $0.lineBreakMode = .byWordWrapping
            $0.maximumNumberOfLines = 2
        }
        behaviorSymbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        behaviorSymbolView.imageScaling = .scaleProportionallyDown

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.maximumNumberOfLines = 0

        appearancePopup.addItems(withTitles: AppearanceMode.allCases.map(\.rawValue))
        appearancePopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue)
        applyAppearance()
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

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
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
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 920),
            stack.widthAnchor.constraint(lessThanOrEqualTo: documentView.widthAnchor, constant: -48)
        ])

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 6

        let panel = makePanel(controlsPanel)
        let panelStack = NSStackView()
        panelStack.orientation = .vertical
        panelStack.spacing = 14
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(panelStack)
        NSLayoutConstraint.activate([
            panelStack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 18),
            panelStack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -18),
            panelStack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 18),
            panelStack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -18)
        ])

        panelStack.addArrangedSubview(makeBehaviorSummary())
        panelStack.addArrangedSubview(enabledSwitch)
        panelStack.addArrangedSubview(clamSwitch)
        panelStack.addArrangedSubview(makeSliderRow(title: "Display sleep", slider: displaySleepSlider, valueLabel: displaySleepValue))
        panelStack.addArrangedSubview(makeSliderRow(title: "Battery floor", slider: batterySlider, valueLabel: batteryValue))
        panelStack.addArrangedSubview(makeSliderRow(title: "Poll interval", slider: pollSlider, valueLabel: pollValue))
        panelStack.addArrangedSubview(makeAppearanceRow())
        panelStack.addArrangedSubview(makeButtonRow())

        let statusPanel = makePanel(self.statusPanel)
        let statusStack = NSStackView(views: [statusLabel])
        statusStack.orientation = .vertical
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusPanel.contentView?.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.leadingAnchor.constraint(equalTo: statusPanel.contentView!.leadingAnchor, constant: 18),
            statusStack.trailingAnchor.constraint(equalTo: statusPanel.contentView!.trailingAnchor, constant: -18),
            statusStack.topAnchor.constraint(equalTo: statusPanel.contentView!.topAnchor, constant: 18),
            statusStack.bottomAnchor.constraint(equalTo: statusPanel.contentView!.bottomAnchor, constant: -18)
        ])

        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(panel)
        stack.addArrangedSubview(statusPanel)
        stack.addArrangedSubview(footerLabel)
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

    private func makePanel(_ box: NSBox) -> NSBox {
        box.boxType = .custom
        box.cornerRadius = 16
        box.borderWidth = 1
        box.contentViewMargins = NSSize(width: 0, height: 0)
        return box
    }

    private func makeSwitch(title: String) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.setButtonType(.switch)
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return button
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .recessed
        button.contentTintColor = title == "Apply" ? BuoyChrome.accentColor : BuoyChrome.primaryTextColor
        return button
    }

    private func makeBehaviorSummary() -> NSView {
        let panel = makePanel(behaviorPanel)
        panel.borderWidth = 0

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
        facts.spacing = 8

        let stack = NSStackView(views: [header, facts])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -14)
        ])

        return panel
    }

    private func makeBehaviorRow(title: String, valueLabel: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [label, NSView(), valueLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        return row
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.alignment = .right

        let header = NSStackView(views: [titleLabel, NSView(), valueLabel])
        header.orientation = .horizontal
        header.distribution = .fill

        let stack = NSStackView(views: [header, slider])
        stack.orientation = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeAppearanceRow() -> NSView {
        let title = NSTextField(labelWithString: "Appearance")
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [title, NSView(), appearancePopup])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        return stack
    }

    private func makeButtonRow() -> NSView {
        let grid = AdaptiveGridView(minColumnWidth: 150, maxColumns: 4, rowSpacing: 10, columnSpacing: 10)
        grid.setItems([applyButton, turnOffButton, screenOffButton, refreshButton])
        return grid
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
        refreshColorPalette()
    }

    private func refreshColorPalette() {
        view.layer?.backgroundColor = .clear
        controlsPanel.fillColor = BuoyChrome.panelBackgroundColor
        controlsPanel.borderColor = BuoyChrome.borderColor
        behaviorPanel.fillColor = BuoyChrome.elevatedBackgroundColor
        behaviorPanel.borderColor = BuoyChrome.borderColor
        statusPanel.fillColor = BuoyChrome.panelBackgroundColor
        statusPanel.borderColor = BuoyChrome.borderColor

        titleLabel.textColor = BuoyChrome.primaryTextColor
        subtitleLabel.textColor = BuoyChrome.secondaryTextColor
        footerLabel.textColor = BuoyChrome.secondaryTextColor
        behaviorTitleLabel.textColor = BuoyChrome.primaryTextColor
        behaviorDetailLabel.textColor = BuoyChrome.secondaryTextColor
        [currentBehaviorValueLabel, computerBehaviorValueLabel, displayBehaviorValueLabel, lidBehaviorValueLabel].forEach {
            $0.textColor = BuoyChrome.primaryTextColor
        }
        behaviorSymbolView.contentTintColor = enabledSwitch.state == .on ? BuoyChrome.accentColor : BuoyChrome.secondaryTextColor
        statusLabel.textColor = BuoyChrome.primaryTextColor
        displaySleepValue.textColor = BuoyChrome.secondaryTextColor
        batteryValue.textColor = BuoyChrome.secondaryTextColor
        pollValue.textColor = BuoyChrome.secondaryTextColor
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
        } else {
            behaviorTitleLabel.stringValue = "Normal sleep restored"
            behaviorDetailLabel.stringValue = "When Server mode is off, Buoy stops holding the Mac awake and restores the saved AC power settings."
            computerBehaviorValueLabel.stringValue = "Restore normal sleep"
            displayBehaviorValueLabel.stringValue = "System default"
            lidBehaviorValueLabel.stringValue = "System default"
            behaviorSymbolView.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Normal sleep restored")
        }

        refreshColorPalette()
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
