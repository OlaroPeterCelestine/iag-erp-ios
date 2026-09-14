import SwiftUI
import ErpCore

struct LoginView: View {
    @EnvironmentObject var box: StoreBox
    @State private var username = ""
    @State private var password = ""
    @State private var departmentId = ""
    @State private var error: String?
    @State private var showReset = false

    var selected: ErpModule? { box.store.moduleById(departmentId) }
    var title: String { selected == nil ? "IAG Finance ERP" : "IAG \(selected!.label)" }
    var subtitle: String {
        selected == nil ? "Inspire Africa Group · All departments" : "Inspire Africa Group · \(selected!.label)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("ERP iOS").font(.largeTitle.bold())
                    Text(title).font(.title3.weight(.semibold))
                    Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Demo: admin, accountant, clerk, viewer, hr, contractor — password iagdemo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Button("Forgot password?") { showReset = true }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Picker("Department", selection: $departmentId) {
                        Text("Finance ERP (all departments)").tag("")
                        ForEach(box.store.modules, id: \.id) { module in
                            Text(module.label).tag(module.id)
                        }
                    }
                    .pickerStyle(.menu)
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Sign in") {
                        error = box.store.login(username, password, departmentId: departmentId.isEmpty ? nil : departmentId)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255))
                }
                .padding(24)
            }
            .sheet(isPresented: $showReset) {
                ResetPasswordView(username: username)
            }
        }
    }
}

struct ResetPasswordView: View {
    @EnvironmentObject var box: StoreBox
    @Environment(\.dismiss) private var dismiss
    @State var username: String
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                SecureField("New password", text: $password)
                SecureField("Confirm", text: $confirm)
                if let error { Text(error).foregroundStyle(.red) }
                if done { Text("Password updated. Sign in with the new password.") }
            }
            .navigationTitle("Reset password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let err = box.store.resetPassword(username: username, newPassword: password, confirm: confirm) {
                            error = err
                            done = false
                        } else {
                            error = nil
                            done = true
                        }
                    }
                }
            }
        }
    }
}
