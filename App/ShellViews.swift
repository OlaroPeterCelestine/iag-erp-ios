import SwiftUI
import MapKit
import ErpCore

private struct ShellTabKey: EnvironmentKey {
    static let defaultValue: Binding<String> = .constant("home")
}

extension EnvironmentValues {
    var shellTab: Binding<String> {
        get { self[ShellTabKey.self] }
        set { self[ShellTabKey.self] = newValue }
    }
}

struct ShellView: View {
    @EnvironmentObject var box: StoreBox
    @State private var tab = "home"

    var body: some View {
        let _ = box.tick
        let specs = shellTabs(appId: box.store.activeAppId, role: box.store.roleName, canApprove: box.store.canApprove, canClockIn: box.store.canClockIn)
        TabView(selection: $tab) {
            ForEach(specs) { spec in
                shellPage(spec)
                    .tabItem { Label(spec.label, systemImage: spec.icon) }
                    .tag(spec.id)
                    .badge(spec.id == "approvals" ? box.store.appPendingApprovals.count : 0)
            }
        }
        .id(box.store.activeAppId ?? "launcher")
        .onChange(of: box.store.activeAppId) { _, _ in
            tab = "home"
        }
        .tint(IagTheme.leaf)
        #if os(iOS)
        .toolbarColorScheme(box.store.themeMode == "dark" ? .dark : box.store.themeMode == "light" ? .light : nil, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(IagTheme.card, for: .tabBar)
        #endif
        .environment(\.shellTab, $tab)
    }

    @ViewBuilder
    private func shellPage(_ spec: ShellTabSpec) -> some View {
        switch spec.id {
        case "home":
            if box.store.activeAppId == nil {
                AppsLauncherView()
            } else {
                HomeView()
            }
        case "desks":
            DepartmentsView()
        case "attendance", "clock", "calendar":
            NavigationStack { AttendanceCalendarView() }
        case "approvals":
            ApprovalsView()
        case "map":
            NavigationStack {
                OperationsMapView(moduleId: spec.moduleId ?? "fleet")
            }
        default:
            NavigationStack {
                if let moduleId = spec.moduleId, let entity = spec.entity {
                    EntityListView(moduleId: moduleId, entity: entity)
                } else if let moduleId = spec.moduleId {
                    DepartmentView(moduleId: moduleId)
                } else {
                    DepartmentsView()
                }
            }
        }
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
    var noticeCount: Int
    var kpis: [Kpi]
    var apps: [SuiteApp]
    var recents: [ErpRecord]
    var pending: [ErpRecord]
    var onOpenApp: (String) -> Void
    var onLeaveApp: (() -> Void)?
    var viewAllTab: String = "desks"
    var toolsTitle: String = "Quick actions"
    var viewAllModule: String? = nil
    var viewAllDesks: Bool = false

    private var frequentApps: [SuiteApp] { apps }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                welcomeCard
                if !actions.isEmpty || !frequentApps.isEmpty || !recents.isEmpty { quickActions }
                if !pending.isEmpty { waiting }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagHideNavigationBar()
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
            if let onLeaveApp {
                Button(action: onLeaveApp) {
                    Image(systemName: "square.grid.2x2")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apps")
            }
            NavigationLink {
                NotificationsList()
            } label: {
                cornerIcon(systemName: "bell", color: IagTheme.orange, badge: noticeCount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            NavigationLink {
                ProfileView()
            } label: {
                cornerIcon(systemName: "person.crop.circle", color: Color(red: 0.05, green: 0.45, blue: 0.72))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
        }
    }

    private func cornerIcon(systemName: String, color: Color, badge: Int = 0) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
            if badge > 0 {
                Text(badge > 9 ? "9+" : "\(badge)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(IagTheme.onLeaf)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(IagTheme.leaf, in: Capsule())
                    .offset(x: 6, y: -4)
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
                    Text(toolsTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if viewAllDesks {
                        NavigationLink {
                            DepartmentsView()
                        } label: {
                            Text("View all")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(IagTheme.leaf)
                        }
                        .buttonStyle(.plain)
                    } else if let module = viewAllModule {
                        NavigationLink {
                            DepartmentView(moduleId: module)
                        } label: {
                            Text("View all")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(IagTheme.leaf)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("View all") { shellTab.wrappedValue = viewAllTab }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IagTheme.leaf)
                            .buttonStyle(.plain)
                    }
                }
            }
            ForEach(toolSections, id: \.title) { section in
                if toolSections.count > 1 {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 12) {
                    ForEach(section.actions) { action in
                        departmentTool(action)
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

    private struct ToolSection: Identifiable {
        var title: String
        var actions: [QuickAction]
        var id: String { title }
    }

    private var toolSections: [ToolSection] {
        var sections: [ToolSection] = []
        for action in actions {
            let title = action.section ?? ""
            if let index = sections.indices.last, sections[index].title == title {
                sections[index].actions.append(action)
            } else {
                sections.append(ToolSection(title: title, actions: [action]))
            }
        }
        return sections
    }

    private func departmentTool(_ action: QuickAction) -> some View {
        QuickActionOpener(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(iagColor(action.color).opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: action.entity.map { featureIcon($0, fallback: action.icon) } ?? action.icon)
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

    private var frequents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(frequentApps.isEmpty ? "Jump back" : "Systems")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if !frequentApps.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                    ForEach(frequentApps) { app in
                        Button {
                            onOpenApp(app.id)
                            shellTab.wrappedValue = "home"
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
                                    .minimumScaleFactor(0.8)
                                    .frame(height: 28)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !recents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
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
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Approvals")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                NavigationLink { ApprovalsList() } label: { Text("Open desk") }
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
                actions: store.departmentTools.isEmpty ? Array(store.homeQuickActions.prefix(8)) : store.departmentTools,
                approvalCount: store.appPendingApprovals.count,
                noticeCount: store.appNotices.count,
                kpis: store.kpis,
                apps: [],
                recents: Array(store.recent.filter { rec in
                    store.canOpen(rec.moduleId) && (store.activeSuiteApp?.moduleIds.contains(rec.moduleId) ?? true)
                }.prefix(6)),
                pending: Array(store.appPendingApprovals.prefix(3)),
                onOpenApp: { store.openApp($0) },
                onLeaveApp: { store.closeApp() },
                viewAllTab: shellTabs(appId: store.activeAppId, role: store.roleName, canApprove: store.canApprove, canClockIn: store.canClockIn).first { !["home", "approvals", "attendance", "clock", "calendar"].contains($0.id) }?.id ?? "desks",
                toolsTitle: store.activeSuiteApp?.label ?? "Quick actions",
                viewAllModule: store.departmentTools.isEmpty || store.appModules.count != 1 ? nil : store.appModules.first?.id,
                viewAllDesks: !store.departmentTools.isEmpty && store.appModules.count > 1
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
            let modules = store.appModules
            let records = store.records.filter { rec in
                guard store.canOpen(rec.moduleId) else { return false }
                if let app = store.activeSuiteApp { return app.moduleIds.contains(rec.moduleId) }
                return true
            }
            let open = records.filter { store.isOpenStatus($0.status) }.count
            let value = records.compactMap(\.amount).reduce(0, +)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageStats(stats: [
                        ("Desks", "\(modules.count)"),
                        ("Features", "\(modules.reduce(0) { $0 + $1.entities.count })"),
                        ("Open", "\(open)"),
                        ("Value", value == 0 ? "—" : compactMoney(value)),
                    ])
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
                        SectionHeading(title: group, detail: "\(modules.count)")
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

struct NotificationsList: View {
    @EnvironmentObject var box: StoreBox

    var body: some View {
        let _ = box.tick
        let notes = box.store.activeAppId == nil ? box.store.notices : box.store.appNotices
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageStats(stats: [
                    ("Updates", "\(notes.count)"),
                    ("Approved", "\(notes.filter { $0.status.lowercased().contains("approv") }.count)"),
                    ("Rejected", "\(notes.filter { $0.status.lowercased().contains("reject") }.count)"),
                    ("Posted", "\(notes.filter { rec in ["posted", "cleared", "paid"].contains { rec.status.lowercased().contains($0) } }.count)"),
                ])
                SectionHeading(title: "Updates", detail: notes.isEmpty ? "Quiet" : "Decisions and posted results")
                if notes.isEmpty {
                    IagEmptyHint(text: "No decisions or posted results yet.", systemName: "bell.slash")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    IagGrouped {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(statusColor(rec.status).opacity(0.12))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Image(systemName: noticeIcon(rec.status))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(statusColor(rec.status))
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rec.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("\(rec.entity) · \(rec.status)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            if index < notes.count - 1 { IagRowDivider() }
                        }
                    }
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Notifications", subtitle: "Decisions and posted results")
    }
}

private func noticeIcon(_ status: String) -> String {
    let s = status.lowercased()
    if s.contains("reject") || s.contains("void") { return "xmark" }
    if s.contains("return") { return "arrow.uturn.backward" }
    if s.contains("paid") || s.contains("posted") || s.contains("cleared") { return "doc.text" }
    return "bell"
}

struct OperationsMapView: View {
    @EnvironmentObject var box: StoreBox
    var moduleId: String
    @State private var selected: String?

    private var isFleet: Bool { moduleId == "fleet" }

    var body: some View {
        let _ = box.tick
        let pins = isFleet ? fleetMapPins(box.store.records) : distributionMapPins(box.store.records)
        let tint = isFleet ? IagTheme.orange : IagTheme.success
        VStack(spacing: 0) {
            PinMap(pins: pins, systemImage: isFleet ? "car.fill" : "box.truck.fill", tint: tint, selected: $selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if pins.isEmpty {
                        IagEmptyHint(text: isFleet ? "No vehicles are reporting a position." : "No delivery stops have a position yet.", systemName: "mappin.slash")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        IagGrouped {
                            ForEach(Array(pins.enumerated()), id: \.element.id) { index, pin in
                                NavigationLink {
                                    RecordDetailView(recordId: pin.id)
                                } label: {
                                    DeskRow(title: pin.title, subtitle: pin.subtitle, systemName: isFleet ? "car.fill" : "box.truck.fill", color: tint, status: pin.status)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if index < pins.count - 1 { IagRowDivider() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 280)
            .background(IagTheme.canvas)
        }
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar(isFleet ? "Fleet map" : "Distribution map", subtitle: isFleet ? "Vehicles" : "Delivery stops")
    }
}

struct PinMap: View {
    var pins: [PlacePin]
    var systemImage: String
    var tint: Color
    var selected: Binding<String?> = .constant(nil)
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position, selection: selected) {
            ForEach(pins) { pin in
                Marker(pin.title, systemImage: systemImage, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                    .tint(tint)
                    .tag(pin.id)
            }
        }
        .mapStyle(.standard)
        .onAppear { position = .region(mapRegion(pins)) }
        .onChange(of: selected.wrappedValue) { _, id in
            guard let id, let pin = pins.first(where: { $0.id == id }) else { return }
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ))
        }
    }
}

private func mapRegion(_ pins: [PlacePin]) -> MKCoordinateRegion {
    guard let first = pins.first else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: hqLatitude, longitude: hqLongitude),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }
    let lats = pins.map(\.latitude)
    let lngs = pins.map(\.longitude)
    let minLat = lats.min() ?? first.latitude
    let maxLat = lats.max() ?? first.latitude
    let minLng = lngs.min() ?? first.longitude
    let maxLng = lngs.max() ?? first.longitude
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
        span: MKCoordinateSpan(
            latitudeDelta: max(0.12, (maxLat - minLat) * 1.8),
            longitudeDelta: max(0.12, (maxLng - minLng) * 1.8)
        )
    )
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
        let waiting = box.store.appPendingApprovals
        let value = waiting.compactMap(\.amount).reduce(0, +)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageStats(stats: [
                    ("Waiting", "\(waiting.count)"),
                    ("Desks", "\(Set(waiting.map(\.moduleId)).count)"),
                    ("Types", "\(Set(waiting.map(\.entity)).count)"),
                    ("Value", value == 0 ? "—" : compactMoney(value)),
                ])
                SectionHeading(title: "Queue", detail: waiting.isEmpty ? "Clear" : "\(waiting.count) open")
                if waiting.isEmpty {
                    IagEmptyHint(text: "Nothing is waiting for your desk.", systemName: "checkmark.circle")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    IagGrouped {
                        ForEach(Array(waiting.enumerated()), id: \.element.id) { index, rec in
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
                            if index < waiting.count - 1 { IagRowDivider() }
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
    let action: QuickAction
    @ViewBuilder var label: () -> Label

    var body: some View {
        switch action.kind {
        case .clock:
            NavigationLink { ClockInView() } label: { label() }
                .buttonStyle(.plain)
        case .approvals:
            NavigationLink { ApprovalsList() } label: { label() }
                .buttonStyle(.plain)
        case .map:
            NavigationLink { OperationsMapView(moduleId: action.moduleId) } label: { label() }
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
        case .map:
            OperationsMapView(moduleId: action.moduleId)
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

                    PageStats(stats: store.welcomeStats.map { (label: $0.label, value: $0.value) })

                    if store.activeAppId != nil {
                        SectionHeading(title: "This app", detail: store.activeSuiteApp?.label)
                        IagGrouped {
                            Button {
                                store.closeApp()
                                shellTab.wrappedValue = "home"
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
                            SectionHeading(title: group, detail: "\(tools.count + (showAccess ? 1 : 0))")
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
            .iagBar("Workspace", subtitle: role)
        }
    }
}

struct AppsLauncherView: View {
    @EnvironmentObject var box: StoreBox

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
                noticeCount: store.notices.count,
                kpis: store.kpis,
                apps: store.visibleSuiteApps,
                recents: [],
                pending: Array(store.pendingApprovals.prefix(3)),
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
                DeskRow(title: hit.title, subtitle: "Feature · \(hit.subtitle)", systemName: featureIcon(hit.title, fallback: box.store.moduleById(hit.moduleId)?.icon ?? "square.grid.2x2"))
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
        let open = records.filter { $0.status.lowercased().contains("pending") || $0.status.lowercased().contains("open") || $0.status.lowercased().contains("submitted") }.count
        let value = records.compactMap(\.amount).reduce(0, +)
        ToolCanvas {
            PageStats(stats: [
                ("Records", "\(records.count)"),
                ("Open", "\(open)"),
                ("Types", "\(Set(records.map(\.entity)).count)"),
                ("Value", value == 0 ? "—" : compactMoney(value)),
            ])
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
                let visibleRecords = store.records.filter { store.canOpen($0.moduleId) }
                let analyticsValue = visibleRecords.compactMap(\.amount).reduce(0, +)
                ToolCanvas {
                    PageStats(stats: [
                        ("Desks", "\(store.visibleModules.count)"),
                        ("Features", "\(store.visibleModules.reduce(0) { $0 + $1.entities.count })"),
                        ("Records", "\(visibleRecords.count)"),
                        ("Value", analyticsValue == 0 ? "—" : compactMoney(analyticsValue)),
                    ])
                    ForEach(departmentGroups, id: \.self) { group in
                        let modules = store.visibleModules.filter { $0.group == group }
                        if !modules.isEmpty {
                            SectionHeading(title: group, detail: "\(modules.reduce(0) { $0 + store.forModule($1.id).count }) records")
                            IagGrouped {
                                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                                    IagKeyValue(label: module.label, value: "\(store.forModule(module.id).count)")
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                    if index < modules.count - 1 { IagRowDivider(inset: 14) }
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
                            if index < erpTemplates.count - 1 { IagRowDivider(inset: 14) }
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
                    PageStats(stats: [
                        ("Records", "\(store.records.count)"),
                        ("Roles", "\(store.roles.count)"),
                        ("Users", "\(store.workspaceUsers.count)"),
                        ("Session", store.remoteSession ? "Live" : "Device"),
                    ])
                    SectionHeading(title: "This install", detail: appVersion)
                    IagGrouped {
                        let rows: [(String, String)] = [
                            ("App", appName),
                            ("Session", store.remoteSession ? "Connected" : "On this device"),
                            ("Role", store.user?.role ?? "—"),
                            ("Theme", store.themeMode.capitalized),
                        ]
                        ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                            IagKeyValue(label: row.0, value: row.1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            if index < rows.count - 1 { IagRowDivider(inset: 14) }
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
        .iagBar(tool?.label ?? "Workspace", subtitle: "Workspace")
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
    if !module.description.isEmpty { return module.description }
    return module.entities.count == 1 ? "1 feature" : "\(module.entities.count) features"
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
