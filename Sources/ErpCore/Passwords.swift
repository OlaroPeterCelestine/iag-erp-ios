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
