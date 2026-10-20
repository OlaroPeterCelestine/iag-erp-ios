import SwiftUI

struct ToolDashboard: View {
    let system: SystemCatalog
    let person: String

    var body: some View {
        switch system.id {
        case "finance":
            FinanceDash(system: system, person: person)
        case "erp":
            ERPDash(system: system, person: person)
        case "hr":
            HRDash(system: system, person: person)
        case "inventory":
            InventoryDash(system: system, person: person)
        case "procurement":
            ProcurementDash(system: system, person: person)
        case "fleet":
            FleetDash(system: system, person: person)
        case "logistics":
            LogisticsDash(system: system, person: person)
        case "distribution":
            DistributionDash(system: system, person: person)
        case "crm":
            CRMDash(system: system, person: person)
        case "project-manager":
            ProjectDash(system: system, person: person)
        case "contract-manager":
            ContractDash(system: system, person: person)
        case "production":
            ProductionDash(system: system, person: person)
        case "maintenance":
            MaintenanceDash(system: system, person: person)
        case "lab":
            LabDash(system: system, person: person)
        case "farmer-traceability":
            FarmerDash(system: system, person: person)
        case "auditor":
            AuditorDash(system: system, person: person)
        case "security":
            SecurityDash(system: system, person: person)
        case "admin":
            AdminDash(system: system, person: person)
        default:
            ServiceDash(system: system, person: person)
        }
    }
}

private enum DeskCopy {
    static func hello(_ name: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        if hour < 12 {
            part = "Good morning"
        } else if hour < 17 {
            part = "Good afternoon"
        } else {
            part = "Good evening"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? part : "\(part), \(trimmed)"
    }

    static func saved(_ count: Int) -> String {
        switch count {
        case 0: return "None saved"
        case 1: return "1 saved"
        default: return "\(count) saved"
        }
    }
}

@MainActor
private enum DeskData {
    static func count(_ store: RecordStore, _ system: SystemCatalog, _ formName: String) -> Int {
        guard let form = system.form(named: formName) else { return 0 }
        return store.records(for: form.id).count
    }

    static func recent(_ store: RecordStore, _ system: SystemCatalog, limit: Int) -> [RecentItem] {
        let items = system.allForms.flatMap { form in
            store.records(for: form.id).map { RecentItem(form: form, record: $0) }
        }
        return Array(items.sorted { $0.record.updatedAt > $1.record.updatedAt }.prefix(limit))
    }
}

private struct RecentItem: Identifiable {
    let form: FormDef
    let record: SavedRecord
    var id: String { "\(form.id)-\(record.id.uuidString)" }
}

private struct DeskPage<Content: View>: View {
    var wash: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
        }
        .background {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                if let wash {
                    LinearGradient(
                        colors: [wash.opacity(0.32), wash.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 280)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct NamedDeskLink<Label: View>: View {
    let system: SystemCatalog
    let formName: String
    @ViewBuilder var label: () -> Label

    var body: some View {
        if let form = system.form(named: formName) {
            NavigationLink {
                FormScreen(form: form)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MetricTile: View {
    let value: Int
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DeskRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RecentDesk: View {
    let system: SystemCatalog
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let items = DeskData.recent(store, system, limit: 5)
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest on this phone")
                .font(.headline)
            if items.isEmpty {
                Text("Nothing saved in this tool yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        RecordEditor(form: item.form, existing: item.record)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.record.title(in: item.form))
                                    .foregroundStyle(.primary)
                                Text(item.form.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.record.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FinanceDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let receipts = DeskData.count(store, system, "Receipts")
        let payments = DeskData.count(store, system, "Payments")
        let invoices = DeskData.count(store, system, "Sales Invoices")
        let journals = DeskData.count(store, system, "Journal Entries")
        DeskPage {
            VStack(alignment: .leading, spacing: 14) {
                Text(DeskCopy.hello(person))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(receipts + payments + invoices == 0
                     ? "No receipts or invoices on this phone yet. Banking and Sales are the first places to post."
                     : "\(receipts) receipts, \(payments) payments, and \(invoices) invoices saved on this phone.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                HStack(spacing: 8) {
                    capsule("\(receipts) receipts")
                    capsule("\(payments) payments")
                    capsule("\(invoices) invoices")
                }
                HStack(spacing: 8) {
                    NamedDeskLink(system: system, formName: "Sales Invoices") {
                        Text("Invoices")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                            .foregroundStyle(Color(hex: 0x102033))
                    }
                    NamedDeskLink(system: system, formName: "Receipts") {
                        Text("Receipts")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.16), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x102033), tint.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NamedDeskLink(system: system, formName: "Receipts") {
                    MetricTile(value: receipts, label: "Receipts", symbol: "arrow.down.left", tint: tint)
                }
                NamedDeskLink(system: system, formName: "Payments") {
                    MetricTile(value: payments, label: "Payments", symbol: "arrow.up.right", tint: Color(hex: 0x9F1239))
                }
                NamedDeskLink(system: system, formName: "Sales Invoices") {
                    MetricTile(value: invoices, label: "Invoices", symbol: "receipt", tint: Color(hex: 0x1D4E89))
                }
                NamedDeskLink(system: system, formName: "Journal Entries") {
                    MetricTile(value: journals, label: "Journals", symbol: "book.closed", tint: Color(hex: 0x0F766E))
                }
            }
            RecentDesk(system: system)
        }
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white)
    }
}

private struct ERPDash: View {
    let system: SystemCatalog
    let person: String

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Whole suite")
                    .font(.title2.weight(.semibold))
                Text("Every desk in ERP, from banking through reports.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(system.groups.enumerated()), id: \.element.id) { index, group in
                    NavigationLink {
                        GroupBrowser(title: group.name, groups: [group])
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: symbol(for: group.id))
                                .foregroundStyle(tileTint(index))
                            Text(group.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text("\(group.forms.count) forms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func symbol(for id: String) -> String {
        switch id {
        case "banking": return "building.columns"
        case "receipts-payments": return "arrow.left.arrow.right"
        case "expense-claims": return "creditcard"
        case "sales": return "receipt"
        case "accounts": return "book.closed"
        case "reports": return "chart.bar"
        case "fixed-assets": return "building.2"
        case "pos": return "storefront"
        case "documents": return "folder"
        default: return "square.grid.2x2"
        }
    }

    private func tileTint(_ index: Int) -> Color {
        let palette: [UInt32] = [0x1D4E89, 0x0B6E4F, 0x9A3412, 0x6D28D9, 0x155E75, 0xBE185D]
        return Color(hex: palette[index % palette.count])
    }
}

private struct HRDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let roster = ["Employees", "Employee Profiles", "Departments", "Org Chart", "Sites", "Blocks"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let people = DeskData.count(store, system, "Employees")
        DeskPage(wash: tint) {
            HStack(alignment: .center, spacing: 16) {
                Text("\(people)")
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(person)'s people desk")
                        .font(.headline)
                    Text(people == 0 ? "No employees saved yet." : DeskCopy.saved(people) + " in Employees.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            ForEach(roster, id: \.self) { name in
                NamedDeskLink(system: system, formName: name) {
                    HStack(spacing: 12) {
                        Text(initials(name))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(tint, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(DeskCopy.saved(DeskData.count(store, system, name)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        let text = String(letters)
        return text.isEmpty ? "HR" : text.uppercased()
    }
}

private struct InventoryDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let kinds = ["Inventory Items", "Non-inventory Items", "Inventory Kits", "Item Groups", "Price Lists"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let items = DeskData.count(store, system, "Inventory Items")
        DeskPage {
            VStack(alignment: .leading, spacing: 6) {
                Text(person.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(items)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("inventory items on this phone")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            NamedDeskLink(system: system, formName: "Inventory Desk") {
                DeskRow(title: "Inventory Desk", detail: "Open the stock desk", symbol: "shippingbox.fill", tint: tint)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(kinds, id: \.self) { name in
                    NamedDeskLink(system: system, formName: name) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(DeskData.count(store, system, name))")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct ProcurementDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let stages: [(String, String)] = [
        ("Purchase Requisitions", "Req"),
        ("Purchase Quotes", "Quotes"),
        ("Purchase Orders", "Orders"),
        ("Suppliers", "Suppliers"),
    ]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Buying pipeline")
                    .font(.title2.weight(.semibold))
                Text("\(person) · requisition to supplier")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    NamedDeskLink(system: system, formName: stage.0) {
                        VStack(spacing: 6) {
                            Text("\(DeskData.count(store, system, stage.0))")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                            Text(stage.1)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if index < stages.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 18)
                    }
                }
            }
            NamedDeskLink(system: system, formName: "Budgets") {
                DeskRow(title: "Budgets", detail: DeskCopy.saved(DeskData.count(store, system, "Budgets")), symbol: "chart.pie", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Supplier Ledgers") {
                DeskRow(title: "Supplier Ledgers", detail: DeskCopy.saved(DeskData.count(store, system, "Supplier Ledgers")), symbol: "book", tint: tint)
            }
        }
    }
}

private struct FleetDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let vehicles = DeskData.count(store, system, "Vehicles")
        let drivers = DeskData.count(store, system, "Drivers")
        DeskPage(wash: tint) {
            Text(person)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statBlock(value: vehicles, label: "Vehicles", symbol: "truck.box", tint: tint)
                statBlock(value: drivers, label: "Drivers", symbol: "person.fill", tint: Color(hex: 0x0F766E))
            }
            NamedDeskLink(system: system, formName: "Vehicles") {
                DeskRow(title: "Vehicles", detail: DeskCopy.saved(vehicles), symbol: "truck.box", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Fuel Logs") {
                DeskRow(title: "Fuel Logs", detail: DeskCopy.saved(DeskData.count(store, system, "Fuel Logs")), symbol: "fuelpump", tint: Color(hex: 0xA16207))
            }
            NamedDeskLink(system: system, formName: "Trip Requests") {
                DeskRow(title: "Trip Requests", detail: DeskCopy.saved(DeskData.count(store, system, "Trip Requests")), symbol: "map", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Service Requests") {
                DeskRow(title: "Service Requests", detail: DeskCopy.saved(DeskData.count(store, system, "Service Requests")), symbol: "wrench", tint: Color(hex: 0x57534E))
            }
        }
    }

    private func statBlock(value: Int, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.white)
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LogisticsDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let stops = ["Shipments", "Dispatch Board", "Routes", "Proof of Delivery", "Carriers"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dispatch")
                    .font(.title2.weight(.semibold))
                Text("\(person) · move, route, deliver")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, name in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(tint)
                                .frame(width: 12, height: 12)
                                .padding(.top, 16)
                            if index < stops.count - 1 {
                                Rectangle()
                                    .fill(tint.opacity(0.35))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 12)
                        NamedDeskLink(system: system, formName: name) {
                            DeskRow(
                                title: name,
                                detail: DeskCopy.saved(DeskData.count(store, system, name)),
                                symbol: "arrow.right",
                                tint: tint
                            )
                        }
                        .padding(.bottom, index == stops.count - 1 ? 0 : 10)
                    }
                }
            }
        }
    }
}

private struct DistributionDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let stops: [(String, String)] = [
        ("Retailers", "storefront"),
        ("Beats", "map"),
        ("Field Reps", "figure.walk"),
        ("Van Loads", "box.truck"),
        ("Outlet Visits", "mappin.and.ellipse"),
    ]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's round")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(person)
                    .font(.title2.weight(.semibold))
                Text("Retailers, beats, vans, and outlet visits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(stops, id: \.0) { stop in
                NamedDeskLink(system: system, formName: stop.0) {
                    HStack(spacing: 12) {
                        Image(systemName: stop.1)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(tint, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.0)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(DeskCopy.saved(DeskData.count(store, system, stop.0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct CRMDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let columns = ["Leads", "Opportunities", "Customers"]
    private let follow = ["Contacts", "Follow-ups", "Complaints"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pipeline")
                    .font(.title2.weight(.semibold))
                Text(person)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(columns, id: \.self) { name in
                    NamedDeskLink(system: system, formName: name) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(DeskData.count(store, system, name))")
                                .font(.title.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                            Text(name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            ForEach(follow, id: \.self) { name in
                NamedDeskLink(system: system, formName: name) {
                    DeskRow(title: name, detail: DeskCopy.saved(DeskData.count(store, system, name)), symbol: "person.crop.circle", tint: Color(hex: 0xBE185D))
                }
            }
        }
    }
}

private struct ProjectDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let tiles = ["Project Updates", "Gantt Chart", "Material Requests", "Payment Requests (IPC)"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 6) {
                Text(person)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Projects")
                    .font(.title2.weight(.semibold))
            }
            NamedDeskLink(system: system, formName: "New Project") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New project")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(DeskCopy.saved(DeskData.count(store, system, "New Project")))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(tiles, id: \.self) { name in
                    NamedDeskLink(system: system, formName: name) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(DeskData.count(store, system, name))")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct ContractDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let contracts = DeskData.count(store, system, "Contracts")
        DeskPage(wash: tint) {
            Text(person)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.25))
                    .frame(height: 108)
                    .padding(.horizontal, 18)
                    .offset(y: 16)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.45))
                    .frame(height: 108)
                    .padding(.horizontal, 10)
                    .offset(y: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONTRACTS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(contracts)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("on file")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(height: 140)
            NamedDeskLink(system: system, formName: "Contracts") {
                DeskRow(title: "Contracts", detail: DeskCopy.saved(contracts), symbol: "doc.text.fill", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Contract Milestones") {
                DeskRow(title: "Milestones", detail: DeskCopy.saved(DeskData.count(store, system, "Contract Milestones")), symbol: "flag", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Contract Variations") {
                DeskRow(title: "Variations", detail: DeskCopy.saved(DeskData.count(store, system, "Contract Variations")), symbol: "pencil.line", tint: Color(hex: 0x6D28D9))
            }
            NamedDeskLink(system: system, formName: "Contractor Invoices") {
                DeskRow(title: "Contractor invoices", detail: DeskCopy.saved(DeskData.count(store, system, "Contractor Invoices")), symbol: "receipt", tint: Color(hex: 0x9A3412))
            }
        }
    }
}

private struct ProductionDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let jobs = ["Production Orders", "Production Plans", "Machines", "Bill of Materials", "Factories"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shop floor")
                    .font(.title2.weight(.semibold))
                Text(person)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(jobs, id: \.self) { name in
                NamedDeskLink(system: system, formName: name) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("JOB")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(tint)
                            Text(name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(DeskCopy.saved(DeskData.count(store, system, name)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(tint.opacity(0.7))
                    }
                }
            }
        }
    }
}

private struct MaintenanceDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let queue = ["Work Orders", "Job Cards", "Preventive Schedules", "Machines"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Job queue")
                    .font(.title2.weight(.semibold))
                Text("\(person) · open the next card")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(queue.enumerated()), id: \.offset) { index, name in
                NamedDeskLink(system: system, formName: name) {
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(DeskCopy.saved(DeskData.count(store, system, name)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == 0 ? Color(hex: 0xC2410C) : tint.opacity(0.4))
                            .frame(width: 4)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

private struct LabDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let lab = SystemTheme.tint(for: "lab")
        let qa = Color(hex: 0x0F766E)
        DeskPage {
            Text(person)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            band(title: "Lab bench", tint: lab, forms: ["Lab Samples", "Lab Requests", "Lab Trials", "Cupping Sheets"])
            band(title: "Quality assurance", tint: qa, forms: ["Quality Checks", "Incoming Inspections", "Release Decisions", "Non-conformances"])
        }
    }

    private func band(title: String, tint: Color, forms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
            ForEach(forms, id: \.self) { name in
                NamedDeskLink(system: system, formName: name) {
                    HStack {
                        Text(name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(DeskData.count(store, system, name))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FarmerDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let chain = ["Farmers", "Farms", "Plots", "Crops", "Harvest Lots", "Collections"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trace")
                    .font(.title2.weight(.semibold))
                Text("\(person) · farmer to collection")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(chain.enumerated()), id: \.offset) { index, name in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(tint, in: Circle())
                            if index < chain.count - 1 {
                                Rectangle()
                                    .fill(tint.opacity(0.35))
                                    .frame(width: 2, height: 18)
                            }
                        }
                        NamedDeskLink(system: system, formName: name) {
                            HStack {
                                Text(name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(DeskCopy.saved(DeskData.count(store, system, name)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct AuditorDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    private let rows = ["Engagements", "Workpapers", "Findings", "Controls", "Recommendations"]

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let findings = DeskData.count(store, system, "Findings")
        DeskPage(wash: tint) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(person)
                        .font(.headline)
                    Text(findings == 0 ? "No findings on this phone." : "\(findings) findings saved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(rows, id: \.self) { name in
                NamedDeskLink(system: system, formName: name) {
                    DeskRow(
                        title: name,
                        detail: DeskCopy.saved(DeskData.count(store, system, name)),
                        symbol: name == "Findings" ? "exclamationmark.bubble" : "doc.text",
                        tint: name == "Findings" ? Color(hex: 0x9F1239) : tint
                    )
                }
            }
        }
    }
}

private struct SecurityDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        let exceptions = DeskData.count(store, system, "Open Exceptions")
        DeskPage {
            NamedDeskLink(system: system, formName: "Gate Check-In/Out") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ON DUTY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(person)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Gate check-in / out")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(DeskCopy.saved(DeskData.count(store, system, "Gate Check-In/Out")))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            NamedDeskLink(system: system, formName: "Open Exceptions") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open exceptions")
                            .font(.headline)
                            .foregroundStyle(Color(hex: 0x9F1239))
                        Text(DeskCopy.saved(exceptions))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(exceptions)")
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: 0x9F1239))
                }
                .padding(14)
                .background(Color(hex: 0x9F1239).opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            NamedDeskLink(system: system, formName: "Visitor Pre-Registrations") {
                DeskRow(title: "Visitor pre-registrations", detail: DeskCopy.saved(DeskData.count(store, system, "Visitor Pre-Registrations")), symbol: "person.badge.clock", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Standing Passes") {
                DeskRow(title: "Standing passes", detail: DeskCopy.saved(DeskData.count(store, system, "Standing Passes")), symbol: "wallet.pass", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Material Gate Passes") {
                DeskRow(title: "Material gate passes", detail: DeskCopy.saved(DeskData.count(store, system, "Material Gate Passes")), symbol: "shippingbox", tint: tint)
            }
            NamedDeskLink(system: system, formName: "Blocked List") {
                DeskRow(title: "Blocked list", detail: DeskCopy.saved(DeskData.count(store, system, "Blocked List")), symbol: "hand.raised", tint: Color(hex: 0x9F1239))
            }
        }
    }
}

private struct AdminDash: View {
    let system: SystemCatalog
    let person: String
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Operator console")
                    .font(.title2.weight(.semibold))
                Text(person)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            action("Create user", detail: "Add someone who can sign in on the web.", symbol: "person.badge.plus", countName: "Create user")
            action("Create role", detail: "Name a set of permissions.", symbol: "key", countName: "Create role")
            action("Tools", detail: "Which connected apps are on, and for whom.", symbol: "slider.horizontal.3", countName: "Tools")
        }
    }

    private func action(_ title: String, detail: String, symbol: String, countName: String) -> some View {
        let tint = SystemTheme.tint(for: system.id)
        return NamedDeskLink(system: system, formName: countName) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(DeskCopy.saved(DeskData.count(store, system, countName)))
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct ServiceDash: View {
    let system: SystemCatalog
    let person: String

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        DeskPage(wash: tint) {
            VStack(spacing: 14) {
                Image(systemName: SystemTheme.symbol(for: system.id))
                    .font(.system(size: 36))
                    .foregroundStyle(tint)
                    .frame(width: 76, height: 76)
                    .background(tint.opacity(0.14), in: Circle())
                Text(system.name)
                    .font(.title2.weight(.semibold))
                Text("Signed in as \(person)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("This service has no forms on the phone. Web apps sign in through it, then read and write records.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                if let port = system.port {
                    Text("Port \(port)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
    }
}
