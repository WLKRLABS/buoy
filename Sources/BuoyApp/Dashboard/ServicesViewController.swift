import AppKit
import Foundation

public final class ServicesViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private enum Column {
        static let group = NSUserInterfaceItemIdentifier("group")
        static let label = NSUserInterfaceItemIdentifier("label")
        static let status = NSUserInterfaceItemIdentifier("status")
        static let enabled = NSUserInterfaceItemIdentifier("enabled")
        static let pid = NSUserInterfaceItemIdentifier("pid")
        static let cpu = NSUserInterfaceItemIdentifier("cpu")
        static let mem = NSUserInterfaceItemIdentifier("mem")
        static let location = NSUserInterfaceItemIdentifier("location")
        static let plist = NSUserInterfaceItemIdentifier("plist")
    }

    private let searchField = NSSearchField()
    private let statusFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let locationFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let summaryLabel = NSTextField(labelWithString: "0 services")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let visibleCard = DashboardMetricCardView(title: "Visible")
    private let runningCard = DashboardMetricCardView(title: "Running")
    private let disabledCard = DashboardMetricCardView(title: "Disabled")
    private let thirdPartyCard = DashboardMetricCardView(title: "Third-Party")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 210, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let table = DashboardTableContainer(columns: [
        (Column.group, "Category", 135),
        (Column.label, "Service", 220),
        (Column.status, "Status", 95),
        (Column.enabled, "Boot", 70),
        (Column.pid, "PID", 75),
        (Column.cpu, "CPU %", 85),
        (Column.mem, "Memory MB", 105),
        (Column.location, "Location", 190),
        (Column.plist, "Plist Path", 360)
    ])

    private var snapshot = DashboardSnapshot()
    private var visibleRows: [ServiceInfoRow] = []

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        applyFilters()
    }

    private func buildLayout() {
        let (_, documentView) = installVerticalScrollContainer(in: view)

        searchField.placeholderString = "Search service or plist"
        searchField.delegate = self

        statusFilter.addItems(withTitles: ["All Statuses", "Running", "Stopped", "Disabled"])
        statusFilter.target = self
        statusFilter.action = #selector(filtersChanged)

        locationFilter.addItem(withTitle: "All Locations")
        locationFilter.addItems(withTitles: [
            "System Daemons",
            "System Agents",
            "Library Daemons",
            "Library Agents",
            "User Agents"
        ])
        locationFilter.target = self
        locationFilter.action = #selector(filtersChanged)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = BuoyChrome.secondaryTextColor
        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        table.tableView.delegate = self
        table.tableView.dataSource = self

        summaryGrid.setItems([visibleCard, runningCard, disabledCard, thirdPartyCard])

        let summarySection = DashboardSectionView(
            title: "Service Summary",
            subtitle: "Running state, boot behavior, and third-party footprint."
        )
        summarySection.pinContent(summaryGrid)

        let searchRow = NSStackView(views: [label("Search"), searchField, label("Status"), statusFilter])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8

        let filterRow = NSStackView(views: [label("Location"), locationFilter, NSView(), summaryLabel, timestampLabel])
        filterRow.orientation = .horizontal
        filterRow.alignment = .centerY
        filterRow.spacing = 8

        let filterStack = NSStackView(views: [searchRow, filterRow])
        filterStack.orientation = .vertical
        filterStack.spacing = 10

        let filtersSection = DashboardSectionView(
            title: "Filters",
            subtitle: "Narrow launchd services by state and install location."
        )
        filtersSection.pinContent(filterStack)

        let tableSection = DashboardSectionView(
            title: "Launchd Table",
            subtitle: "Boot state, live process details, and on-disk plist location."
        )
        tableSection.pinContent(table)

        let stack = NSStackView(views: [summarySection, filtersSection, tableSection])
        stack.orientation = .vertical
        stack.spacing = 12
        documentView.addSubview(stack)
        stack.pinEdges(
            to: documentView,
            insets: NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        )

        tableSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = BuoyChrome.secondaryTextColor
        return field
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        applyFilters()
        timestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }

    @objc private func filtersChanged() {
        applyFilters()
    }

    public func controlTextDidChange(_ obj: Notification) {
        applyFilters()
    }

    private func applyFilters() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusTitle = statusFilter.titleOfSelectedItem ?? "All Statuses"
        let locationTitle = locationFilter.titleOfSelectedItem ?? "All Locations"

        visibleRows = snapshot.services.filter { row in
            let matchesQuery = query.isEmpty
                || row.label.localizedCaseInsensitiveContains(query)
                || row.plistPath.localizedCaseInsensitiveContains(query)

            let matchesStatus: Bool
            switch statusTitle {
            case "Running": matchesStatus = row.status == .running
            case "Stopped": matchesStatus = row.status == .stopped
            case "Disabled": matchesStatus = row.status == .disabled
            default: matchesStatus = true
            }

            let matchesLocation: Bool
            switch locationTitle {
            case "System Daemons": matchesLocation = row.location == .systemDaemons
            case "System Agents": matchesLocation = row.location == .systemAgents
            case "Library Daemons": matchesLocation = row.location == .libraryDaemons
            case "Library Agents": matchesLocation = row.location == .libraryAgents
            case "User Agents": matchesLocation = row.location == .userAgents
            default: matchesLocation = true
            }

            return matchesQuery && matchesStatus && matchesLocation
        }

        visibleRows.sort {
            if $0.group == $1.group {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.group.rawValue.localizedCaseInsensitiveCompare($1.group.rawValue) == .orderedAscending
        }

        summaryLabel.stringValue = "\(visibleRows.count) of \(snapshot.services.count) visible"
        updateSummaryCards()
        table.tableView.reloadData()
    }

    private func updateSummaryCards() {
        visibleCard.set(
            value: "\(visibleRows.count)",
            detail: "\(snapshot.services.count) total services",
            tone: .accent
        )

        let runningCount = visibleRows.filter { $0.status == .running }.count
        runningCard.set(
            value: "\(runningCount)",
            detail: "Running now",
            tone: runningCount > 0 ? .accent : .neutral
        )

        let disabledCount = visibleRows.filter { $0.status == .disabled }.count
        disabledCard.set(
            value: "\(disabledCount)",
            detail: "Disabled or blocked",
            tone: disabledCount > 0 ? .warning : .accent
        )

        let thirdPartyCount = visibleRows.filter { $0.group == .thirdParty }.count
        thirdPartyCard.set(
            value: "\(thirdPartyCount)",
            detail: "Third-party services",
            tone: thirdPartyCount > 0 ? .accent : .neutral
        )
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < visibleRows.count, let column = tableColumn else { return nil }
        let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: column.identifier)
        cell.textField?.stringValue = displayValue(for: visibleRows[row], column: column.identifier)
        return cell
    }

    private func displayValue(for row: ServiceInfoRow, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case Column.group: return row.group.rawValue
        case Column.label: return row.label
        case Column.status: return row.status.rawValue
        case Column.enabled: return row.enabledOnBoot ? "Yes" : "No"
        case Column.pid: return row.pid.map(String.init) ?? "—"
        case Column.cpu: return DashboardFormatters.percent(row.cpuPercent)
        case Column.mem: return DashboardFormatters.memoryMB(row.memoryMB)
        case Column.location: return String(row.location.rawValue.split(separator: "/").last ?? "")
        case Column.plist: return row.plistPath
        default: return ""
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = BuoyChrome.primaryTextColor

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
