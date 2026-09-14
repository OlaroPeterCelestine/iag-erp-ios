import SwiftUI
import ErpCore

private enum LoginField: Hashable {
    case username, password
}

private enum LoginPalette {
    static let canvas = Color.white
    static let ink = Color(red: 24 / 255, green: 24 / 255, blue: 27 / 255)
    static let muted = Color(red: 113 / 255, green: 113 / 255, blue: 122 / 255)
    static let field = Color(red: 244 / 255, green: 244 / 255, blue: 245 / 255)
    static let line = Color(red: 228 / 255, green: 228 / 255, blue: 231 / 255)
    static let errorFill = Color(red: 255 / 255, green: 241 / 255, blue: 242 / 255)
    static let errorText = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
}

struct LoginView: View {
    @EnvironmentObject var box: StoreBox
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var showReset = false
    @State private var showPassword = false
    @FocusState private var focus: LoginField?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    IagBrandLogo(height: 56, mono: true)
                        .padding(.top, 24)
                    Text(appName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LoginPalette.ink)
                        .padding(.top, 16)
                    Text("Sign in")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(LoginPalette.ink)
                        .padding(.top, 28)
                    Text("Enter your username and password to continue.")
                        .font(.subheadline)
                        .foregroundStyle(LoginPalette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                    form
                        .padding(.top, 28)
                    Text("© Inspire Africa Group")
                        .font(.caption)
                        .foregroundStyle(LoginPalette.muted)
                        .padding(.top, 32)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
            .background(LoginPalette.canvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showReset) {
                ResetPasswordView(username: username)
            }
            }
        }
        .preferredColorScheme(.light)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            loginField("Username", text: $username, field: .username)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    fieldLabel("Password")
                    Spacer()
                    Button("Forgot password?") { showReset = true }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LoginPalette.ink)
                        .buttonStyle(.plain)
                }
                passwordFieldControl
            }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(LoginPalette.errorText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LoginPalette.errorFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Button(action: signInRemote) {
                HStack(spacing: 10) {
                    if busy { ProgressView().tint(.white) }
                    Text(busy ? "Signing in…" : "Sign in")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(LoginPalette.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(busy)
            .opacity(busy ? 0.72 : 1)
            .padding(.top, 4)
            Button("Continue on this device") {
                error = box.store.login(username, password)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(LoginPalette.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func loginField(_ title: String, text: Binding<String>, field: LoginField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)
            TextField("Enter \(title.lowercased())", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .submitLabel(.next)
                .focused($focus, equals: field)
                .foregroundStyle(LoginPalette.ink)
                .tint(LoginPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(LoginPalette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focus == field ? LoginPalette.ink : LoginPalette.line, lineWidth: 1)
                )
                .onSubmit { focus = .password }
        }
    }

    private var passwordFieldControl: some View {
        ZStack(alignment: .trailing) {
            Group {
                if showPassword {
                    TextField("Enter password", text: $password)
                } else {
                    SecureField("Enter password", text: $password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
            .submitLabel(.go)
            .focused($focus, equals: .password)
            .foregroundStyle(LoginPalette.ink)
            .tint(LoginPalette.ink)
            .padding(.leading, 14)
            .padding(.trailing, 52)
            .frame(minHeight: 48)
            .onSubmit(signInRemote)
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.body)
                    .foregroundStyle(LoginPalette.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            .padding(.trailing, 2)
        }
        .background(LoginPalette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(focus == .password ? LoginPalette.ink : LoginPalette.line, lineWidth: 1)
        )
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(LoginPalette.ink)
    }

    private func signInRemote() {
        guard !busy else { return }
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty {
            error = "Enter your username and password."
            return
        }
        busy = true
        error = nil
        focus = nil
        Task {
            let result = await box.store.loginAsync(username, password)
            await MainActor.run {
                error = result
                busy = false
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
    @State private var notice: String?
    @State private var done = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                SecureField("New password on this device", text: $password)
                    .textContentType(.newPassword)
                SecureField("Confirm", text: $confirm)
                    .textContentType(.newPassword)
                if let error { Text(error).foregroundStyle(.red) }
                if let notice { Text(notice).foregroundStyle(.secondary) }
                if done { Text("Password updated. Sign in with the new password.") }
                Button {
                    busy = true
                    error = nil
                    notice = nil
                    Task {
                        let result = await box.store.requestFrontendPasswordReset(username)
                        await MainActor.run {
                            busy = false
                            switch result {
                            case .success(let message):
                                notice = message
                            case .failure(let err):
                                error = err.message
                            }
                        }
                    }
                } label: {
                    Text(busy ? "Sending…" : "Email reset code")
                }
                .disabled(busy)
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
        .preferredColorScheme(.light)
    }
}
