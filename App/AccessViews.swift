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
        .navigationTitle("Access")
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
            Section("Custom roles") {
                if box.store.customRoles.isEmpty {
                    Text("No custom roles yet.")
                } else {
                    ForEach(box.store.customRoles, id: \.id) { role in
                        Text("\(role.name) — \(role.description.isEmpty ? "custom" : role.description)")
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
    @State private var password = "iagdemo"
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
                Text(user?.role ?? "").fontWeight(.bold)
                Text("ERP iOS \(appVersion)").foregroundStyle(.secondary)
            }
            TextField("Name", text: $name)
            TextField("Email", text: $email)
            TextField("Phone", text: $phone)
            TextField("Title", text: $title)
            if let message { Text(message) }
            Button("Save profile") {
                message = box.store.updateProfile(name: name, email: email, phone: phone, title: title) ?? "Saved."
            }
            Button(box.store.themeMode == "dark" ? "Use light theme" : "Use dark theme") {
                box.store.setThemeMode(box.store.themeMode == "dark" ? "light" : "dark")
            }
            Button("Sign out", role: .destructive) { box.store.logout() }
        }
        .navigationTitle("Account")
        .onAppear {
            name = user?.name ?? ""
            email = user?.email ?? ""
            phone = user?.phone ?? ""
            title = user?.title ?? ""
        }
    }
}
