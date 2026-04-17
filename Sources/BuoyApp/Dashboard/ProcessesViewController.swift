import AppKit
import Foundation

public final class ProcessesViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private enum Column {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let pid = NSUserInterfaceItemIdentifier("pid")
        static let ppid = NSUserInterfaceItemIdentifier("ppid")
        static let cpu = NSUserInterfaceItemIdentifier("cpu")
        static let memMB = NSUserInterfaceItemIdentifier("memMB")
        static let memPct = NSUserInterfaceItemIdentifier("memPct")
        static let state = NSUserInterfaceItemIdentifier("state")
        static let user = NSUserInterfaceItemIdentifier("user")
    }

    private let searchField = NSSearchField()
    private let userFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let summaryLabel = NSTextField(labelWithString: "0 processes")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let visibleCard = DashboardMetricCardView(title: "Visible")
    private let topCPUCard = DashboardMetricCardView(title: "Top CPU")
    private let topMemoryCard = DashboardMetricCardView(title: "Top Memory")
    private let userCard = DashboardMetricCardView(title: "Users")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 210, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let table = DashboardTableContainer(columns: [
        (Column.name, "Process", 240),
        (Column.pid, "PID", 80),
        (Column.ppid, "PPID", 80),
        (Column.cpu, "CPU %", 90),
        (Column.memMB, "Memory MB", 110),
        (Column.memPct, "Memory %", 95),
        (Column.state, "State", 110),
        (Column.user, "User", 120)
    ])

    private var snapshot = DashboardSnapshot()
    private var visibleRows: [ProcessInfoRow] = []

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
        let (_, _, stack) = installDashboardDocumentStack(in: view)

        searchField.placeholderString = "Search process name"
        searchField.delegate = self

        sortPopup.addItems(withTitles: ProcessSortKey.allCases.map(\.rawValue))
        sortPopup.selectItem(withTitle: ProcessSortKey.cpu.rawValue)
        sortPopup.target = self
        sortPopup.action = #selector(filtersChanged)

        userFilter.target = self
        userFilter.action = #selector(filtersChanged)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = BuoyChrome.secondaryTextColor
        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        table.tableView.delegate = self
        table.tableView.dataSource = self

        summaryGrid.setItems([visibleCard, topCPUCard, topMemoryCard, userCard])

        let searchRow = NSStackView(views: [label("Search"), searchField, label("User"), userFilter])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8

        let filtersRow = NSStackView(views: [label("Sort"), sortPopup, NSView(), summaryLabel, timestampLabel])
        filtersRow.orientation = .horizontal
        filtersRow.alignment = .centerY
        filtersRow.spacing = 8

        let controlsStack = NSStackView(views: [searchRow, filtersRow])
        controlsStack.orientation = .vertical
        controlsStack.spacing = 10

        let controlsPanel = NSView()
        controlsPanel.applyBuoySurface(cornerRadius: 12, fillColor: BuoyChrome.elevatedBackgroundColor, borderColor: BuoyChrome.gridColor)
        controlsPanel.addSubview(controlsStack)
        controlsStack.pinEdges(to: controlsPanel, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        let scopeAccessory = NSStackView(views: [summaryLabel, timestampLabel])
        scopeAccessory.orientation = .horizontal
        scopeAccessory.alignment = .centerY
        scopeAccessory.spacing = 12

        let scopeStage = DashboardStageView(
            sectionLabel: "Load",
            title: "Current Process Load",
            subtitle: "What is noisy right now, plus the scope controls that shape the list below.",
            accessory: scopeAccessory
        )
        let scopeBody = DashboardSplitColumnsView(
            primary: summaryGrid,
            secondary: controlsPanel,
            collapseWidth: 940,
            preferredSecondaryWidth: 360
        )
        scopeStage.pinContent(scopeBody)

        let tableStage = DashboardStageView(
            sectionLabel: "Inspect",
            title: "Process Table",
            subtitle: "Sorted and filtered live process data for exact inspection."
        )
        tableStage.pinContent(table)

        stack.addArrangedSubview(scopeStage)
        stack.addArrangedSubview(tableStage)
        [scopeStage, tableStage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        tableStage.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = BuoyChrome.secondaryTextColor
        return field
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        refreshUserChoices()
        applyFilters()
        timestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }

    private func refreshUserChoices() {
        let selected = userFilter.titleOfSelectedItem ?? "All Users"
        let users = Array(Set(snapshot.processes.map(\.user))).sorted()
        userFilter.removeAllItems()
        userFilter.addItem(withTitle: "All Users")
        userFilter.addItems(withTitles: users)
        if userFilter.itemTitles.contains(selected) {
            userFilter.selectItem(withTitle: selected)
        } else {
            userFilter.selectItem(at: 0)
        }
    }

    @objc private func filtersChanged() {
        applyFilters()
    }

    public func controlTextDidChange(_ obj: Notification) {
        applyFilters()
    }

    private func applyFilters() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedUser = userFilter.titleOfSelectedItem ?? "All Users"
        let sortKey = ProcessSortKey(rawValue: sortPopup.titleOfSelectedItem ?? "") ?? .cpu

        visibleRows = snapshot.processes.filter { row in
            let matchesName = query.isEmpty || row.name.localizedCaseInsensitiveContains(query)
            let matchesUser = selectedUser == "All Users" || row.user == selectedUser
            return matchesName && matchesUser
        }

        visibleRows.sort { lhs, rhs in
            switch sortKey {
            case .cpu:
                return lhs.cpuPercent == rhs.cpuPercent ? lhs.pid < rhs.pid : lhs.cpuPercent > rhs.cpuPercent
            case .memory:
                return lhs.memoryPercent == rhs.memoryPercent ? lhs.pid < rhs.pid : lhs.memoryPercent > rhs.memoryPercent
            case .pid:
                return lhs.pid < rhs.pid
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .user:
                if lhs.user == rhs.user {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.user.localizedCaseInsensitiveCompare(rhs.user) == .orderedAscending
            }
        }

        summaryLabel.stringValue = "\(visibleRows.count) of \(snapshot.processes.count) visible"
        updateSummaryCards()
        table.tableView.reloadData()
    }

    private func updateSummaryCards() {
        visibleCard.set(
            value: "\(visibleRows.count)",
            detail: "\(snapshot.processes.count) total processes",
            tone: .accent
        )

        if let leader = visibleRows.max(by: { $0.cpuPercent < $1.cpuPercent }) {
            topCPUCard.set(
                value: String(format: "%.1f%%", leader.cpuPercent),
                detail: leader.name,
                tone: leader.cpuPercent > 80 ? .warning : .accent
            )
        } else {
            topCPUCard.set(value: "—", detail: "No process data", tone: .neutral)
        }

        if let leader = visibleRows.max(by: { $0.memoryMB < $1.memoryMB }) {
            topMemoryCard.set(
                value: String(format: "%.1f MB", leader.memoryMB),
                detail: leader.name,
                tone: .accent
            )
        } else {
            topMemoryCard.set(value: "—", detail: "No process data", tone: .neutral)
        }

        let userCount = Set(visibleRows.map(\.user)).count
        userCard.set(
            value: "\(userCount)",
            detail: selectedUserLabel(),
            tone: .accent
        )
    }

    private func selectedUserLabel() -> String {
        let title = userFilter.titleOfSelectedItem ?? "All Users"
        if title == "All Users" {
            return "Unique users in view"
        }
        return title
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < visibleRows.count, let column = tableColumn else { return nil }
        let value = displayValue(for: visibleRows[row], column: column.identifier)
        let identifier = column.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: identifier)
        cell.textField?.stringValue = value
        return cell
    }

    private func displayValue(for row: ProcessInfoRow, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case Column.name: return row.name
        case Column.pid: return "\(row.pid)"
        case Column.ppid: return "\(row.ppid)"
        case Column.cpu: return DashboardFormatters.percent(row.cpuPercent)
        case Column.memMB: return DashboardFormatters.memoryMB(row.memoryMB)
        case Column.memPct: return DashboardFormatters.percent(row.memoryPercent)
        case Column.state: return row.state
        case Column.user: return row.user
        default: return ""
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.textColor = BuoyChrome.primaryTextColor
        if identifier == Column.pid || identifier == Column.ppid || identifier == Column.cpu || identifier == Column.memMB || identifier == Column.memPct {
            textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            textField.font = .systemFont(ofSize: 12)
        }

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
