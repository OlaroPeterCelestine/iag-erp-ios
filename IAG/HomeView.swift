import SwiftUI

struct HomeView: View {
    @StateObject private var session = SessionStore()
    @State private var systems: [SystemCatalog] = []
    @State private var loadError: String?

    private var activeSystem: SystemCatalog? {
        let allowed = session.access.allowed(systems)
        return allowed.first { $0.id == session.toolID }
            ?? allowed.first { $0.id == session.access.preferredHomeID }
            ?? allowed.first
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if systems.isEmpty {
                ProgressView("Loading tools")
            } else if session.signedIn, let system = activeSystem {
                ToolShell(system: system, session: session, systems: session.access.allowed(systems))
                    .id(system.id)
                    .environmentObject(session)
            } else {
                LoginView(session: session, systems: systems)
            }
        }
        .task {
            guard systems.isEmpty, loadError == nil else { return }
            switch CatalogLoader.load() {
            case .success(let loaded):
                systems = loaded
                if session.signedIn, !session.access.allows(session.toolID) {
                    session.open(toolID: session.access.homeToolID(in: loaded))
                }
            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
    }
}

struct LoginView: View {
    @ObservedObject var session: SessionStore
    let systems: [SystemCatalog]

    @State private var name: String
    @State private var email: String
    @State private var department: WorkDepartment
    @State private var role: WorkRole
    @State private var toolID: String
    @State private var showTools = false
    @State private var problem: String?

    init(session: SessionStore, systems: [SystemCatalog]) {
        self.session = session
        self.systems = systems
        _name = State(initialValue: session.name)
        _email = State(initialValue: session.email)
        let department = session.department
        let role = session.role
        _department = State(initialValue: department)
        _role = State(initialValue: role)
        let access = ToolAccess(department: department, role: role)
        let stored = session.toolID
        _toolID = State(initialValue: access.allows(stored) ? stored : access.preferredHomeID)
    }

    private var access: ToolAccess {
        ToolAccess(department: department, role: role)
    }

    private var allowed: [SystemCatalog] {
        access.allowed(systems)
    }

    private var chosen: SystemCatalog? {
        allowed.first { $0.id == toolID } ?? allowed.first { $0.id == access.preferredHomeID } ?? allowed.first
    }

    private var canEnter: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@") && email.contains(".")
    }

    var body: some View {
        let tint = SystemTheme.tint(for: chosen?.id ?? "finance")
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACP Hub")
                    .font(.largeTitle.bold())
                Text("Sign in with a department and a role. The department decides which tools open.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Name", prompt: "Your name", text: $name, contentType: .name, email: false)
                    field("Email", prompt: "name@company.com", text: $email, contentType: .emailAddress, email: true)
                    menu("Department", selection: $department)
                    menu("Role", selection: $role)
                    Text(access.opensSentence(in: systems))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let chosen {
                        Button {
                            guard allowed.count > 1 else { return }
                            showTools = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: SystemTheme.symbol(for: chosen.id))
                                    .font(.title3)
                                    .foregroundStyle(tint)
                                    .frame(width: 44, height: 44)
                                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Open")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(chosen.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(chosen.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if allowed.count > 1 {
                                    Text("Change")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(tint)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if let problem {
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Text("This sign-in stays on the phone. It does not check a server. A later sign-in with another department opens only that department’s tools.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            Rectangle()
                .fill(tint)
                .frame(height: 6)
                .ignoresSafeArea(edges: .top)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: enter) {
                Text("Enter \(chosen?.name ?? "tool")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canEnter ? tint : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canEnter || chosen == nil)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .onChange(of: department) { _, _ in alignTool() }
        .onChange(of: role) { _, _ in alignTool() }
        .sheet(isPresented: $showTools) {
            NavigationStack {
                ToolPicker(systems: allowed, selectedID: chosen?.id ?? toolID) { picked in
                    toolID = picked.id
                    showTools = false
                }
            }
        }
    }

    private func menu<T: Hashable & RawRepresentable>(_ title: String, selection: Binding<T>) -> some View where T.RawValue == String, T: CaseIterable, T.AllCases: RandomAccessCollection, T: Identifiable {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(Array(T.allCases)) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func alignTool() {
        if !access.allows(toolID) {
            toolID = access.homeToolID(in: systems)
        }
    }

    private func field(_ title: String, prompt: String, text: Binding<String>, contentType: UITextContentType, email: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(email ? .never : .words)
                .keyboardType(email ? .emailAddress : .default)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func enter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            problem = "Enter your name and a valid email."
            return
        }
        guard let chosen, access.allows(chosen.id) else {
            problem = "This department cannot open that tool."
            return
        }
        problem = nil
        session.signIn(
            name: trimmedName,
            email: trimmedEmail,
            toolID: chosen.id,
            department: department,
            role: role
        )
    }
}

struct ToolPicker: View {
    let systems: [SystemCatalog]
    let selectedID: String
    var onPick: (SystemCatalog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [SystemCatalog] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return systems }
        return systems.filter { system in
            system.name.localizedCaseInsensitiveContains(trimmed)
                || system.summary.localizedCaseInsensitiveContains(trimmed)
                || system.groups.contains { group in
                    group.name.localizedCaseInsensitiveContains(trimmed)
                        || group.forms.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                }
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                ForEach(filtered) { system in
                    Button {
                        onPick(system)
                    } label: {
                        SystemCard(system: system, selected: system.id == selectedID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search tools")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

struct SystemCard: View {
    let system: SystemCatalog
    var selected = false

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: SystemTheme.symbol(for: system.id))
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(system.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(system.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(selected ? 0.9 : 0.28), lineWidth: selected ? 2 : 1)
        }
    }
}
