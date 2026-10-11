import SwiftUI
import ErpCore

enum ShellTab: Int, Hashable {
    case home = 0
    case desks = 1
    case clock = 2
    case approvals = 3
    case more = 4
}

private struct ShellTabKey: EnvironmentKey {
    static let defaultValue: Binding<ShellTab> = .constant(.home)
}

extension EnvironmentValues {
    var shellTab: Binding<ShellTab> {
        get { self[ShellTabKey.self] }
        set { self[ShellTabKey.self] = newValue }
    }
}

struct ShellView: View {
    @EnvironmentObject var box: StoreBox
    @State private var tab = ShellTab.home

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
            .tag(ShellTab.home)
            DepartmentsView()
                .tabItem { Label("Desks", systemImage: "building.2") }
                .tag(ShellTab.desks)
            NavigationStack {
                ClockInView()
            }
            .tabItem { Label("Clock", systemImage: "clock") }
            .tag(ShellTab.clock)
            if box.store.canApprove {
                ApprovalsView()
                    .tabItem { Label("Approvals", systemImage: "checkmark.rectangle") }
                    .tag(ShellTab.approvals)
                    .badge(box.store.appPendingApprovals.count)
            }
            MoreView()
                .tabItem { Label("More", systemImage: "square.grid.2x2") }
                .tag(ShellTab.more)
        }
        .tint(IagTheme.leaf)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(IagTheme.card, for: .tabBar)
        .environment(\.shellTab, $tab)
    }
}

struct FinHome: View {
    @Environment(\.shellTab) private var shellTab
    var name: String
    var detail: String
    var actions: [QuickAction]
    var approvalCount: Int
    var canOpenApprovals: Bool
    var kpis: [Kpi]
    var apps: [SuiteApp]
    var recents: [ErpRecord]
    var pending: [ErpRecord]
    var hits: [SearchHit]
    @Binding var query: String
    var onOpenApp: (String) -> Void
    var onLeaveApp: (() -> Void)?

    @State private var searching = false

    private var frequentApps: [SuiteApp] { Array(apps.prefix(8)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if searching {
                    searchField
                }
                if searching && query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    searchResults
                } else if !searching {
                    walletRow
                    if !actions.isEmpty { quickActions }
                    if !frequentApps.isEmpty || !recents.isEmpty { frequents }
                    if !pending.isEmpty { waiting }
                    explore
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            IagAvatar(name: name, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(iagGreeting())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                if let onLeaveApp {
                    Button(action: onLeaveApp) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apps")
                }
                Button {
                    searching.toggle()
                    if !searching { query = "" }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
                Button {
                    guard canOpenApprovals else { return }
                    shellTab.wrappedValue = .approvals
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundStyle(.primary)
                        if approvalCount > 0 {
                            Text(approvalCount > 9 ? "9+" : "\(approvalCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(IagTheme.leaf, in: Capsule())
                                .offset(x: 8, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Approvals")
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Account")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search desks and records", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .finShadow()
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.title3.weight(.bold))
            if hits.isEmpty {
                Text("No matches in desks, features, or records.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .finShadow()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                        SearchHitRow(hit: hit)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        if index < hits.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .finShadow()
            }
        }
    }

    private var walletRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if kpis.isEmpty {
                    statCard(label: detail, value: "\(approvalCount)", hint: "Waiting", showsButton: true)
                        .frame(width: 300)
                } else {
                    ForEach(Array(kpis.prefix(3).enumerated()), id: \.offset) { index, kpi in
                        statCard(label: kpi.label, value: kpi.value, hint: kpi.hint, showsButton: index == 0)
                            .frame(width: 300)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func statCard(label: String, value: String, hint: String, showsButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            if showsButton {
                Button {
                    shellTab.wrappedValue = approvalCount > 0 ? .approvals : .desks
                } label: {
                    Text(approvalCount > 0 ? "View approvals" : "View desks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(IagTheme.leaf)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(IagTheme.leaf.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .finShadow()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick actions")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("View all") { shellTab.wrappedValue = .desks }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IagTheme.leaf)
                    .buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 18) {
                ForEach(actions) { action in
                    QuickActionOpener(action: action) {
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(IagTheme.leaf.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Image(systemName: action.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(IagTheme.leaf)
                                    }
                                if action.kind == .approvals && approvalCount > 0 {
                                    Circle()
                                        .fill(IagTheme.leaf)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                            Text(action.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(height: 32, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .finShadow()
    }

    private var frequents: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(frequentApps.isEmpty ? "Jump back" : "Your apps")
                .font(.title3.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(frequentApps) { app in
                        Button {
                            onOpenApp(app.id)
                            shellTab.wrappedValue = .desks
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(iagColor(app.color).opacity(0.14))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: app.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(iagColor(app.color))
                                }
                                Text(app.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(recents, id: \.id) { rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(statusColor(rec.status).opacity(0.14))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(statusColor(rec.status))
                                }
                                Text(rec.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Waiting for you")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("View all") { shellTab.wrappedValue = .approvals }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IagTheme.leaf)
                    .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                ForEach(Array(pending.enumerated()), id: \.element.id) { index, rec in
                    NavigationLink {
                        RecordDetailView(recordId: rec.id)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(IagTheme.leaf.opacity(0.12))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(IagTheme.leaf)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(rec.entity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(text: rec.status)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < pending.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .finShadow()
        }
    }

    private var explore: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore desks")
                .font(.title3.weight(.bold))
            Button {
                shellTab.wrappedValue = .desks
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(detail)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Banking, sales, people, fleet, and the rest of \(appName), on this phone.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Open desks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(IagTheme.leaf)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(IagTheme.leaf, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private extension View {
    func finShadow() -> some View {
        shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }
}

struct HomeView: View {
    @EnvironmentObject var box: StoreBox
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let first = store.user?.name.split(separator: " ").first.map(String.init) ?? "there"
        NavigationStack {
            FinHome(
                name: first,
                detail: store.activeSuiteApp?.label ?? store.user?.role ?? appName,
                actions: Array(store.homeQuickActions.prefix(8)),
                approvalCount: store.appPendingApprovals.count,
                canOpenApprovals: store.canApprove,
                kpis: store.kpis,
                apps: [],
                recents: Array(store.recent.filter { store.canOpen($0.moduleId) }.prefix(6)),
                pending: Array(store.appPendingApprovals.prefix(3)),
                hits: store.searchHits(query),
                query: $query,
                onOpenApp: { store.openApp($0) },
                onLeaveApp: { store.closeApp() }
            )
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let groups = departmentGroups.filter { group in
                        store.appModules.contains { module in
                            module.group == group && (q.isEmpty || module.label.lowercased().contains(q) || module.entities.contains { $0.lowercased().contains(q) })
                        }
                    }
                    if groups.isEmpty {
                        IagEmptyHint(text: "No desks match.", systemName: "building.2")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    ForEach(groups, id: \.self) { group in
                        let modules = store.appModules.filter { module in
                            guard module.group == group else { return false }
                            if q.isEmpty { return true }
                            return module.label.lowercased().contains(q)
                                || module.entities.contains { $0.lowercased().contains(q) }
                        }
                        Text(group).font(.title3.weight(.bold))
                        IagGrouped {
                            ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                                NavigationLink {
                                    DepartmentView(moduleId: module.id)
                                } label: {
                                    DeskRow(
                                        title: module.label,
                                        subtitle: featureSummary(module),
                                        systemName: module.icon,
                                        color: iagColor(module.color)
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    store.setActiveDepartment(module.id)
                                })
                                if index < modules.count - 1 { IagRowDivider() }
                            }
                        }
                    }
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar(
                box.store.activeSuiteApp?.label ?? "Desks",
                subtitle: box.store.activeSuiteApp == nil ? "All desks" : "Desks"
            )
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Waiting for you")
                    .font(.title3.weight(.bold))
                if box.store.appPendingApprovals.isEmpty {
                    IagEmptyHint(text: "Nothing is waiting for your desk.", systemName: "checkmark.circle")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    IagGrouped {
                        ForEach(Array(box.store.appPendingApprovals.enumerated()), id: \.element.id) { index, rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                DeskRow(
                                    title: rec.title,
                                    subtitle: "\(rec.entity) · \(rec.subtitle)",
                                    systemName: "checkmark",
                                    color: IagTheme.leaf,
                                    status: rec.status
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            if index < box.store.appPendingApprovals.count - 1 { IagRowDivider() }
                        }
                    }
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Approvals", subtitle: box.store.activeSuiteApp?.label ?? appName)
        .task {
            await box.store.refreshApprovals()
        }
    }
}

struct QuickActionOpener<Label: View>: View {
    @Environment(\.shellTab) private var shellTab
    let action: QuickAction
    @ViewBuilder var label: () -> Label

    var body: some View {
        switch action.kind {
        case .clock:
            Button { shellTab.wrappedValue = .clock } label: { label() }
                .buttonStyle(.plain)
        case .approvals:
            Button { shellTab.wrappedValue = .approvals } label: { label() }
                .buttonStyle(.plain)
        default:
            NavigationLink { QuickActionDestination(action: action) } label: { label() }
                .buttonStyle(.plain)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.activeAppId != nil {
                        Text("Apps").font(.title3.weight(.bold))
                        IagGrouped {
                            Button {
                                store.closeApp()
                            } label: {
                                DeskRow(
                                    title: "Switch app",
                                    subtitle: store.activeSuiteApp.map { "You are in \($0.label)." } ?? "Open another tool.",
                                    systemName: "square.grid.2x2",
                                    color: IagTheme.leaf
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ForEach(workspaceGroups, id: \.self) { group in
                        let tools = store.visibleWorkspaceTools.filter { $0.group == group }
                        if !tools.isEmpty {
                            Text(group).font(.title3.weight(.bold))
                            IagGrouped {
                                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                                    NavigationLink {
                                        WorkspaceToolView(toolId: tool.id)
                                    } label: {
                                        DeskRow(
                                            title: tool.label,
                                            subtitle: tool.description,
                                            systemName: workspaceIcon(tool.id),
                                            color: IagTheme.leaf
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    if index < tools.count - 1 { IagRowDivider() }
                                }
                            }
                        }
                    }
                    Text("Account").font(.title3.weight(.bold))
                    IagGrouped {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            DeskRow(title: "Profile", subtitle: "Name, theme, and sign out", systemName: "person.crop.circle", color: IagTheme.leaf)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if store.isAdmin {
                            IagRowDivider()
                            NavigationLink {
                                AccessView()
                            } label: {
                                DeskRow(title: "Users & roles", subtitle: "Custom roles and workspace users", systemName: "shield", color: IagTheme.leaf)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar("More", subtitle: appName)
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
        NavigationStack {
            FinHome(
                name: first,
                detail: store.user?.role ?? appName,
                actions: Array(store.launcherQuickActions.prefix(8)),
                approvalCount: store.pendingApprovals.count,
                canOpenApprovals: store.canApprove,
                kpis: store.kpis,
                apps: store.visibleSuiteApps,
                recents: [],
                pending: Array(store.pendingApprovals.prefix(3)),
                hits: store.searchHits(query),
                query: $query,
                onOpenApp: { store.openApp($0) },
                onLeaveApp: nil
            )
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
        .iagBar(tool?.label ?? "Workspace", subtitle: "More")
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
