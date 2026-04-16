import AppKit
import Foundation

public final class StorageViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private enum Column {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let kind = NSUserInterfaceItemIdentifier("kind")
        static let category = NSUserInterfaceItemIdentifier("category")
        static let size = NSUserInterfaceItemIdentifier("size")
        static let signal = NSUserInterfaceItemIdentifier("signal")
        static let path = NSUserInterfaceItemIdentifier("path")
    }

    private let scanner = StorageScanner()
    private let accessManager = StorageAccessManager()
    private let cacheStore = StorageCacheStore()
    private let refreshPolicy = StorageRefreshPolicy()
    private let searchField = NSSearchField()
    private let scopePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let kindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton(title: "Deep Scan", target: nil, action: nil)
    private let revealButton = NSButton(title: "Reveal in Finder", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let stateLabel = NSTextField(labelWithString: "—")
    private let summaryLabel = NSTextField(labelWithString: "0 heavy items")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Run a storage scan to see where disk space is actually going.")
    private let usedCard = StorageSummaryCardView(title: "Disk Used")
    private let explainedCard = StorageSummaryCardView(title: "Explained")
    private let cleanupCard = StorageSummaryCardView(title: "Cleanup Focus")
    private let systemCard = StorageSummaryCardView(title: "System + Hidden")
    private let breakdownView = StorageBreakdownView()
    private let breakdownLabel = NSTextField(wrappingLabelWithString: "No storage scan yet.")
    private let highlightsLabel = NSTextField(wrappingLabelWithString: "The storage view scans root, home, apps, caches, and developer folders so Finder-style “System Data” is less opaque.")
    private let accessSummaryLabel = NSTextField(wrappingLabelWithString: "Protected folders are opt-in. Buoy saves access bookmarks so your choices survive app relaunches.")
    private let customLocationsSwitch = NSSwitch()
    private let customLocationsStatusLabel = NSTextField(labelWithString: "")
    private let customLocationsButton = NSButton(title: "Choose…", target: nil, action: nil)
    private let scrollView = NSScrollView()
    private let table = DashboardTableContainer(columns: [
        (Column.name, "Name", 220),
        (Column.kind, "Kind", 80),
        (Column.category, "Category", 115),
        (Column.size, "Size", 110),
        (Column.signal, "Signal", 110),
        (Column.path, "Path", 430)
    ])

    private var scanSnapshot: StorageScanSnapshot?
    private var visibleItems: [StorageItem] = []
    private var hasLoadedInitialState = false
    private var snapshotSource: StorageSnapshotSource = .seed
    private var cacheStatus: StorageCacheStatus = .partial
    private var lastDeepScanAt: Date?
    private var activeScanMode: StorageScanMode?
    private var protectedSwitches: [StorageProtectedScope: NSSwitch] = [:]
    private var protectedStatusLabels: [StorageProtectedScope: NSTextField] = [:]
    private var protectedButtons: [StorageProtectedScope: NSButton] = [:]

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        wireActions()
        applyEmptyState()
        refreshAccessControls()
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        handleStorageTabOpen()
    }

    private func buildLayout() {
        searchField.placeholderString = "Search name or path"
        searchField.delegate = self

        scopePopup.addItems(withTitles: StorageScopeFilter.allCases.map(\.rawValue))
        scopePopup.selectItem(withTitle: StorageScopeFilter.all.rawValue)

        kindPopup.addItems(withTitles: StorageKindFilter.allCases.map(\.rawValue))
        kindPopup.selectItem(withTitle: StorageKindFilter.all.rawValue)

        sortPopup.addItems(withTitles: StorageSortKey.allCases.map(\.rawValue))
        sortPopup.selectItem(withTitle: StorageSortKey.size.rawValue)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = BuoyChrome.secondaryTextColor
        stateLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        stateLabel.textColor = BuoyChrome.secondaryTextColor
        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = BuoyChrome.secondaryTextColor
        statusLabel.maximumNumberOfLines = 0
        breakdownLabel.maximumNumberOfLines = 0
        highlightsLabel.maximumNumberOfLines = 0
        accessSummaryLabel.maximumNumberOfLines = 0
        breakdownLabel.font = .systemFont(ofSize: 12)
        highlightsLabel.font = .systemFont(ofSize: 12)
        accessSummaryLabel.font = .systemFont(ofSize: 12)
        breakdownLabel.textColor = BuoyChrome.primaryTextColor
        highlightsLabel.textColor = BuoyChrome.secondaryTextColor
        accessSummaryLabel.textColor = BuoyChrome.secondaryTextColor

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        refreshButton.bezelStyle = .recessed
        refreshButton.contentTintColor = BuoyChrome.accentColor
        revealButton.bezelStyle = .recessed
        revealButton.contentTintColor = BuoyChrome.primaryTextColor

        table.tableView.delegate = self
        table.tableView.dataSource = self
        table.tableView.target = self
        table.tableView.doubleAction = #selector(revealSelection)

        let cards = AdaptiveGridView(minColumnWidth: 220, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
        cards.setItems([usedCard, explainedCard, cleanupCard, systemCard])

        let breakdownStack = NSStackView(views: [breakdownView, breakdownLabel, highlightsLabel])
        breakdownStack.orientation = .vertical
        breakdownStack.spacing = 10
        breakdownView.heightAnchor.constraint(equalToConstant: 94).isActive = true

        let breakdownSection = DashboardSectionView(title: "Where Space Is Going")
        breakdownSection.pinContent(breakdownStack, top: 38, bottom: 14)

        let accessSection = buildAccessSection()

        let searchRow = NSStackView(views: [label("SEARCH"), searchField, label("SCOPE"), scopePopup])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8

        let filterRow = NSStackView(views: [label("KIND"), kindPopup, label("SORT"), sortPopup, refreshButton, revealButton, NSView()])
        filterRow.orientation = .horizontal
        filterRow.alignment = .centerY
        filterRow.spacing = 8

        let scanRow = NSStackView(views: [spinner, stateLabel, timestampLabel, NSView(), summaryLabel])
        scanRow.orientation = .horizontal
        scanRow.alignment = .centerY
        scanRow.spacing = 8

        let tableStack = NSStackView(views: [searchRow, filterRow, scanRow, statusLabel, table])
        tableStack.orientation = .vertical
        tableStack.spacing = 10

        let itemsSection = DashboardSectionView(title: "Largest Files & Folders")
        itemsSection.pinContent(tableStack, top: 38, bottom: 14)

        let stack = NSStackView(views: [cards, accessSection, breakdownSection, itemsSection])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let (_, documentView) = installVerticalScrollContainer(in: view)
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20),
            accessSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            itemsSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
    }

    private func buildAccessSection() -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 10

        for (index, scope) in StorageProtectedScope.allCases.enumerated() {
            let toggle = NSSwitch()
            toggle.tag = index
            toggle.target = self
            toggle.action = #selector(protectedToggleChanged(_:))
            protectedSwitches[scope] = toggle

            let status = NSTextField(labelWithString: "")
            status.font = .systemFont(ofSize: 11)
            status.textColor = BuoyChrome.secondaryTextColor
            status.lineBreakMode = .byTruncatingMiddle
            protectedStatusLabels[scope] = status

            let button = NSButton(title: "Grant…", target: self, action: #selector(protectedGrantPressed(_:)))
            button.tag = index
            protectedButtons[scope] = button

            let title = NSTextField(labelWithString: scope.title)
            title.font = .systemFont(ofSize: 12, weight: .semibold)
            title.textColor = BuoyChrome.primaryTextColor

            let detail = NSTextField(wrappingLabelWithString: scope.note)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = BuoyChrome.secondaryTextColor
            detail.maximumNumberOfLines = 0

            let labels = NSStackView(views: [title, detail, status])
            labels.orientation = .vertical
            labels.spacing = 2

            let row = NSStackView(views: [toggle, labels, NSView(), button])
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 12
            rows.addArrangedSubview(row)
        }

        customLocationsSwitch.target = self
        customLocationsSwitch.action = #selector(customLocationsToggleChanged(_:))
        customLocationsButton.target = self
        customLocationsButton.action = #selector(chooseCustomLocationsPressed)
        customLocationsStatusLabel.font = .systemFont(ofSize: 11)
        customLocationsStatusLabel.textColor = BuoyChrome.secondaryTextColor
        customLocationsStatusLabel.lineBreakMode = .byTruncatingMiddle

        let customTitle = NSTextField(labelWithString: "Saved Drives & Folders")
        customTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        customTitle.textColor = BuoyChrome.primaryTextColor
        let customDetail = NSTextField(wrappingLabelWithString: "Choose extra locations like external drives. Buoy stores bookmarks and only scans them when this switch is on.")
        customDetail.font = .systemFont(ofSize: 11)
        customDetail.textColor = BuoyChrome.secondaryTextColor
        customDetail.maximumNumberOfLines = 0
        let customLabels = NSStackView(views: [customTitle, customDetail, customLocationsStatusLabel])
        customLabels.orientation = .vertical
        customLabels.spacing = 2

        let customRow = NSStackView(views: [customLocationsSwitch, customLabels, NSView(), customLocationsButton])
        customRow.orientation = .horizontal
        customRow.alignment = .top
        customRow.spacing = 12
        rows.addArrangedSubview(customRow)

        let content = NSStackView(views: [accessSummaryLabel, rows])
        content.orientation = .vertical
        content.spacing = 12

        let section = DashboardSectionView(title: "Access Controls")
        section.pinContent(content, top: 38, bottom: 14)
        return section
    }

    private func wireActions() {
        scopePopup.target = self
        scopePopup.action = #selector(filtersChanged)
        kindPopup.target = self
        kindPopup.action = #selector(filtersChanged)
        sortPopup.target = self
        sortPopup.action = #selector(filtersChanged)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressed)
        revealButton.target = self
        revealButton.action = #selector(revealSelection)
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        field.textColor = BuoyChrome.secondaryTextColor
        return field
    }

    private func applyEmptyState() {
        usedCard.set(value: "—", detail: "No scan yet")
        explainedCard.set(value: "—", detail: "Run a scan")
        cleanupCard.set(value: "—", detail: "No cleanup estimate")
        systemCard.set(value: "—", detail: "No system estimate")
        breakdownView.setBreakdown([], totalBytes: 0)
        breakdownLabel.stringValue = "No storage scan yet."
        highlightsLabel.stringValue = "The storage view scans root, home, apps, caches, and developer folders so Finder-style “System Data” is less opaque."
        summaryLabel.stringValue = "No scan data"
        stateLabel.stringValue = "—"
        timestampLabel.stringValue = "—"
        revealButton.isEnabled = false
        table.tableView.reloadData()
    }

    @objc private func refreshPressed() {
        startScan(mode: .deep)
    }

    private func handleStorageTabOpen() {
        if !hasLoadedInitialState {
            hasLoadedInitialState = true
            loadCachedOrSeedState()
        }

        maybeStartAutomaticRefreshOnOpen()
    }

    private func loadCachedOrSeedState() {
        let fingerprint = accessManager.cacheFingerprint()
        if let record = cacheStore.loadRecord(for: fingerprint) {
            applySnapshot(
                record.runtimeSnapshot(),
                source: .cached,
                cacheStatus: refreshPolicy.cacheStatus(for: record),
                lastDeepScanAt: record.lastDeepScanAt
            )
            return
        }

        applySeedState()
    }

    private func applySeedState() {
        let seedSnapshot = StorageScanSnapshot.seed(disk: DiskMetricsCollector.sample())
        applySnapshot(
            seedSnapshot,
            source: .seed,
            cacheStatus: .partial,
            lastDeepScanAt: nil
        )
    }

    private func maybeStartAutomaticRefreshOnOpen() {
        guard activeScanMode == nil else { return }

        if snapshotSource == .seed {
            startScan(mode: .summaryOnly)
            return
        }

        guard let snapshot = scanSnapshot else { return }
        let status = refreshPolicy.cacheStatus(
            capturedAt: snapshot.capturedAt,
            scanCompleteness: snapshot.scanMode,
            lastDeepScanAt: lastDeepScanAt
        )
        cacheStatus = status
        updateMetadataLabels()

        if status == .stale {
            startScan(mode: .summaryOnly)
        }
    }

    private func startScan(
        mode: StorageScanMode,
        preservePreviousDeepResults: Bool = true
    ) {
        let accessFingerprint = accessManager.cacheFingerprint()
        let preservedSnapshot = preservePreviousDeepResults ? scanSnapshot : nil
        let preservedLastDeepScanAt = preservePreviousDeepResults ? lastDeepScanAt : nil

        activeScanMode = mode
        spinner.startAnimation(nil)
        stateLabel.stringValue = mode == .deep ? "Deep Scan Running" : "Refreshing Summary"
        statusLabel.stringValue = mode == .deep ? "Starting deep scan…" : "Refreshing storage summary…"
        let accessSession = accessManager.beginAccessSession()

        scanner.scan(mode: mode, access: accessSession, progress: { [weak self] message in
            self?.statusLabel.stringValue = message
        }, completion: { [weak self] result in
            guard let self else { return }

            self.activeScanMode = nil
            self.spinner.stopAnimation(nil)

            switch result {
            case .success(let rawSnapshot):
                let resolvedLastDeepScanAt = mode == .deep ? rawSnapshot.capturedAt : preservedLastDeepScanAt
                let snapshot = rawSnapshot.preservingHeavyItems(
                    from: preservedSnapshot,
                    lastDeepScanAt: resolvedLastDeepScanAt
                )
                let resolvedCacheStatus = self.refreshPolicy.cacheStatus(
                    capturedAt: snapshot.capturedAt,
                    scanCompleteness: snapshot.scanMode,
                    lastDeepScanAt: resolvedLastDeepScanAt
                )

                self.applySnapshot(
                    snapshot,
                    source: .live,
                    cacheStatus: resolvedCacheStatus,
                    lastDeepScanAt: resolvedLastDeepScanAt
                )
                self.refreshAccessControls()
                try? self.cacheStore.save(
                    snapshot: snapshot,
                    lastDeepScanAt: resolvedLastDeepScanAt,
                    accessFingerprint: accessFingerprint
                )
            case .failure(let error):
                self.updateMetadataLabels()
                self.statusLabel.stringValue = self.failureMessage(for: mode, error: error)
            }
        })
    }

    private func applySnapshot(
        _ snapshot: StorageScanSnapshot,
        source: StorageSnapshotSource,
        cacheStatus: StorageCacheStatus,
        lastDeepScanAt: Date?
    ) {
        scanSnapshot = snapshot
        snapshotSource = source
        self.cacheStatus = cacheStatus
        self.lastDeepScanAt = lastDeepScanAt
        updateSummaryCards(snapshot, source: source)
        updateBreakdown(snapshot, source: source)
        applyFilters()
        updateMetadataLabels()
    }

    private func updateSummaryCards(_ snapshot: StorageScanSnapshot, source: StorageSnapshotSource) {
        let usedBytes = Int64(snapshot.disk.usedGB * 1_073_741_824.0)
        let totalBytes = Int64(snapshot.disk.totalGB * 1_073_741_824.0)
        let systemAndHidden = snapshot.systemBytes + snapshot.unexplainedBytes

        if source == .seed {
            usedCard.set(
                value: DashboardFormatters.bytes(usedBytes),
                detail: String(format: "APFS container %.0f%% of %@", snapshot.disk.usagePercent, DashboardFormatters.bytes(totalBytes))
            )
            explainedCard.set(value: "—", detail: "Summary scan not ready yet")
            cleanupCard.set(value: "—", detail: "Waiting for cleanup targets")
            systemCard.set(value: "—", detail: "Waiting for system estimate")
            return
        }

        usedCard.set(
            value: DashboardFormatters.bytes(usedBytes),
            detail: String(format: "APFS container %.0f%% of %@", snapshot.disk.usagePercent, DashboardFormatters.bytes(totalBytes))
        )
        explainedCard.set(
            value: DashboardFormatters.bytes(snapshot.explainedBytes),
            detail: snapshot.unexplainedBytes > 0
                ? "\(DashboardFormatters.bytes(snapshot.unexplainedBytes)) still protected or opaque"
                : "Root scan fully accounted for used space"
        )
        cleanupCard.set(
            value: DashboardFormatters.bytes(snapshot.reclaimableBytes),
            detail: snapshot.cleanupHighlights.isEmpty ? "No obvious cleanup targets surfaced" : "Downloads, caches, backups, and dev data"
        )
        systemCard.set(
            value: DashboardFormatters.bytes(systemAndHidden),
            detail: "System data, hidden folders, and unexplained usage"
        )
    }

    private func updateBreakdown(_ snapshot: StorageScanSnapshot, source: StorageSnapshotSource) {
        guard source != .seed else {
            breakdownView.setBreakdown([], totalBytes: 0)
            breakdownLabel.stringValue = "Live APFS container totals are ready. Buoy will fill in folder summaries and cleanup targets with a background summary refresh."
            highlightsLabel.stringValue = "Deep Scan is optional and only needed when you want an exact largest-files pass."
            return
        }

        let breakdownTotal = max(snapshot.rootBreakdown.reduce(Int64(0)) { $0 + $1.sizeBytes }, 1)
        breakdownView.setBreakdown(snapshot.rootBreakdown, totalBytes: breakdownTotal)

        let breakdownText = snapshot.rootBreakdown.prefix(4).map {
            "\($0.category.rawValue) \(DashboardFormatters.bytes($0.sizeBytes))"
        }.joined(separator: " • ")

        if snapshot.unexplainedBytes > 0 {
            breakdownLabel.stringValue = "Accounted for \(DashboardFormatters.bytes(snapshot.explainedBytes)) of \(DashboardFormatters.bytes(Int64(snapshot.disk.usedGB * 1_073_741_824.0))). Remaining \(DashboardFormatters.bytes(snapshot.unexplainedBytes)) is likely APFS snapshots, purgeable space, or protected system data. \(breakdownText)"
        } else {
            breakdownLabel.stringValue = "Root scan accounted for the used disk space. \(breakdownText)"
        }

        let homeHotspots = snapshot.homeHighlights.prefix(3).map {
            "\(DashboardFormatters.abbreviatedPath($0.path)) \(DashboardFormatters.bytes($0.sizeBytes))"
        }.joined(separator: " • ")
        let cleanupHotspots = snapshot.cleanupHighlights.prefix(3).map {
            "\($0.name) \(DashboardFormatters.bytes($0.sizeBytes))"
        }.joined(separator: " • ")

        if homeHotspots.isEmpty && cleanupHotspots.isEmpty {
            highlightsLabel.stringValue = "No obvious large folders were surfaced."
        } else if cleanupHotspots.isEmpty {
            highlightsLabel.stringValue = "Home hot spots: \(homeHotspots)"
        } else if homeHotspots.isEmpty {
            highlightsLabel.stringValue = "Cleanup ideas: \(cleanupHotspots)"
        } else {
            highlightsLabel.stringValue = "Home hot spots: \(homeHotspots)\nCleanup ideas: \(cleanupHotspots)"
        }
    }

    private func updateMetadataLabels() {
        stateLabel.stringValue = statusStateTitle()
        timestampLabel.stringValue = statusTimestampText()
        statusLabel.stringValue = defaultStatusText()
    }

    private func statusStateTitle() -> String {
        if activeScanMode == .summaryOnly {
            return "Refreshing Summary"
        }
        if activeScanMode == .deep {
            return "Deep Scan Running"
        }
        if cacheStatus == .partial {
            return "Partial Scan"
        }
        if snapshotSource == .cached {
            return "Cached"
        }
        return "Live"
    }

    private func statusTimestampText() -> String {
        guard let snapshot = scanSnapshot else { return "—" }

        var parts: [String] = []
        switch snapshotSource {
        case .seed:
            parts.append("Disk totals \(DashboardFormatters.timestamp(snapshot.capturedAt))")
        case .cached:
            parts.append("Cached \(DashboardFormatters.timestamp(snapshot.capturedAt))")
        case .live:
            parts.append("Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))")
        }

        switch cacheStatus {
        case .fresh:
            parts.append("Fresh")
        case .stale:
            parts.append("Stale")
        case .partial:
            break
        }

        if let lastDeepScanAt,
           snapshot.scanMode == .summaryOnly,
           lastDeepScanAt != snapshot.capturedAt {
            parts.append("Deep \(DashboardFormatters.timestamp(lastDeepScanAt))")
        }

        return parts.joined(separator: " • ")
    }

    private func defaultStatusText() -> String {
        guard let snapshot = scanSnapshot else {
            return "Run a deep scan to see where disk space is actually going."
        }

        var parts: [String] = []
        switch snapshotSource {
        case .seed:
            parts.append("Showing live disk totals while Buoy prepares a storage summary.")
        case .cached:
            parts.append("Showing cached storage data immediately.")
        case .live:
            let label = snapshot.scanMode == .deep ? "Deep scan" : "Summary refresh"
            parts.append("\(label) finished in \(String(format: "%.1fs", snapshot.scanDuration)).")
        }

        if snapshot.scanMode == .summaryOnly {
            if let lastDeepScanAt {
                parts.append("Largest files are from the last deep scan at \(DashboardFormatters.timestamp(lastDeepScanAt)).")
            } else {
                parts.append("Largest files are unavailable until a deep scan completes.")
            }
        }

        if !snapshot.inaccessiblePaths.isEmpty {
            parts.append("Skipped \(snapshot.inaccessiblePaths.count) protected paths.")
        }

        let disabled = StorageProtectedScope.allCases
            .filter { !accessManager.isEnabled($0) }
            .map(\.title)
        if !disabled.isEmpty {
            parts.append("Protected folders off: \(disabled.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }

    private func failureMessage(for mode: StorageScanMode, error: Error) -> String {
        let label = mode == .deep ? "Deep scan" : "Summary refresh"
        return "\(label) failed: \(error.localizedDescription)"
    }

    private func refreshAccessControls() {
        for scope in StorageProtectedScope.allCases {
            let isEnabled = accessManager.isEnabled(scope)
            protectedSwitches[scope]?.state = isEnabled ? .on : .off

            if let url = accessManager.resolvedURL(for: scope) {
                let savedText = DashboardFormatters.abbreviatedPath(url.path)
                protectedStatusLabels[scope]?.stringValue = isEnabled
                    ? "Enabled: \(savedText)"
                    : "Saved: \(savedText)"
                protectedButtons[scope]?.title = "Change…"
            } else {
                protectedStatusLabels[scope]?.stringValue = isEnabled
                    ? "Enabled but not granted yet"
                    : "Off"
                protectedButtons[scope]?.title = "Grant…"
            }
        }

        let customURLs = accessManager.resolvedCustomURLs()
        let customEnabled = accessManager.isCustomLocationsEnabled()
        customLocationsSwitch.state = customEnabled ? .on : .off
        if customURLs.isEmpty {
            customLocationsStatusLabel.stringValue = customEnabled
                ? "Enabled but no saved locations"
                : "No saved locations"
            customLocationsButton.title = "Choose…"
        } else {
            let preview = customURLs.prefix(2).map { DashboardFormatters.abbreviatedPath($0.path) }.joined(separator: " • ")
            let suffix = customURLs.count > 2 ? " • +\(customURLs.count - 2) more" : ""
            let label = "\(customURLs.count) saved location\(customURLs.count == 1 ? "" : "s"): \(preview)\(suffix)"
            customLocationsStatusLabel.stringValue = customEnabled ? "Enabled: \(label)" : "Saved: \(label)"
            customLocationsButton.title = "Change…"
        }
    }

    @objc private func protectedToggleChanged(_ sender: NSSwitch) {
        guard sender.tag >= 0, sender.tag < StorageProtectedScope.allCases.count else { return }
        let scope = StorageProtectedScope.allCases[sender.tag]

        if sender.state == .on {
            if accessManager.resolvedURL(for: scope) == nil {
                guard let selectedURL = requestProtectedFolder(scope) else {
                    accessManager.setEnabled(false, for: scope)
                    refreshAccessControls()
                    return
                }
                do {
                    try accessManager.saveBookmark(for: scope, url: selectedURL)
                } catch {
                    accessManager.setEnabled(false, for: scope)
                    statusLabel.stringValue = "Could not save \(scope.title) access: \(error.localizedDescription)"
                    refreshAccessControls()
                    return
                }
            }
            accessManager.setEnabled(true, for: scope)
        } else {
            accessManager.setEnabled(false, for: scope)
        }

        refreshAccessControls()
        handleAccessSettingsChanged()
    }

    @objc private func protectedGrantPressed(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < StorageProtectedScope.allCases.count else { return }
        let scope = StorageProtectedScope.allCases[sender.tag]
        guard let selectedURL = requestProtectedFolder(scope) else { return }

        do {
            try accessManager.saveBookmark(for: scope, url: selectedURL)
            accessManager.setEnabled(true, for: scope)
            refreshAccessControls()
            handleAccessSettingsChanged()
        } catch {
            statusLabel.stringValue = "Could not save \(scope.title) access: \(error.localizedDescription)"
            refreshAccessControls()
        }
    }

    @objc private func customLocationsToggleChanged(_ sender: NSSwitch) {
        if sender.state == .on {
            let existing = accessManager.resolvedCustomURLs()
            if existing.isEmpty {
                guard let selected = requestCustomLocations() else {
                    accessManager.setCustomLocationsEnabled(false)
                    refreshAccessControls()
                    return
                }
                do {
                    try accessManager.saveCustomBookmarks(for: selected)
                } catch {
                    accessManager.setCustomLocationsEnabled(false)
                    statusLabel.stringValue = "Could not save custom locations: \(error.localizedDescription)"
                    refreshAccessControls()
                    return
                }
            }
            accessManager.setCustomLocationsEnabled(true)
        } else {
            accessManager.setCustomLocationsEnabled(false)
        }

        refreshAccessControls()
        handleAccessSettingsChanged()
    }

    @objc private func chooseCustomLocationsPressed() {
        guard let selected = requestCustomLocations() else { return }

        do {
            try accessManager.saveCustomBookmarks(for: selected)
            accessManager.setCustomLocationsEnabled(true)
            refreshAccessControls()
            handleAccessSettingsChanged()
        } catch {
            statusLabel.stringValue = "Could not save custom locations: \(error.localizedDescription)"
            refreshAccessControls()
        }
    }

    private func handleAccessSettingsChanged() {
        cacheStore.invalidate()
        startScan(mode: .summaryOnly, preservePreviousDeepResults: false)
    }

    private func requestProtectedFolder(_ scope: StorageProtectedScope) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = scope.defaultURL.deletingLastPathComponent()
        panel.prompt = "Grant Access"
        panel.message = "Choose the \(scope.title) folder you want Buoy to scan. Buoy stores a bookmark so this access survives app relaunches."
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func requestCustomLocations() -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.fileExists(atPath: "/Volumes")
            ? URL(fileURLWithPath: "/Volumes", isDirectory: true)
            : URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        panel.prompt = "Save Locations"
        panel.message = "Choose extra folders or drives for storage scans. Buoy stores bookmarks so these selections survive app relaunches."
        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }

    @objc private func filtersChanged() {
        applyFilters()
    }

    public func controlTextDidChange(_ obj: Notification) {
        applyFilters()
    }

    private func applyFilters() {
        guard let snapshot = scanSnapshot else {
            visibleItems = []
            summaryLabel.stringValue = "No scan data"
            table.tableView.reloadData()
            revealButton.isEnabled = false
            return
        }

        let scope = StorageScopeFilter(rawValue: scopePopup.titleOfSelectedItem ?? "") ?? .all
        let kind = StorageKindFilter(rawValue: kindPopup.titleOfSelectedItem ?? "") ?? .all
        let sort = StorageSortKey(rawValue: sortPopup.titleOfSelectedItem ?? "") ?? .size
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        visibleItems = snapshot.heavyItems.filter { item in
            let matchesQuery = query.isEmpty
                || item.name.localizedCaseInsensitiveContains(query)
                || item.path.localizedCaseInsensitiveContains(query)
                || item.note.localizedCaseInsensitiveContains(query)
            return matchesQuery && matches(scope: scope, item: item) && matches(kind: kind, item: item)
        }

        visibleItems.sort { lhs, rhs in
            switch sort {
            case .size:
                return lhs.sizeBytes == rhs.sizeBytes
                    ? lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
                    : lhs.sizeBytes > rhs.sizeBytes
            case .name:
                if lhs.name == rhs.name {
                    return lhs.sizeBytes > rhs.sizeBytes
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .category:
                if lhs.category == rhs.category {
                    return lhs.sizeBytes > rhs.sizeBytes
                }
                return lhs.category.rawValue.localizedCaseInsensitiveCompare(rhs.category.rawValue) == .orderedAscending
            case .path:
                return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
            }
        }

        if snapshotSource == .seed {
            summaryLabel.stringValue = "Waiting for scan data"
        } else if snapshot.heavyItems.isEmpty {
            summaryLabel.stringValue = snapshot.scanMode == .summaryOnly ? "No summary items yet" : "No heavy items"
        } else {
            let label = snapshot.scanMode == .summaryOnly && lastDeepScanAt == nil ? "summary items" : "heavy items"
            summaryLabel.stringValue = "\(visibleItems.count) of \(snapshot.heavyItems.count) \(label)"
        }
        table.tableView.reloadData()
        updateRevealButtonState()
    }

    private func matches(scope: StorageScopeFilter, item: StorageItem) -> Bool {
        switch scope {
        case .all:
            return true
        case .cleanup:
            return item.isCleanupCandidate
        case .userFiles:
            return item.path.hasPrefix(NSHomeDirectory())
                && item.category != .developer
                && item.category != .applications
                && item.category != .system
        case .applications:
            return item.category == .applications
        case .developer:
            return item.category == .developer
        case .system:
            return item.category == .system || item.category == .library || item.category == .hidden
        }
    }

    private func matches(kind: StorageKindFilter, item: StorageItem) -> Bool {
        switch kind {
        case .all:
            return true
        case .folders:
            return item.kind == .folder
        case .files:
            return item.kind == .file
        }
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        visibleItems.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < visibleItems.count, let column = tableColumn else { return nil }
        let identifier = column.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: identifier)
        let item = visibleItems[row]
        cell.textField?.stringValue = displayValue(for: item, column: identifier)
        cell.textField?.toolTip = item.note.isEmpty ? item.path : item.note
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        updateRevealButtonState()
    }

    private func updateRevealButtonState() {
        let selected = table.tableView.selectedRow
        revealButton.isEnabled = selected >= 0 && selected < visibleItems.count
    }

    @objc private func revealSelection() {
        let selected = table.tableView.selectedRow
        guard selected >= 0, selected < visibleItems.count else { return }
        let url = URL(fileURLWithPath: visibleItems[selected].path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func displayValue(for item: StorageItem, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case Column.name:
            return item.name
        case Column.kind:
            return item.kind.rawValue
        case Column.category:
            return item.category.rawValue
        case Column.size:
            return DashboardFormatters.bytes(item.sizeBytes)
        case Column.signal:
            return item.safety.rawValue
        case Column.path:
            return DashboardFormatters.abbreviatedPath(item.path)
        default:
            return ""
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.maximumNumberOfLines = 1
        textField.font = identifier == Column.size ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 12)
        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }
}

private final class StorageSummaryCardView: NSBox {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")

    init(title: String) {
        super.init(frame: .zero)
        boxType = .custom
        cornerRadius = 14
        borderWidth = 1
        borderColor = BuoyChrome.borderColor
        fillColor = BuoyChrome.panelBackgroundColor

        titleLabel.stringValue = title
        titleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = BuoyChrome.secondaryTextColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        valueLabel.textColor = BuoyChrome.primaryTextColor
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = BuoyChrome.secondaryTextColor
        detailLabel.maximumNumberOfLines = 0

        let stack = NSStackView(views: [titleLabel, valueLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func set(value: String, detail: String) {
        valueLabel.stringValue = value
        detailLabel.stringValue = detail
    }
}

private final class StorageBreakdownView: NSView {
    private let barView = StorageStackedBarView()
    private let legendStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        legendStack.orientation = .horizontal
        legendStack.alignment = .centerY
        legendStack.spacing = 10
        legendStack.distribution = .gravityAreas

        let stack = NSStackView(views: [barView, legendStack])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        barView.heightAnchor.constraint(equalToConstant: 26).isActive = true

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setBreakdown(_ breakdown: [StorageCategorySummary], totalBytes: Int64) {
        barView.updateSegments(breakdown, totalBytes: totalBytes)
        legendStack.arrangedSubviews.forEach { view in
            legendStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for segment in breakdown {
            legendStack.addArrangedSubview(StorageLegendChip(summary: segment))
        }
    }
}

private final class StorageStackedBarView: NSView {
    private var segments: [StorageCategorySummary] = []
    private var totalBytes: Int64 = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateSegments(_ segments: [StorageCategorySummary], totalBytes: Int64) {
        self.segments = segments
        self.totalBytes = totalBytes
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let background = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        BuoyChrome.gridColor.withAlphaComponent(0.55).setFill()
        background.fill()

        guard totalBytes > 0 else { return }

        var currentX = bounds.minX
        for segment in segments where segment.sizeBytes > 0 {
            let width = bounds.width * CGFloat(Double(segment.sizeBytes) / Double(totalBytes))
            let segmentRect = NSRect(x: currentX, y: bounds.minY, width: max(width, 2), height: bounds.height)
            StoragePalette.color(for: segment.category).setFill()
            NSBezierPath(rect: segmentRect).fill()
            currentX += width
        }
    }
}

private final class StorageLegendChip: NSView {
    init(summary: StorageCategorySummary) {
        super.init(frame: .zero)

        let swatch = NSView()
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = StoragePalette.color(for: summary.category).cgColor
        swatch.layer?.cornerRadius = 4
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: 8).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let label = NSTextField(labelWithString: "\(summary.category.rawValue) \(DashboardFormatters.bytes(summary.sizeBytes))")
        label.font = .systemFont(ofSize: 11)
        label.textColor = BuoyChrome.secondaryTextColor

        let stack = NSStackView(views: [swatch, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

private enum StoragePalette {
    static func color(for category: StorageCategory) -> NSColor {
        switch category {
        case .applications:
            return NSColor(hex: 0xC08A4A)
        case .users:
            return NSColor(hex: 0x5A86B5)
        case .downloads:
            return NSColor(hex: 0x6FA36A)
        case .documents:
            return NSColor(hex: 0x5C9A92)
        case .media:
            return NSColor(hex: 0xB37378)
        case .developer:
            return NSColor(hex: 0xBEA24C)
        case .backups:
            return NSColor(hex: 0x8E77B1)
        case .caches:
            return NSColor(hex: 0x6C9F8A)
        case .library:
            return NSColor(hex: 0x6A78A6)
        case .system:
            return NSColor(hex: 0xB05C55)
        case .hidden:
            return NSColor(hex: 0x7C7A72)
        case .other:
            return BuoyChrome.secondaryTextColor
        }
    }
}
