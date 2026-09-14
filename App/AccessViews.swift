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
        .navigationTitle("Access")
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
                        pages[pageWildcardKey] = .none
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
                    .textInputAutocapitalization(.never)
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
        Form {
            Section {
                Text(user?.role ?? "").fontWeight(.semibold)
                Text("\(appName) \(appVersion)").foregroundStyle(.secondary)
                if box.store.remoteSession {
                    Text("Signed in.").foregroundStyle(.secondary)
                } else {
                    Text("On this device.").foregroundStyle(.secondary)
                }
                if let remote = box.store.lastRemoteError, !remote.isEmpty {
                    Text(remote).foregroundStyle(.red)
                }
            }
            Section("Profile") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                TextField("Phone", text: $phone)
                TextField("Title", text: $title)
                if let message { Text(message) }
                Button("Save profile") {
                    Task {
                        let result = await box.store.updateProfileAsync(name: name, email: email, phone: phone, title: title)
                        await MainActor.run { message = result ?? "Saved." }
                    }
                }
            }
            Section {
                Button("Theme: \(box.store.themeMode == "dark" ? "Dark" : box.store.themeMode == "light" ? "Light" : "System")") {
                    let next = box.store.themeMode == "system" ? "light" : box.store.themeMode == "light" ? "dark" : "system"
                    box.store.setThemeMode(next)
                }
                Button("Sign out", role: .destructive) { box.store.logout() }
            }
        }
        .iagCanvas()
        .navigationTitle("Account")
        .onAppear {
            name = user?.name ?? ""
            email = user?.email ?? ""
            phone = user?.phone ?? ""
            title = user?.title ?? ""
        }
    }
}
