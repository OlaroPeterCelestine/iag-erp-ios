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
        .toolbarColorScheme(box.store.themeMode == "dark" ? .dark : box.store.themeMode == "light" ? .light : nil, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(IagTheme.card, for: .tabBar)
        .environment(\.shellTab, $tab)
    }
}

struct FinHome: View {
    @Environment(\.shellTab) private var shellTab
    var name: String
    var fullName: String
    var detail: String
    var stats: [WelcomeStat]
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
            VStack(alignment: .leading, spacing: 16) {
                header
                if searching {
                    searchField
                }
                if searching && query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    searchResults
                } else if !searching {
                    welcomeCard
                    if !actions.isEmpty || !frequentApps.isEmpty || !recents.isEmpty { quickActions }
                    if !pending.isEmpty { waiting }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            IagAvatar(name: name, size: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(iagGreeting())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 16) {
                if let onLeaveApp {
                    Button(action: onLeaveApp) {
                        Image(systemName: "square.grid.2x2")
                            .font(.body.weight(.medium))
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
                        .font(.body.weight(.medium))
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
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if approvalCount > 0 {
                            Text(approvalCount > 9 ? "9+" : "\(approvalCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(IagTheme.onLeaf)
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
                        .font(.body.weight(.medium))
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
                .font(.subheadline.weight(.semibold))
            if hits.isEmpty {
                Text("No matches in desks, features, or records.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .finShadow()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                        SearchHitRow(hit: hit)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        if index < hits.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .finShadow()
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome")
                    .font(.caption.weight(.medium))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                Text(fullName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.value)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text(stat.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < stats.count - 1 {
                            Rectangle()
                                .fill(IagTheme.hairline)
                                .frame(width: 0.5, height: 22)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
            if !kpis.isEmpty {
                Rectangle().fill(IagTheme.hairline).frame(height: 0.5)
                Text("Stats report")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 10) {
                    ForEach(Array(kpis.enumerated()), id: \.offset) { _, kpi in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kpi.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(kpi.value)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 0.5)
        )
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !actions.isEmpty {
                HStack {
                    Text("Quick actions")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("View all") { shellTab.wrappedValue = .desks }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(IagTheme.leaf)
                        .buttonStyle(.plain)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 12) {
                ForEach(actions) { action in
                    QuickActionOpener(action: action) {
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(iagColor(action.color).opacity(0.12))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: action.icon)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(iagColor(action.color))
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                if action.kind == .approvals && approvalCount > 0 {
                                    Circle()
                                        .fill(IagTheme.leaf)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                            Text(action.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(height: 26, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            if !frequentApps.isEmpty || !recents.isEmpty {
                if !actions.isEmpty {
                    Rectangle()
                        .fill(IagTheme.hairline)
                        .frame(height: 0.5)
                }
                frequents
            }
        }
        .padding(12)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 0.5)
        )
    }

    private var frequents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(frequentApps.isEmpty ? "Jump back" : "Your apps")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(frequentApps) { app in
                        Button {
                            onOpenApp(app.id)
                            shellTab.wrappedValue = .desks
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(iagColor(app.color).opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: app.icon)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(iagColor(app.color))
                                }
                                Text(app.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 64)
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
                                        .fill(statusColor(rec.status).opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(statusColor(rec.status))
                                }
                                Text(rec.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 64)
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
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("View all") { shellTab.wrappedValue = .approvals }
                    .font(.caption.weight(.medium))
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if index < pending.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(IagTheme.hairline, lineWidth: 0.5)
            )
        }
    }

}

private extension View {
    func finShadow() -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 0.5)
        )
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
                fullName: store.user?.name ?? first,
                detail: store.activeSuiteApp?.label ?? store.user?.role ?? appName,
                stats: store.welcomeStats,
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
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    ForEach(groups, id: \.self) { group in
                        let modules = store.appModules.filter { module in
                            guard module.group == group else { return false }
                            if q.isEmpty { return true }
                            return module.label.lowercased().contains(q)
                                || module.entities.contains { $0.lowercased().contains(q) }
                        }
                        Text(group).font(.subheadline.weight(.semibold))
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
                                    .padding(.vertical, 8)
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
                    .font(.subheadline.weight(.semibold))
                if box.store.appPendingApprovals.isEmpty {
                    IagEmptyHint(text: "Nothing is waiting for your desk.", systemName: "checkmark.circle")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    IagGrouped {
                        ForEach(Array(box.store.appPendingApprovals.enumerated()), id: \.element.id) { index, rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                DeskRow(
                                    title: rec.title,
                                    subtitle: "\(rec.entity) · \(rec.subtitle)",
                                    systemName: entityIcon(rec.entity),
                                    color: statusColor(rec.status),
                                    status: rec.status
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
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
    @Environment(\.shellTab) private var shellTab

    var body: some View {
        let store = box.store
        let _ = box.tick
        let name = store.user?.name ?? "Account"
        let role = store.user?.role ?? appName
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        HStack(spacing: 12) {
                            IagAvatar(name: name, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(IagTheme.hairline, lineWidth: 0.5)
                    )

                    if store.activeAppId != nil {
                        Text("This app").font(.subheadline.weight(.semibold))
                        IagGrouped {
                            Button {
                                store.closeApp()
                                shellTab.wrappedValue = .home
                            } label: {
                                DeskRow(
                                    title: "Switch app",
                                    subtitle: store.activeSuiteApp.map { "You are in \($0.label)." } ?? "Open another tool.",
                                    systemName: "square.grid.2x2",
                                    color: IagTheme.leaf
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(workspaceGroups, id: \.self) { group in
                        let tools = store.visibleWorkspaceTools.filter { $0.group == group }
                        let showAccess = group == "Admin" && store.isAdmin
                        if !tools.isEmpty || showAccess {
                            Text(group).font(.subheadline.weight(.semibold))
                            IagGrouped {
                                if showAccess {
                                    NavigationLink {
                                        AccessView()
                                    } label: {
                                        DeskRow(
                                            title: "Users & roles",
                                            subtitle: "Custom roles and workspace users",
                                            systemName: "shield",
                                            color: IagTheme.leaf
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    if !tools.isEmpty { IagRowDivider() }
                                }
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
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    if index < tools.count - 1 { IagRowDivider() }
                                }
                            }
                        }
                    }
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar("More", subtitle: role)
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
                fullName: store.user?.name ?? first,
                detail: store.user?.role ?? appName,
                stats: store.welcomeStats,
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
                DeskRow(title: hit.title, subtitle: "Desk · \(hit.subtitle)", systemName: "building.columns")
            }
        case .entity:
            NavigationLink {
                EntityListView(moduleId: hit.moduleId, entity: hit.entity ?? "")
            } label: {
                DeskRow(title: hit.title, subtitle: "Feature · \(hit.subtitle)", systemName: entityIcon(hit.title))
            }
        case .record:
            NavigationLink {
                RecordDetailView(recordId: hit.recordId ?? "")
            } label: {
                DeskRow(title: hit.title, subtitle: hit.subtitle, systemName: entityIcon(hit.subtitle))
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

private struct ToolCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
    }
}

private struct RecordToolList: View {
    var records: [ErpRecord]
    var empty: String
    var icon: String
    var subtitle: (ErpRecord) -> String = { $0.entity }

    var body: some View {
        ToolCanvas {
            if records.isEmpty {
                IagEmptyHint(text: empty, systemName: icon)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                IagGrouped {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            DeskRow(title: rec.title, subtitle: subtitle(rec), systemName: icon, status: rec.status)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if index < records.count - 1 { IagRowDivider() }
                    }
                }
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
                ToolCanvas {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                        IagEmptyHint(text: "Type at least two characters.", systemName: "magnifyingglass")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        let hits = store.searchHits(query)
                        if hits.isEmpty {
                            IagEmptyHint(text: "Nothing matched.", systemName: "magnifyingglass")
                                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            IagGrouped {
                                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                                    SearchHitRow(hit: hit)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                    if index < hits.count - 1 { IagRowDivider() }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $query, prompt: "IAG-LOT, SI-2026, UAX 221K…")
            case "analytics":
                ToolCanvas {
                    IagGrouped {
                        IagKeyValue(label: "Departments", value: "\(store.visibleModules.count)")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        IagRowDivider()
                        IagKeyValue(label: "Features", value: "\(store.visibleModules.reduce(0) { $0 + $1.entities.count })")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        IagRowDivider()
                        IagKeyValue(label: "Records", value: "\(store.records.filter { store.canOpen($0.moduleId) }.count)")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        IagRowDivider()
                        IagKeyValue(label: "Pending approvals", value: "\(store.pendingApprovals.count)")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    ForEach(departmentGroups, id: \.self) { group in
                        let modules = store.visibleModules.filter { $0.group == group }
                        if !modules.isEmpty {
                            Text(group).font(.subheadline.weight(.semibold))
                            IagGrouped {
                                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                                    IagKeyValue(label: module.label, value: "\(store.forModule(module.id).count)")
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                    if index < modules.count - 1 { IagRowDivider() }
                                }
                            }
                        }
                    }
                }
            case "accounting-documents":
                RecordToolList(records: store.accountingDocuments, empty: "No accounting documents yet.", icon: "doc.richtext")
            case "payment-requests":
                RecordToolList(
                    records: store.pendingApprovals,
                    empty: "No open desk requests.",
                    icon: "list.clipboard",
                    subtitle: { "\($0.entity) · \($0.subtitle)" }
                )
            case "templates":
                ToolCanvas {
                    IagGrouped {
                        ForEach(Array(erpTemplates.enumerated()), id: \.element) { index, name in
                            Text(name)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            if index < erpTemplates.count - 1 { IagRowDivider() }
                        }
                    }
                }
            case "comms":
                ToolCanvas {
                    IagGrouped {
                        ForEach(Array(erpComms.enumerated()), id: \.element.title) { index, row in
                            DeskRow(title: row.title, subtitle: row.detail, systemName: "envelope")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            if index < erpComms.count - 1 { IagRowDivider() }
                        }
                    }
                }
            case "guides":
                ToolCanvas {
                    ForEach(erpGuides, id: \.title) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.title).font(.subheadline.weight(.semibold))
                            Text(row.body).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
                    }
                }
            case "qna":
                ToolCanvas {
                    ForEach(erpQnA, id: \.q) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.q).font(.subheadline.weight(.semibold))
                            Text(row.a).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
                    }
                }
            case "release-notes":
                ToolCanvas {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(appName) \(appVersion)").font(.subheadline.weight(.semibold))
                        Text("Every desk, approval, and record from the web ERP is on this phone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
                }
            case "activity-logs":
                RecordToolList(
                    records: store.recent.filter { store.canOpen($0.moduleId) },
                    empty: "No recent activity.",
                    icon: "clock.arrow.circlepath",
                    subtitle: { "\($0.entity) · \($0.date)" }
                )
            case "system-health":
                ToolCanvas {
                    IagGrouped {
                        let rows: [(String, String)] = [
                            ("App", "\(appName) \(appVersion)"),
                            ("Session", store.remoteSession ? "Connected" : "On this device"),
                            ("Role", store.user?.role ?? "—"),
                            ("Records", "\(store.records.count)"),
                            ("Roles", "\(store.roles.count)"),
                            ("Workspace users", "\(store.workspaceUsers.count)"),
                            ("Theme", store.themeMode),
                        ]
                        ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                            IagKeyValue(label: row.0, value: row.1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            if index < rows.count - 1 { IagRowDivider() }
                        }
                    }
                }
            case "settings":
                ToolCanvas {
                    IagGrouped {
                        Picker("Theme", selection: Binding(
                            get: { store.themeMode },
                            set: { store.setThemeMode($0) }
                        )) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .padding(14)
                        IagRowDivider()
                        IagKeyValue(label: "Desks on this device", value: "\(store.visibleModules.count)")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                }
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
