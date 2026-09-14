import SwiftUI
import ErpCore

struct LoginView: View {
    @EnvironmentObject var box: StoreBox
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 56)
                        IagBrandLogo(height: 84, mono: true)
                        VStack(spacing: 8) {
                            Text(appName)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Sign in to continue")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        VStack(spacing: 12) {
                            loginField("Username", text: $username, secure: false)
                            loginField("Password", text: $password, secure: true)
                        }
                        Button("Forgot password?") { showReset = true }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        if let error {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button {
                            busy = true
                            error = nil
                            Task {
                                let result = await box.store.loginAsync(username, password)
                                await MainActor.run {
                                    error = result
                                    busy = false
                                }
                            }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.black) }
                                Text(busy ? "Signing in…" : "Sign in")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                        .controlSize(.large)
                        .disabled(busy)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showReset) {
                ResetPasswordView(username: username)
            }
        }
    }

    @ViewBuilder
    private func loginField(_ title: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(title).foregroundStyle(Color.white.opacity(0.4)))
            } else {
                TextField("", text: text, prompt: Text(title).foregroundStyle(Color.white.opacity(0.4)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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
