import SwiftUI

struct ToolShell: View {
    let system: SystemCatalog
    @ObservedObject var session: SessionStore
    let systems: [SystemCatalog]

    @StateObject private var store: RecordStore
    @State private var showTools = false
    @State private var confirmSignOut = false

    init(system: SystemCatalog, session: SessionStore, systems: [SystemCatalog]) {
        self.system = system
        self.session = session
        self.systems = systems
        _store = StateObject(wrappedValue: RecordStore(systemID: system.id))
    }

    var body: some View {
        Group {
            if system.id == "pos" {
                NavigationStack {
                    Group {
                        if session.access.canCreate {
                            TillView()
                        } else {
                            ContentUnavailableView(
                                "Till is view only",
                                systemImage: "storefront",
                                description: Text("\(session.role.rawValue) can open POS and cannot record a sale.")
                            )
                        }
                    }
                    .toolChrome(tool: system.name, person: accessLine, openTools: { showTools = true }, signOut: { confirmSignOut = true })
                }
            } else if pages.count < 2 {
                NavigationStack {
                    ToolDashboard(system: system, person: session.name)
                        .toolChrome(tool: system.name, person: accessLine, openTools: { showTools = true }, signOut: { confirmSignOut = true })
                }
            } else {
                TabView {
                    ForEach(pages) { page in
                        NavigationStack {
                            pageBody(page)
                                .toolChrome(tool: system.name, person: accessLine, openTools: { showTools = true }, signOut: { confirmSignOut = true })
                        }
                        .tabItem {
                            Label(page.tab, systemImage: page.symbol)
                        }
                        .tag(page.id)
                    }
                }
            }
        }
        .tint(SystemTheme.tint(for: system.id))
        .environmentObject(store)
        .sheet(isPresented: $showTools) {
            NavigationStack {
                ToolPicker(systems: session.access.allowed(systems), selectedID: system.id) { picked in
                    showTools = false
                    session.open(toolID: picked.id)
                }
            }
        }
        .confirmationDialog("Sign out of this phone?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { session.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your records stay on this phone. Sign in again with a department to open that department’s tools.")
        }
    }

    private var accessLine: String {
        "\(session.department.rawValue) · \(session.role.rawValue)"
    }

    private var pages: [ToolPage] {
        ToolPage.make(for: system)
    }

    @ViewBuilder
    private func pageBody(_ page: ToolPage) -> some View {
        if page.isHome {
            ToolDashboard(system: system, person: session.name)
        } else {
            GroupBrowser(title: page.browserTitle, groups: page.groups, showsHeading: false)
        }
    }
}

struct ToolPage: Identifiable {
    let id: String
    let tab: String
    let browserTitle: String
    let symbol: String
    let groups: [FormGroup]

    var isHome: Bool { id == "home" }

    static func make(for system: SystemCatalog) -> [ToolPage] {
        let home = ToolPage(
            id: "home",
            tab: "Home",
            browserTitle: system.name,
            symbol: SystemTheme.symbol(for: system.id),
            groups: []
        )
        let featuredPages: [ToolPage] = featured(system.id).compactMap { pick in
            guard let group = system.groups.first(where: { $0.id == pick.id }) else { return nil }
            return ToolPage(id: group.id, tab: pick.tab, browserTitle: pick.title, symbol: pick.symbol, groups: [group])
        }
        let used = Set(featuredPages.map(\.id))
        let rest = system.groups.filter { !used.contains($0.id) }
        var result = [home] + featuredPages
        if !rest.isEmpty {
            result.append(ToolPage(id: "more", tab: "More", browserTitle: "More", symbol: "ellipsis.circle", groups: rest))
        }
        return result
    }

    private struct Pick {
        let id: String
        let tab: String
        let title: String
        let symbol: String
    }

    private static func featured(_ id: String) -> [Pick] {
        switch id {
        case "finance":
            return [
                Pick(id: "banking", tab: "Banking", title: "Banking", symbol: "building.columns"),
                Pick(id: "sales", tab: "Sales", title: "Sales", symbol: "receipt"),
                Pick(id: "accounts", tab: "Books", title: "Accounts", symbol: "book.closed"),
            ]
        case "erp":
            return [
                Pick(id: "sales", tab: "Sales", title: "Sales", symbol: "receipt"),
                Pick(id: "accounts", tab: "Books", title: "Accounts", symbol: "book.closed"),
                Pick(id: "reports", tab: "Reports", title: "Reports", symbol: "chart.bar"),
            ]
        case "auditor":
            return [
                Pick(id: "auditor", tab: "Audit", title: "Auditor", symbol: "checkmark.seal"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "hr":
            return [
                Pick(id: "hr-payroll", tab: "People", title: "HR & Payroll", symbol: "person.3"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "inventory":
            return [
                Pick(id: "inventory", tab: "Stock", title: "Inventory", symbol: "shippingbox"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "procurement":
            return [
                Pick(id: "procurement", tab: "Buying", title: "Procurement", symbol: "cart"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "fleet":
            return [
                Pick(id: "fleet", tab: "Fleet", title: "Fleet", symbol: "truck.box"),
                Pick(id: "tracking", tab: "Tracking", title: "Tracking", symbol: "location"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "logistics":
            return [
                Pick(id: "logistics", tab: "Moves", title: "Logistics", symbol: "arrow.left.arrow.right"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "distribution":
            return [
                Pick(id: "distribution", tab: "Field", title: "Distribution", symbol: "box.truck"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "contract-manager":
            return [
                Pick(id: "contract-manager", tab: "Contracts", title: "Contract Manager", symbol: "doc.text"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "project-manager":
            return [
                Pick(id: "project-manager", tab: "Projects", title: "Project Manager", symbol: "chart.bar"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "crm":
            return [
                Pick(id: "crm", tab: "Pipeline", title: "CRM", symbol: "person.crop.circle"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "production":
            return [
                Pick(id: "production", tab: "Floor", title: "Production", symbol: "gearshape.2"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "maintenance":
            return [
                Pick(id: "maintenance", tab: "Jobs", title: "Maintenance", symbol: "wrench.and.screwdriver"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "lab":
            return [
                Pick(id: "lab", tab: "Lab", title: "Lab", symbol: "testtube.2"),
                Pick(id: "quality-assurance", tab: "QA", title: "Quality Assurance", symbol: "checkmark.seal"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "farmer-traceability":
            return [
                Pick(id: "farmer-traceability", tab: "Trace", title: "Farmer Traceability", symbol: "leaf"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "security":
            return [
                Pick(id: "security", tab: "Gate", title: "Security", symbol: "shield"),
                Pick(id: "documents", tab: "Files", title: "Documents", symbol: "folder"),
            ]
        case "admin":
            return [
                Pick(id: "create-user", tab: "Users", title: "Create user", symbol: "person.badge.plus"),
                Pick(id: "create-role", tab: "Roles", title: "Create role", symbol: "key"),
                Pick(id: "tools", tab: "Tools", title: "Tools", symbol: "slider.horizontal.3"),
            ]
        default:
            return []
        }
    }
}

private struct ToolChrome: ViewModifier {
    let tool: String
    let person: String
    let openTools: () -> Void
    let signOut: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(tool)
                            .font(.headline)
                        Text(person)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: openTools) {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("Switch tool")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Sign out")
                }
            }
    }
}

extension View {
    func toolChrome(tool: String, person: String, openTools: @escaping () -> Void, signOut: @escaping () -> Void) -> some View {
        modifier(ToolChrome(tool: tool, person: person, openTools: openTools, signOut: signOut))
    }
}
