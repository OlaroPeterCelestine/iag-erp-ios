import Foundation

/// Live IAG Frontend — Next.js app that proxies `/api/*` to the shared Go API.
public enum ErpConfig {
    public static let liveFrontendOrigin = ErpAPI.liveFrontendOrigin
    public static let liveApiOrigin = ErpAPI.liveApiOrigin
    public static let localFrontendOrigin = ErpAPI.localFrontendOrigin
    public static let localApiOrigin = ErpAPI.localApiOrigin
    public static let originOverrideKey = "iag-erp-ios-frontend-url"

    public static func origin(
        from persistence: KeyValueStore? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        if let raw = persistence?.get(originOverrideKey) {
            let normalized = sanitizeOrigin(raw)
            if !normalized.isEmpty { return normalized }
        }
        if let env = environment["IAG_FRONTEND_URL"] {
            let normalized = sanitizeOrigin(env)
            if !normalized.isEmpty { return normalized }
        }
        return liveFrontendOrigin
    }

    public static func sanitizeOrigin(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        if value.isEmpty { return "" }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
        return "https://\(value)"
    }

    public static func saveOrigin(_ origin: String, to persistence: KeyValueStore) {
        let normalized = sanitizeOrigin(origin)
        persistence.put(originOverrideKey, normalized.isEmpty ? liveFrontendOrigin : normalized)
    }
}
