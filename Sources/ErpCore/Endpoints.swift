import Foundation

/// ERP HTTP paths. Same contract on IAG Frontend (`/api/*` rewrite) and the Go API.
public enum ErpAPI {
    public static let liveFrontendOrigin = "https://iag-frontend-five.vercel.app"
    public static let liveApiOrigin = "https://api-production-b0c8d.up.railway.app"
    public static let localFrontendOrigin = "http://127.0.0.1:3180"
    public static let localApiOrigin = "http://127.0.0.1:8080"

    public enum Auth {
        public static let login = "/api/auth/login"
        public static let logout = "/api/auth/logout"
        public static let me = "/api/auth/me"
        public static let forgotPassword = "/api/auth/forgot-password"
        public static let verifyResetOTP = "/api/auth/verify-reset-otp"
        public static let resetPassword = "/api/auth/reset-password"
        public static let changePassword = "/api/auth/change-password"
        public static let profile = "/api/auth/profile"
        public static let users = "/api/auth/users"
        public static let roles = "/api/auth/roles"
        public static let sessions = "/api/auth/sessions"
    }

    public enum Sync {
        public static let ready = "/api/sync/ready"
        public static let status = "/api/sync/status"
        public static let bootstrap = "/api/sync/bootstrap"
    }

    public enum Data {
        public static let index = "/api/data"
        public static let catalog = "/api/data/catalog"
        public static let modules = "/api/data/modules"
        public static let records = "/api/data/records"
        public static let search = "/api/data/search"
        public static let summary = "/api/data/summary"
    }

    public enum Ledger {
        public static let accounts = "/api/ledger/accounts"
        public static let balances = "/api/ledger/balances"
        public static let lines = "/api/ledger/lines"
        public static let trialBalance = "/api/ledger/reports/trial-balance"
        public static let balanceSheet = "/api/ledger/reports/balance-sheet"
        public static let profitAndLoss = "/api/ledger/reports/profit-and-loss"
    }

    public enum Banking {
        public static let balances = "/api/banking/bank-balances"
    }

    public enum Approvals {
        public static let chain = "/api/approvals/chain"
        public static let desk = "/api/approvals/desk"
        public static func progress(entity: String, id: String) -> String {
            "/api/approvals/\(enc(entity))/\(enc(id))"
        }
        public static func advance(entity: String, id: String) -> String {
            "/api/approvals/\(enc(entity))/\(enc(id))/advance"
        }
        public static func settle(entity: String, id: String) -> String {
            "/api/approvals/\(enc(entity))/\(enc(id))/settle"
        }
        public static func reject(entity: String, id: String) -> String {
            "/api/approvals/\(enc(entity))/\(enc(id))/reject"
        }
        public static func amend(entity: String, id: String) -> String {
            "/api/approvals/\(enc(entity))/\(enc(id))/amend"
        }
    }

    public static let health = "/api/health"
    public static let recordsIndex = "/api/records"

    public static func records(module: String, entity: String) -> String {
        "/api/records/\(enc(module))/\(enc(entity))"
    }

    public static func record(module: String, entity: String, id: String) -> String {
        "/api/records/\(enc(module))/\(enc(entity))/\(enc(id))"
    }

    public static let chainEntities: Set<String> = [
        "payment-requests",
        "oral-payment-requests",
        "requisitions",
        "general-requests",
        "fuel-requests",
        "trip-requests",
        "maintenance-requests",
        "equipment-and-vehicle-requests",
        "document-requests",
        "leave-requests",
        "payroll-runs",
    ]

    public static func isChainEntity(_ entity: String) -> Bool {
        chainEntities.contains(apiEntityKey(entity))
    }

    private static func enc(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
