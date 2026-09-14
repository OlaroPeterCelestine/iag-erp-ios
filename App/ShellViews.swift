import SwiftUI
import ErpCore

struct ShellView: View {
    @EnvironmentObject var box: StoreBox
    @State private var tab = 0

    var body: some View {
        let _ = box.tick
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            DepartmentsView()
                .tabItem { Label("Departments", systemImage: "building.2") }
                .tag(1)
            NavigationStack {
                ClockInView()
            }
            .tabItem { Label("Clock", systemImage: "clock") }
            .tag(2)
            if box.store.canApprove {
                ApprovalsView()
                    .tabItem { Label("Approvals", systemImage: "checkmark.rectangle") }
                    .tag(3)
                    .badge(box.store.pendingApprovals.count)
            }
            MoreView()
                .tabItem { Label("More", systemImage: "square.grid.2x2") }
                .tag(4)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var box: StoreBox
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let first = store.user?.name.split(separator: " ").first.map(String.init) ?? "there"
        let hits = store.searchHits(query)
        NavigationStack {
            List {
                Section {
                    Text("Good morning, \(first)").font(.title2.bold())
                    Text("\(store.user?.role ?? "Inspire Africa Group") · Finance ERP").foregroundStyle(.secondary)
                }
                if store.canClockIn {
                    Section("Clock in") {
                        NavigationLink {
                            ClockInView()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(store.openAttendanceToday() == nil ? "Clock in" : "Clock out")
                                Text("GPS punch against HR Sites and Blocks — every login.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if store.isAdmin {
                    Section("Access") {
                        NavigationLink("Users & custom roles") { AccessView() }
                    }
                }
                Section("Snapshot") {
                    ForEach(store.kpis, id: \.label) { kpi in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(kpi.label).font(.caption).foregroundStyle(.secondary)
                                Text(kpi.value).font(.headline)
                            }
                            Spacer()
                            Text(kpi.hint).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Search") {
                        if hits.isEmpty {
                            Text("No matches in desks, features, or records.").foregroundStyle(.secondary)
                        } else {
                            ForEach(hits) { hit in
                                SearchHitRow(hit: hit)
                            }
                        }
                    }
                } else {
                    if store.canApprove {
                        Section("Needs attention") {
                            if store.pendingApprovals.isEmpty {
                                Text("Nothing waiting for your desk.").foregroundStyle(.secondary)
                            } else {
                                ForEach(store.pendingApprovals.prefix(4), id: \.id) { rec in
                                    NavigationLink {
                                        RecordDetailView(recordId: rec.id)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(rec.title)
                                            Text("\(rec.entity) · \(rec.subtitle)").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ForEach(departmentGroups, id: \.self) { group in
                        let modules = store.visibleModules.filter { $0.group == group }
                        if !modules.isEmpty {
                            Section(group) {
                                ForEach(modules, id: \.id) { module in
                                    NavigationLink {
                                        DepartmentView(moduleId: module.id)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(module.label)
                                            Text(featureSummary(module)).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        store.setActiveDepartment(module.id)
                                    })
                                }
                            }
                        }
                    }
                    Section("Recent") {
                        ForEach(store.recent.filter { store.canOpen($0.moduleId) }, id: \.id) { rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(rec.title)
                                    Text("\(rec.entity) · \(rec.status)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Overview")
            .searchable(text: $query, prompt: "Invoices, lots, employees, desks…")
            .toolbar {
                if store.isAdmin {
                    NavigationLink { AccessView() } label: { Image(systemName: "shield") }
                }
                NavigationLink { ProfileView() } label: { Image(systemName: "person.circle") }
            }
        }
    }
}

struct DepartmentsView: View {
    @EnvironmentObject var box: StoreBox
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        NavigationStack {
            List {
                ForEach(departmentGroups, id: \.self) { group in
                    let modules = store.visibleModules.filter { module in
                        guard module.group == group else { return false }
                        if q.isEmpty { return true }
                        return module.label.lowercased().contains(q)
                            || module.entities.contains { $0.lowercased().contains(q) }
                    }
                    if !modules.isEmpty {
                        Section(group) {
                            ForEach(modules, id: \.id) { module in
                                NavigationLink {
                                    DepartmentView(moduleId: module.id)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(module.label)
                                        Text(featureSummary(module)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    store.setActiveDepartment(module.id)
                                })
                            }
                        }
                    }
                }
            }
            .navigationTitle("Departments")
            .searchable(text: $query, prompt: "Find a desk or feature")
        }
    }
}

struct ApprovalsView: View {
    @EnvironmentObject var box: StoreBox

    var body: some View {
        let _ = box.tick
        NavigationStack {
            List {
                if box.store.pendingApprovals.isEmpty {
                    Text("Nothing waiting for your desk.").foregroundStyle(.secondary)
                } else {
                    ForEach(box.store.pendingApprovals, id: \.id) { rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(rec.title)
                                Text("\(rec.entity) · \(rec.subtitle)").font(.caption).foregroundStyle(.secondary)
                                Text(rec.status).foregroundStyle(statusColor(rec.status))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Approvals")
        }
    }
}

struct MoreView: View {
    @EnvironmentObject var box: StoreBox

    var body: some View {
        let store = box.store
        let _ = box.tick
        NavigationStack {
            List {
                ForEach(workspaceGroups, id: \.self) { group in
                    let tools = store.visibleWorkspaceTools.filter { $0.group == group }
                    if !tools.isEmpty {
                        Section(group) {
                            ForEach(tools) { tool in
                                NavigationLink {
                                    WorkspaceToolView(toolId: tool.id)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(tool.label)
                                        Text(tool.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section("Account") {
                    NavigationLink("Profile") { ProfileView() }
                    if store.isAdmin {
                        NavigationLink("Users & roles") { AccessView() }
                    }
                }
            }
            .navigationTitle("Workspace")
        }
    }
}

struct SearchHitRow: View {
    @EnvironmentObject var box: StoreBox
    let hit: SearchHit

    var body: some View {
        switch hit.kind {
        case .module:
            NavigationLink {
                DepartmentView(moduleId: hit.moduleId)
            } label: {
                labeled(hit.title, "Desk · \(hit.subtitle)")
            }
        case .entity:
            NavigationLink {
                EntityListView(moduleId: hit.moduleId, entity: hit.entity ?? "")
            } label: {
                labeled(hit.title, "Feature · \(hit.subtitle)")
            }
        case .record:
            NavigationLink {
                RecordDetailView(recordId: hit.recordId ?? "")
            } label: {
                labeled(hit.title, hit.subtitle)
            }
        case .tool:
            NavigationLink {
                WorkspaceToolView(toolId: hit.moduleId)
            } label: {
                labeled(hit.title, "Workspace · \(hit.subtitle)")
            }
        }
    }

    private func labeled(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct WorkspaceToolView: View {
    @EnvironmentObject var box: StoreBox
    let toolId: String
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let tool = workspaceTools.first { $0.id == toolId }
        Group {
            switch toolId {
            case "clock-in":
                ClockInView()
            case "trace":
                List {
                    Section("Look up a document, plate, lot, or person") {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                            Text("Type at least two characters.").foregroundStyle(.secondary)
                        } else {
                            let hits = store.searchHits(query)
                            if hits.isEmpty {
                                Text("Nothing matched.").foregroundStyle(.secondary)
                            } else {
                                ForEach(hits) { hit in SearchHitRow(hit: hit) }
                            }
                        }
                    }
                }
                .searchable(text: $query, prompt: "IAG-LOT, SI-2026, UAX 221K…")
            case "analytics":
                List {
                    Section("Workspace") {
                        LabeledContent("Departments", value: "\(store.visibleModules.count)")
                        LabeledContent("Features", value: "\(store.visibleModules.reduce(0) { $0 + $1.entities.count })")
                        LabeledContent("Records", value: "\(store.records.filter { store.canOpen($0.moduleId) }.count)")
                        LabeledContent("Pending approvals", value: "\(store.pendingApprovals.count)")
                    }
                    ForEach(departmentGroups, id: \.self) { group in
                        let modules = store.visibleModules.filter { $0.group == group }
                        if !modules.isEmpty {
                            Section(group) {
                                ForEach(modules, id: \.id) { module in
                                    LabeledContent(module.label, value: "\(store.forModule(module.id).count)")
                                }
                            }
                        }
                    }
                }
            case "accounting-documents":
                List {
                    if store.accountingDocuments.isEmpty {
                        Text("No accounting documents yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.accountingDocuments, id: \.id) { rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(rec.title)
                                    Text("\(rec.entity) · \(rec.status)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            case "payment-requests":
                List {
                    if store.pendingApprovals.isEmpty {
                        Text("No open desk requests.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.pendingApprovals, id: \.id) { rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(rec.title)
                                    Text("\(rec.entity) · \(rec.subtitle)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            case "templates":
                List {
                    ForEach(erpTemplates, id: \.self) { name in
                        Text(name)
                    }
                }
            case "comms":
                List {
                    ForEach(erpComms, id: \.title) { row in
                        VStack(alignment: .leading) {
                            Text(row.title)
                            Text(row.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            case "guides":
                List {
                    ForEach(erpGuides, id: \.title) { row in
                        Section(row.title) { Text(row.body) }
                    }
                }
            case "qna":
                List {
                    ForEach(erpQnA, id: \.q) { row in
                        Section(row.q) { Text(row.a) }
                    }
                }
            case "release-notes":
                List {
                    Section("ERP iOS \(appVersion)") {
                        Text("Every web ERP desk and feature is on the phone: departments, entity lists, approvals, trace, documents, and workspace tools. RBAC matches web IAG ERP.")
                    }
                }
            case "activity-logs":
                List {
                    ForEach(store.recent.filter { store.canOpen($0.moduleId) }, id: \.id) { rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(rec.title)
                                Text("\(rec.entity) · \(rec.status) · \(rec.date)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            case "system-health":
                List {
                    LabeledContent("App", value: "ERP iOS \(appVersion)")
                    LabeledContent("Role", value: store.user?.role ?? "—")
                    LabeledContent("Records", value: "\(store.records.count)")
                    LabeledContent("Roles", value: "\(store.roles.count)")
                    LabeledContent("Workspace users", value: "\(store.workspaceUsers.count)")
                    LabeledContent("Theme", value: store.themeMode)
                }
            case "settings":
                Form {
                    Picker("Theme", selection: Binding(
                        get: { store.themeMode },
                        set: { store.setThemeMode($0) }
                    )) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    LabeledContent("Desks on this device", value: "\(store.visibleModules.count)")
                }
            default:
                Text(tool?.description ?? "Unknown tool")
            }
        }
        .navigationTitle(tool?.label ?? "Workspace")
    }
}

func featureSummary(_ module: ErpModule) -> String {
    let names = module.entities.prefix(3).joined(separator: ", ")
    let extra = module.entities.count > 3 ? " +\(module.entities.count - 3)" : ""
    return "\(module.entities.count) features · \(names)\(extra)"
}

let erpTemplates = [
    "Sales invoice",
    "Purchase order",
    "Expense claim",
    "General request",
    "Fuel request",
    "Leave request",
    "IPC payment certificate",
    "Payslip run",
]

let erpComms: [(title: String, detail: String)] = [
    ("Payslip pack — August", "Email · HR · Sent"),
    ("Overdue SI-2026-188", "SMS · Cafe Javas · Queued"),
    ("IPC-2026-006 submitted", "Email · Mukwano Builders · Sent"),
]

let erpGuides: [(title: String, body: String)] = [
    ("Desks", "Every sidebar tab from web IAG ERP is a department here. Open a desk to see every feature (customers, invoices, lots, reports, …), then open a record."),
    ("Clock in", "The Clock tab is on every signed-in phone. GPS is checked against HR Sites and Blocks. Outside the fence is rejected; HR still sees punches on Attendance and Punch Log."),
    ("Approvals", "Expense claims, general requests, oral payments, leave, IPC, materials, fuel, trips, and maintenance wait on the Approvals tab when your role has a desk."),
    ("SoD", "Administrators see every app. Specialty desks (fleet, lab, CRM, …) need an explicit grant. Contractors stay on Projects and Contract Manager, plus Clock In."),
]

let erpQnA: [(q: String, a: String)] = [
    ("Where is Banking?", "Home or Departments → Treasury → Banking. Features include bank accounts, transfers, statements, and reconciliations."),
    ("Who can clock in?", "Every signed-in login, including clerk, viewer, and contractor. You do not need the HR desk."),
    ("Who can approve?", "QS, Stores, Procurement, HR, HOD, PM, Accounts, GM, CEO, Finance, and Administrators. Clerk and Viewer cannot."),
    ("Demo password?", "iagdemo. Try admin to see every desk."),
]

