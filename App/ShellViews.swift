import SwiftUI
import ErpCore

struct ShellView: View {
    @EnvironmentObject var box: StoreBox
    @State private var tab = 0

    var body: some View {
        let _ = box.tick
        TabView(selection: $tab) {
            Group {
                if box.store.activeAppId == nil {
                    AppsLauncherView()
                } else {
                    HomeView()
                }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
            DepartmentsView()
                .tabItem { Label("Desks", systemImage: "building.2") }
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
                    .badge(box.store.appPendingApprovals.count)
            }
            MoreView()
                .tabItem { Label("More", systemImage: "square.grid.2x2") }
                .tag(4)
        }
        .tint(IagTheme.orange)
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
        let app = store.activeSuiteApp
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let recents = Array(store.recent.filter { store.canOpen($0.moduleId) }.prefix(3))
        let todos = Array(store.appPendingApprovals.prefix(3))
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !searching {
                        WelcomeCard(
                            name: first,
                            subtitle: app?.label ?? store.user?.role ?? appName,
                            stats: store.welcomeStats
                        )
                    }

                    if searching {
                        VStack(alignment: .leading, spacing: 12) {
                            IagSectionHeader(title: "Search")
                            if hits.isEmpty {
                                IagGrouped { IagEmptyHint(text: "No matches in desks, features, or records.") }
                            } else {
                                IagGrouped {
                                    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                                        SearchHitRow(hit: hit)
                                            .padding(14)
                                        if index < hits.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }
                    } else {
                        if !store.homeQuickActions.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                IagSectionHeader(title: "Do now")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(store.homeQuickActions) { action in
                                            NavigationLink {
                                                QuickActionDestination(action: action)
                                            } label: {
                                                QuickActionButton(
                                                    action: action,
                                                    badge: action.kind == .approvals ? store.appPendingApprovals.count : 0
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }

                        if !store.kpis.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                IagSectionHeader(title: "Snapshot")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(store.kpis, id: \.label) { kpi in
                                            KpiChip(kpi: kpi)
                                        }
                                    }
                                }
                            }
                        }

                        if store.canApprove && !todos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                NavigationLink {
                                    ApprovalsList()
                                } label: {
                                    IagSectionHeader(title: "Waiting for you", accessory: "See all")
                                }
                                .buttonStyle(.plain)
                                IagGrouped {
                                    ForEach(Array(todos.enumerated()), id: \.element.id) { index, rec in
                                        NavigationLink {
                                            RecordDetailView(recordId: rec.id)
                                        } label: {
                                            DeskRow(
                                                title: rec.title,
                                                subtitle: "\(rec.entity) · \(rec.subtitle)",
                                                systemName: "checkmark.rectangle",
                                                status: rec.status
                                            )
                                            .padding(14)
                                        }
                                        .buttonStyle(.plain)
                                        if index < todos.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }

                        if !recents.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                IagSectionHeader(title: "Jump back")
                                IagGrouped {
                                    ForEach(Array(recents.enumerated()), id: \.element.id) { index, rec in
                                        NavigationLink {
                                            RecordDetailView(recordId: rec.id)
                                        } label: {
                                            DeskRow(
                                                title: rec.title,
                                                subtitle: rec.entity,
                                                systemName: "doc.text",
                                                status: rec.status
                                            )
                                            .padding(14)
                                        }
                                        .buttonStyle(.plain)
                                        if index < recents.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .iagCanvas()
            .navigationTitle(app?.label ?? "Home")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search desks and records")
            .toolbar {
                Button {
                    store.closeApp()
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Apps")
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
                    let modules = store.appModules.filter { module in
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
                                    DeskRow(
                                        title: module.label,
                                        subtitle: featureSummary(module),
                                        systemName: module.icon,
                                        color: IagTheme.ink
                                    )
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    store.setActiveDepartment(module.id)
                                })
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .iagCanvas()
            .navigationTitle(box.store.activeSuiteApp?.label ?? "Desks")
            .searchable(text: $query, prompt: "Find a desk or feature")
        }
    }
}

struct ApprovalsView: View {
    var body: some View {
        NavigationStack {
            ApprovalsList()
        }
    }
}

struct ApprovalsList: View {
    @EnvironmentObject var box: StoreBox

    var body: some View {
        let _ = box.tick
        List {
            if box.store.appPendingApprovals.isEmpty {
                Text("Nothing waiting for your desk.").foregroundStyle(.secondary)
            } else {
                ForEach(box.store.appPendingApprovals, id: \.id) { rec in
                    NavigationLink {
                        RecordDetailView(recordId: rec.id)
                    } label: {
                        DeskRow(
                            title: rec.title,
                            subtitle: "\(rec.entity) · \(rec.subtitle)",
                            systemName: "checkmark.rectangle",
                            status: rec.status
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .iagCanvas()
        .navigationTitle("Approvals")
        .task {
            await box.store.refreshApprovals()
        }
    }
}

struct QuickActionDestination: View {
    let action: QuickAction

    var body: some View {
        switch action.kind {
        case .clock:
            ClockInView()
        case .approvals:
            ApprovalsList()
        case .access:
            AccessView()
        case .create:
            if let entity = action.entity {
                RecordFormView(moduleId: action.moduleId, entity: entity)
            } else {
                DepartmentView(moduleId: action.moduleId)
            }
        case .list:
            if let entity = action.entity {
                EntityListView(moduleId: action.moduleId, entity: entity)
            } else {
                DepartmentView(moduleId: action.moduleId)
            }
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
                if store.activeAppId != nil {
                    Section("Apps") {
                        Button {
                            store.closeApp()
                        } label: {
                            DeskRow(
                                title: "Switch app",
                                subtitle: store.activeSuiteApp.map { "You are in \($0.label)." } ?? "Open another IAG tool.",
                                systemName: "square.grid.2x2"
                            )
                        }
                    }
                }
                ForEach(workspaceGroups, id: \.self) { group in
                    let tools = store.visibleWorkspaceTools.filter { $0.group == group }
                    if !tools.isEmpty {
                        Section(group) {
                            ForEach(tools) { tool in
                                NavigationLink {
                                    WorkspaceToolView(toolId: tool.id)
                                } label: {
                                    DeskRow(
                                        title: tool.label,
                                        subtitle: tool.description,
                                        systemName: workspaceIcon(tool.id)
                                    )
                                }
                            }
                        }
                    }
                }
                Section("Account") {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        DeskRow(title: "Profile", subtitle: "Name, theme, and sign out", systemName: "person.crop.circle")
                    }
                    if store.isAdmin {
                        NavigationLink {
                            AccessView()
                        } label: {
                            DeskRow(title: "Users & roles", subtitle: "Custom roles and workspace users", systemName: "shield")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .iagCanvas()
            .navigationTitle("More")
        }
    }
}

struct AppsLauncherView: View {
    @EnvironmentObject var box: StoreBox
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let first = store.user?.name.split(separator: " ").first.map(String.init) ?? "there"
        let todos = Array(store.pendingApprovals.prefix(3))
        let recents = Array(store.recent.filter { store.canOpen($0.moduleId) }.prefix(3))
        let today = store.launcherQuickActions.filter { $0.appId == nil }
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hits = store.searchHits(query)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !searching {
                        WelcomeCard(
                            name: first,
                            subtitle: store.user?.role ?? appName,
                            stats: store.welcomeStats
                        )
                    }

                    if searching {
                        VStack(alignment: .leading, spacing: 12) {
                            IagSectionHeader(title: "Search")
                            if hits.isEmpty {
                                IagGrouped { IagEmptyHint(text: "No matches in desks, features, or records.") }
                            } else {
                                IagGrouped {
                                    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                                        SearchHitRow(hit: hit)
                                            .padding(14)
                                        if index < hits.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }
                    } else {
                        if !today.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                IagSectionHeader(title: "Do now")
                                HStack(spacing: 10) {
                                    ForEach(today) { action in
                                        NavigationLink {
                                            QuickActionDestination(action: action)
                                        } label: {
                                            TodayActionCard(
                                                action: action,
                                                badge: action.kind == .approvals ? store.pendingApprovals.count : 0
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            IagSectionHeader(title: "Apps")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                                ForEach(store.visibleSuiteApps) { app in
                                    Button {
                                        store.openApp(app.id)
                                    } label: {
                                        AppTile(app: app)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if store.canApprove && !todos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                NavigationLink {
                                    ApprovalsList()
                                } label: {
                                    IagSectionHeader(title: "Waiting for you", accessory: "See all")
                                }
                                .buttonStyle(.plain)
                                IagGrouped {
                                    ForEach(Array(todos.enumerated()), id: \.element.id) { index, rec in
                                        NavigationLink {
                                            RecordDetailView(recordId: rec.id)
                                        } label: {
                                            DeskRow(
                                                title: rec.title,
                                                subtitle: rec.entity,
                                                systemName: "checkmark.rectangle",
                                                status: rec.status
                                            )
                                            .padding(14)
                                        }
                                        .buttonStyle(.plain)
                                        if index < todos.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }

                        if !recents.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                IagSectionHeader(title: "Jump back")
                                IagGrouped {
                                    ForEach(Array(recents.enumerated()), id: \.element.id) { index, rec in
                                        NavigationLink {
                                            RecordDetailView(recordId: rec.id)
                                        } label: {
                                            DeskRow(
                                                title: rec.title,
                                                subtitle: rec.entity,
                                                systemName: "doc.text",
                                                status: rec.status
                                            )
                                            .padding(14)
                                        }
                                        .buttonStyle(.plain)
                                        if index < recents.count - 1 { IagRowDivider() }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .iagCanvas()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search anything")
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
                DeskRow(title: hit.title, subtitle: "Desk · \(hit.subtitle)", systemName: "building.2")
            }
        case .entity:
            NavigationLink {
                EntityListView(moduleId: hit.moduleId, entity: hit.entity ?? "")
            } label: {
                DeskRow(title: hit.title, subtitle: "Feature · \(hit.subtitle)", systemName: "square.grid.2x2")
            }
        case .record:
            NavigationLink {
                RecordDetailView(recordId: hit.recordId ?? "")
            } label: {
                DeskRow(title: hit.title, subtitle: hit.subtitle, systemName: "doc.text")
            }
        case .tool:
            NavigationLink {
                WorkspaceToolView(toolId: hit.moduleId)
            } label: {
                DeskRow(title: hit.title, subtitle: "Workspace · \(hit.subtitle)", systemName: "wrench.and.screwdriver")
            }
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
                .listStyle(.insetGrouped)
                .iagCanvas()
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
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "accounting-documents":
                List {
                    if store.accountingDocuments.isEmpty {
                        Text("No accounting documents yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.accountingDocuments, id: \.id) { rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                DeskRow(title: rec.title, subtitle: rec.entity, systemName: "doc.richtext", status: rec.status)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "payment-requests":
                List {
                    if store.pendingApprovals.isEmpty {
                        Text("No open desk requests.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.pendingApprovals, id: \.id) { rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                DeskRow(title: rec.title, subtitle: "\(rec.entity) · \(rec.subtitle)", systemName: "list.clipboard", status: rec.status)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "templates":
                List {
                    ForEach(erpTemplates, id: \.self) { name in
                        Text(name)
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "comms":
                List {
                    ForEach(erpComms, id: \.title) { row in
                        DeskRow(title: row.title, subtitle: row.detail, systemName: "envelope")
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "guides":
                List {
                    ForEach(erpGuides, id: \.title) { row in
                        Section(row.title) { Text(row.body) }
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "qna":
                List {
                    ForEach(erpQnA, id: \.q) { row in
                        Section(row.q) { Text(row.a) }
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "release-notes":
                List {
                    Section("\(appName) \(appVersion)") {
                        Text("Every web ERP desk and feature is on the phone: departments, entity lists, approvals, trace, documents, and workspace tools. RBAC matches web IAG ERP.")
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "activity-logs":
                List {
                    ForEach(store.recent.filter { store.canOpen($0.moduleId) }, id: \.id) { rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            DeskRow(title: rec.title, subtitle: "\(rec.entity) · \(rec.date)", systemName: "clock.arrow.circlepath", status: rec.status)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
            case "system-health":
                List {
                    LabeledContent("App", value: "\(appName) \(appVersion)")
                    LabeledContent("Session", value: store.remoteSession ? "Connected" : "On this device")
                    LabeledContent("Role", value: store.user?.role ?? "—")
                    LabeledContent("Records", value: "\(store.records.count)")
                    LabeledContent("Roles", value: "\(store.roles.count)")
                    LabeledContent("Workspace users", value: "\(store.workspaceUsers.count)")
                    LabeledContent("Theme", value: store.themeMode)
                }
                .listStyle(.insetGrouped)
                .iagCanvas()
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
                .iagCanvas()
            default:
                Text(tool?.description ?? "Unknown tool")
            }
        }
        .navigationTitle(tool?.label ?? "Workspace")
    }
}

func workspaceIcon(_ id: String) -> String {
    switch id {
    case "trace": return "magnifyingglass"
    case "analytics": return "chart.bar"
    case "accounting-documents": return "doc.richtext"
    case "templates": return "doc.on.doc"
    case "payment-requests": return "checkmark.rectangle"
    case "clock-in": return "clock"
    case "guides": return "book"
    case "qna": return "questionmark.circle"
    case "release-notes": return "sparkles"
    case "activity-logs": return "clock.arrow.circlepath"
    case "system-health": return "heart.text.square"
    case "settings": return "gearshape"
    default: return "square.grid.2x2"
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
    ("How do I sign in?", "The black Sign in button uses the live web ERP password (10+ characters). To try the app here, type admin and any password of 6+ characters, then tap Continue on this device."),
]
