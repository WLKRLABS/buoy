import AppKit
import Foundation

public final class NetworkViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate {
    private enum PortColumn {
        static let service = NSUserInterfaceItemIdentifier("service")
        static let proto = NSUserInterfaceItemIdentifier("proto")
        static let port = NSUserInterfaceItemIdentifier("port")
        static let local = NSUserInterfaceItemIdentifier("local")
        static let owner = NSUserInterfaceItemIdentifier("owner")
        static let pid = NSUserInterfaceItemIdentifier("pid")
    }

    private enum InterfaceColumn {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let ipv4 = NSUserInterfaceItemIdentifier("ipv4")
        static let ipv6 = NSUserInterfaceItemIdentifier("ipv6")
        static let mac = NSUserInterfaceItemIdentifier("mac")
        static let status = NSUserInterfaceItemIdentifier("status")
    }

    private let summaryLabel = NSTextField(labelWithString: "0 listeners | 0 interfaces")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let listenerCard = DashboardMetricCardView(title: "Listeners")
    private let interfaceCard = DashboardMetricCardView(title: "Interfaces")
    private let addressCard = DashboardMetricCardView(title: "Primary IPv4")
    private let protoCard = DashboardMetricCardView(title: "Protocols")
    private let summaryGrid = AdaptiveGridView(minColumnWidth: 210, maxColumns: 4, rowSpacing: 12, columnSpacing: 12)
    private let portsTable = DashboardTableContainer(columns: [
        (PortColumn.service, "Service", 160),
        (PortColumn.proto, "Proto", 80),
        (PortColumn.port, "Port", 80),
        (PortColumn.local, "Local Address", 220),
        (PortColumn.owner, "Process/Owner", 180),
        (PortColumn.pid, "PID", 80)
    ])
    private let interfacesTable = DashboardTableContainer(columns: [
        (InterfaceColumn.name, "Interface", 100),
        (InterfaceColumn.ipv4, "IPv4", 220),
        (InterfaceColumn.ipv6, "IPv6", 260),
        (InterfaceColumn.mac, "MAC", 150),
        (InterfaceColumn.status, "Status", 100)
    ])

    private var snapshot = DashboardSnapshot()

    public override func loadView() {
        view = NSView()
        BuoyChrome.applyWindowBackground(to: view)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        let (_, _, stack) = installDashboardDocumentStack(in: view)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = BuoyChrome.secondaryTextColor
        timestampLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor = BuoyChrome.secondaryTextColor

        portsTable.tableView.delegate = self
        portsTable.tableView.dataSource = self
        interfacesTable.tableView.delegate = self
        interfacesTable.tableView.dataSource = self

        summaryGrid.setItems([listenerCard, interfaceCard, addressCard, protoCard])

        let accessory = NSStackView(views: [summaryLabel, timestampLabel])
        accessory.orientation = .horizontal
        accessory.alignment = .centerY
        accessory.spacing = 12

        let summaryStage = DashboardStageView(
            sectionLabel: "Footprint",
            title: "Network Summary",
            subtitle: "Listening services, live interfaces, and the current addressing footprint.",
            accessory: accessory
        )
        summaryStage.pinContent(summaryGrid)

        let listenersSection = DashboardSectionView(
            title: "Listening Services",
            subtitle: "Ports currently bound by local processes."
        )
        listenersSection.pinContent(portsTable)

        let interfacesSection = DashboardSectionView(
            title: "Interface Table",
            subtitle: "IPv4, IPv6, MAC address, and link state."
        )
        interfacesSection.pinContent(interfacesTable)

        let inspectionGrid = AdaptiveGridView(minColumnWidth: 420, maxColumns: 2, rowSpacing: 14, columnSpacing: 14)
        inspectionGrid.setItems([listenersSection, interfacesSection])

        let inspectionStage = DashboardStageView(
            sectionLabel: "Inspect",
            title: "Live Surfaces",
            subtitle: "Bound ports and interface detail stay grouped as the lower inspection layer."
        )
        inspectionStage.pinContent(inspectionGrid)

        stack.addArrangedSubview(summaryStage)
        stack.addArrangedSubview(inspectionStage)
        [summaryStage, inspectionStage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        listenersSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        interfacesSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot

        let activeInterfaces = snapshot.network.interfaces.filter(\.isUp)
        let primaryIPv4 = activeInterfaces.flatMap(\.ipv4).first
            ?? snapshot.network.interfaces.flatMap(\.ipv4).first
        let protocols = Set(snapshot.network.listeningPorts.map(\.proto))

        listenerCard.set(
            value: "\(snapshot.network.listeningPorts.count)",
            detail: "Processes with local listeners",
            tone: snapshot.network.listeningPorts.isEmpty ? .neutral : .accent
        )
        interfaceCard.set(
            value: "\(activeInterfaces.count)",
            detail: "\(snapshot.network.interfaces.count) interfaces total",
            tone: .accent
        )
        addressCard.set(
            value: primaryIPv4 ?? "—",
            detail: activeInterfaces.first?.name ?? "No active IPv4 address",
            tone: primaryIPv4 == nil ? .neutral : .accent
        )
        protoCard.set(
            value: "\(protocols.count)",
            detail: protocols.sorted().joined(separator: ", ").uppercased(),
            tone: protocols.isEmpty ? .neutral : .accent
        )

        summaryLabel.stringValue = "\(snapshot.network.listeningPorts.count) listeners | \(snapshot.network.interfaces.count) interfaces"
        timestampLabel.stringValue = "Updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
        portsTable.tableView.reloadData()
        interfacesTable.tableView.reloadData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === portsTable.tableView {
            return snapshot.network.listeningPorts.count
        }
        return snapshot.network.interfaces.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: column.identifier)

        if tableView === portsTable.tableView {
            let item = snapshot.network.listeningPorts[row]
            cell.textField?.stringValue = portValue(item, column: column.identifier)
        } else {
            let item = snapshot.network.interfaces[row]
            cell.textField?.stringValue = interfaceValue(item, column: column.identifier)
        }

        return cell
    }

    private func portValue(_ row: ListeningPort, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case PortColumn.service: return row.service
        case PortColumn.proto: return row.proto
        case PortColumn.port: return "\(row.port)"
        case PortColumn.local: return row.localAddress
        case PortColumn.owner: return row.owner
        case PortColumn.pid: return row.pid.map(String.init) ?? "—"
        default: return ""
        }
    }

    private func interfaceValue(_ row: NetworkInterfaceInfo, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case InterfaceColumn.name: return row.name
        case InterfaceColumn.ipv4: return row.ipv4.joined(separator: ", ")
        case InterfaceColumn.ipv6: return row.ipv6.joined(separator: ", ")
        case InterfaceColumn.mac: return row.mac ?? "—"
        case InterfaceColumn.status: return row.isUp ? "Active" : "Inactive"
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
