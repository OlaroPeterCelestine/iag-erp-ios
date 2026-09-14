import CryptoKit
import Foundation

func passwordDigest(_ username: String, _ password: String) -> String {
    let user = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let material = "iag-central|\(user)|\(password)"
    let digest = SHA256.hash(data: Data(material.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

func isPasswordHash(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy(\.isHexDigit)
}

public struct UserNotice: Equatable, Sendable {
    public var title: String
    public var message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

/// Maps store/API errors to short copy for alerts. Never pass the raw string through.
public func userNotice(from raw: String) -> UserNotice {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if t.contains("enter your username") || (t.contains("username") && t.contains("password") && t.contains("enter")) {
        return UserNotice(title: "Sign in", message: "Enter your username and password.")
    }
    if t.contains("at least 6") {
        return UserNotice(title: "Password too short", message: "Use at least 6 characters.")
    }
    if t.contains("do not match") || t.contains("don't match") {
        return UserNotice(title: "Passwords don't match", message: "Type the same password in both fields.")
    }
    if t.contains("no password set") {
        return UserNotice(title: "Set a password", message: "Save a password on this phone, then try again.")
    }
    if t.contains("can't reach") || t.contains("cant reach") || t.contains("timed out") || t.contains("network") {
        return UserNotice(title: "No connection", message: "We couldn't reach IAG right now. Check your internet, or continue on this device.")
    }
    if t.contains("wrong password") || t.contains("unknown user") || t.contains("invalid")
        || t.contains("live sign-in") || t.contains("rejected this password")
        || t.contains("unauthorized") || t.contains("10+") || t.contains("10 character") {
        return UserNotice(
            title: "Couldn't sign in",
            message: "That username or password isn't right. Try again, or tap Continue on this device."
        )
    }
    return UserNotice(title: "Couldn't sign in", message: "Something went wrong. Please try again.")
}
