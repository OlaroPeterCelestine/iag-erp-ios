import SwiftUI
import ErpCore

struct AccessView: View {
    @EnvironmentObject var box: StoreBox
    @State private var tab = 0

    var body: some View {
        let _ = box.tick
        VStack {
            if !box.store.isAdmin {
                Text("Only administrators can manage roles and users.").padding()
            } else {
                Picker("Section", selection: $tab) {
                    Text("Roles").tag(0)
                    Text("Users").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                if tab == 0 { RolesPanel() } else { UsersPanel() }
            }
        }
        .iagCanvas()
        .iagBar("Access", subtitle: "Account")
        .task { await box.store.refreshDirectory() }
    }
}

struct RolesPanel: View {
    @EnvironmentObject var box: StoreBox
    @State private var name = ""
    @State private var description = ""
    @State private var view = true
    @State private var create = false
    @State private var edit = false
    @State private var delete = false
    @State private var restrict = false
    @State private var grants: Set<String> = []
    @State private var error: String?

    var body: some View {
        Form {
            Section("Workspace roles") {
                ForEach(box.store.roles, id: \.id) { role in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(role.name)
                        Text(role.system ? "System" : (role.description.isEmpty ? "Custom" : role.description))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Create custom role") {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                Toggle("View", isOn: $view)
                Toggle("Create", isOn: $create)
                Toggle("Edit", isOn: $edit)
                Toggle("Delete", isOn: $delete)
                Toggle("Restrict to granted apps", isOn: $restrict)
                if restrict {
                    ForEach(box.store.modules, id: \.id) { module in
                        Toggle(module.label, isOn: Binding(
                            get: { grants.contains(module.id) },
                            set: { on in
                                if on { grants.insert(module.id) } else { grants.remove(module.id) }
                            }
                        ))
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Save role") {
                    let crud = Crud(view: view, create: create, edit: edit, delete: delete)
                    var pages: [String: Crud] = [:]
                    if restrict {
                        pages[pageWildcardKey] = Crud.none
                        for id in grants { pages[id] = crud }
                    }
                    error = box.store.saveRole(RoleDefinition(id: newRoleId(), name: name, description: description, crud: crud, pagePermissions: pages))
                    if error == nil {
                        name = ""
                        description = ""
                    }
                }
            }
        }
    }
}

struct UsersPanel: View {
    @EnvironmentObject var box: StoreBox
    @State private var username = ""
    @State private var name = ""
    @State private var role = "Viewer"
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section("Workspace users") {
                if box.store.workspaceUsers.isEmpty {
                    Text("No custom users yet.")
                } else {
                    ForEach(box.store.workspaceUsers, id: \.username) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.name)
                                Text("\(user.username) · \(user.role)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                error = box.store.deleteWorkspaceUser(user.username)
                            }
                        }
                    }
                }
            }
            Section("Add user") {
                TextField("Username", text: $username)
                    .iagTextCase(.never)
                TextField("Name", text: $name)
                TextField("Role", text: $role)
                SecureField("Password", text: $password)
                if let error { Text(error).foregroundStyle(.red) }
                Button("Save user") {
                    error = box.store.saveWorkspaceUser(username: username, name: name, role: role, password: password)
                    if error == nil {
                        username = ""
                        name = ""
                        password = ""
                    }
                }
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var box: StoreBox
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var title = ""
    @State private var message: String?

    var body: some View {
        let user = box.store.user
        let theme = box.store.themeMode == "dark" ? "Dark" : box.store.themeMode == "light" ? "Light" : "System"
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IagAvatar(name: user?.name ?? "I", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.name ?? "Account")
                            .font(.subheadline.weight(.semibold))
                        Text(user?.role ?? "")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IagTheme.leaf)
                        Text(box.store.remoteSession ? "Signed in" : "On this device")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(appVersion)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))

                if let remote = box.store.lastRemoteError, !remote.isEmpty {
                    Text(remote).font(.caption).foregroundStyle(.red)
                }

                PageStats(stats: [
                    ("Role", user?.role ?? "—"),
                    ("Apps", "\(box.store.visibleSuiteApps.count)"),
                    ("Desks", "\(box.store.visibleModules.count)"),
                    ("Clock", box.store.openAttendanceToday() == nil ? "Out" : "In"),
                ])
                SectionHeading(title: "Your details")
                IagGrouped {
                    profileField("Name", text: $name)
                    IagRowDivider(inset: 14)
                    profileField("Email", text: $email)
                    IagRowDivider(inset: 14)
                    profileField("Phone", text: $phone)
                    IagRowDivider(inset: 14)
                    profileField("Title", text: $title)
                }
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        let result = await box.store.updateProfileAsync(name: name, email: email, phone: phone, title: title)
                        await MainActor.run { message = result ?? "Saved." }
                    }
                } label: {
                    Text("Save profile")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(IagTheme.leaf)

                SectionHeading(title: "Workspace")
                NavigationLink {
                    MoreView()
                } label: {
                    DeskRow(title: "Workspace", subtitle: "Desks, requests, people, and admin", systemName: "square.grid.2x2", color: IagTheme.leaf)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(IagTheme.hairline, lineWidth: 0.5)
                )

                SectionHeading(title: "Preferences")
                IagGrouped {
                    Button {
                        let next = box.store.themeMode == "system" ? "light" : box.store.themeMode == "light" ? "dark" : "system"
                        box.store.setThemeMode(next)
                    } label: {
                        IagKeyValue(label: "Theme", value: theme)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    IagRowDivider(inset: 14)
                    Button(role: .destructive) { box.store.logout() } label: {
                        Text("Sign out")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Account", subtitle: appName)
        .onAppear {
            name = user?.name ?? ""
            email = user?.email ?? ""
            phone = user?.phone ?? ""
            title = user?.title ?? ""
        }
    }

    private func profileField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .font(.subheadline)
                .iagTextCase(label == "Email" ? .never : .words)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
