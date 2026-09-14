import SwiftUI
import ErpCore

struct LoginView: View {
    @EnvironmentObject var box: StoreBox
    @State private var username = ""
    @State private var password = ""
    @State private var departmentId = ""
    @State private var error: String?
    @State private var showReset = false

    var selected: SuiteApp? { suiteAppById(departmentId) }
    var title: String { selected == nil ? "IAG ERP" : "IAG \(selected!.label)" }
    var subtitle: String {
        selected == nil ? "Sign in to open Finance, Procurement, Production, Security, or another app." : selected!.description
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        IagMark(size: 52)
                        Text(title)
                            .font(.title.weight(.semibold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .iagCard()
                        SecureField("Password", text: $password)
                            .padding(14)
                            .iagCard()
                        Button("Forgot password?") { showReset = true }
                            .font(.footnote.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Picker("App", selection: $departmentId) {
                            Text("Choose after sign-in").tag("")
                            ForEach(suiteApps) { app in
                                Text(app.label).tag(app.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .iagCard()
                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        Button {
                            error = box.store.login(username, password, departmentId: departmentId.isEmpty ? nil : departmentId)
                        } label: {
                            Text("Sign in")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(IagTheme.orange)
                        .controlSize(.large)
                    }

                    Text("Demo · admin, clerk, hr, procurement · iagdemo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .iagCanvas()
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
            .iagCanvas()
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
