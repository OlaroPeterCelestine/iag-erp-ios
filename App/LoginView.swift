import SwiftUI
import ErpCore

private enum LoginField: Hashable {
    case username, password
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
            ZStack {
                LoginAtmosphere()
                ScrollView {
                    VStack(spacing: 0) {
                        hero
                        formCard
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        Text("Inspire Africa Group")
                            .font(.caption2.weight(.medium))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.38))
                            .padding(.top, 28)
                            .padding(.bottom, 36)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showReset) {
                ResetPasswordView(username: username)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            IagBrandLogo(height: 118)
                .padding(.top, 56)
                .shadow(color: IagTheme.orange.opacity(0.28), radius: 28, y: 10)
            VStack(spacing: 8) {
                Text("FINANCE & OPERATIONS")
                    .font(.caption.weight(.semibold))
                    .tracking(2.4)
                    .foregroundStyle(IagTheme.orange)
                Text(appName)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text("Sign in to your workspace.")
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text("Finance  ·  Sales  ·  Projects  ·  HR")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.38))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            loginField("Username", text: $username, field: .username)
            passwordField
            Button("Forgot password?") { showReset = true }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(IagTheme.orange)
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.38))
            }
            Button {
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
            } label: {
                HStack(spacing: 10) {
                    if busy { ProgressView().tint(.white) }
                    Text(busy ? "Signing in…" : "Sign in")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [IagTheme.orange, IagTheme.orangeDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: IagTheme.orange.opacity(0.38), radius: 16, y: 8)
            .disabled(busy)
            .opacity(busy ? 0.72 : 1)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
    }

    @ViewBuilder
    private func loginField(_ title: String, text: Binding<String>, field: LoginField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.55))
            TextField("", text: text, prompt: Text(title).foregroundStyle(Color.white.opacity(0.32)))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(field == .username ? .username : .none)
                .focused($focus, equals: field)
                .foregroundStyle(.white)
                .tint(IagTheme.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(focus == field ? IagTheme.orange.opacity(0.85) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 8) {
                Group {
                    if showPassword {
                        TextField("", text: $password, prompt: Text("Password").foregroundStyle(Color.white.opacity(0.32)))
                    } else {
                        SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Color.white.opacity(0.32)))
                    }
                }
                .textContentType(.password)
                .focused($focus, equals: .password)
                .foregroundStyle(.white)
                .tint(IagTheme.orange)
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focus == .password ? IagTheme.orange.opacity(0.85) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct LoginAtmosphere: View {
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.05)
            Circle()
                .fill(Color(red: 0.09, green: 0.62, blue: 0.29).opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -90, y: -40)
            Circle()
                .fill(IagTheme.orange.opacity(0.32))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 110, y: 10)
            Circle()
                .fill(Color(red: 0.05, green: 0.62, blue: 0.89).opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 40, y: 160)
            Circle()
                .fill(Color(red: 0.86, green: 0.18, blue: 0.22).opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 64)
                .offset(x: -70, y: 220)
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
                SecureField("New password on this device", text: $password)
                SecureField("Confirm", text: $confirm)
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
