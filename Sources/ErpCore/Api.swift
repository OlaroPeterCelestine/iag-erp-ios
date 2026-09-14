import Foundation

public struct ErpRemoteUser: Equatable, Sendable {
    public var id: String
    public var username: String
    public var name: String
    public var email: String
    public var role: String
    public var roleId: String
    public var phone: String
    public var title: String
    public var crud: Crud?
    public var pagePermissions: [String: Crud]

    public init(
        id: String = "",
        username: String,
        name: String,
        email: String = "",
        role: String,
        roleId: String = "",
        phone: String = "",
        title: String = "",
        crud: Crud? = nil,
        pagePermissions: [String: Crud] = [:]
    ) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
        self.role = role
        self.roleId = roleId
        self.phone = phone
        self.title = title
        self.crud = crud
        self.pagePermissions = pagePermissions
    }

    public var authUser: AuthUser {
        AuthUser(
            username: username.isEmpty ? email.lowercased() : username.lowercased(),
            name: name.isEmpty ? username : name,
            role: role.isEmpty ? "Viewer" : role,
            email: email,
            phone: phone,
            title: title
        )
    }
}

public struct ErpRemoteSession: Equatable, Sendable {
    public var user: ErpRemoteUser
    public var token: String
    public var expiresAt: String

    public init(user: ErpRemoteUser, token: String, expiresAt: String = "") {
        self.user = user
        self.token = token
        self.expiresAt = expiresAt
    }
}

public enum ErpApiError: Error, Equatable, Sendable {
    case network(String)
    case unauthorized(String)
    case http(Int, String)

    public var message: String {
        switch self {
        case .network(let text): return text
        case .unauthorized(let text): return text
        case .http(_, let text): return text
        }
    }

    public var isNetwork: Bool {
        if case .network = self { return true }
        return false
    }

    public var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    public var isNotFound: Bool {
        if case .http(404, _) = self { return true }
        return false
    }

    public var isConflict: Bool {
        if case .http(409, _) = self { return true }
        return false
    }
}

public protocol ErpTransporting: AnyObject {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public final class URLSessionErpTransport: ErpTransporting {
    public init() {}
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

public protocol ErpApiClient: AnyObject {
    var origin: String { get set }
    var token: String? { get set }
    func login(username: String, password: String, keepSignedIn: Bool) async -> Result<ErpRemoteSession, ErpApiError>
    func me() async -> Result<ErpRemoteUser, ErpApiError>
    func logout() async
    func requestPasswordReset(username: String) async -> Result<String, ErpApiError>
    func updateProfile(name: String, email: String, phone: String, title: String) async -> Result<ErpRemoteUser, ErpApiError>
    func getRecords(module: String, entity: String) async -> Result<[[String: Any]], ErpApiError>
    func getRecord(module: String, entity: String, id: String) async -> Result<[String: Any], ErpApiError>
    func createRecord(module: String, entity: String, record: [String: String]) async -> Result<[String: Any], ErpApiError>
    func patchRecord(module: String, entity: String, id: String, record: [String: String]) async -> Result<[String: Any], ErpApiError>
    func deleteRecord(module: String, entity: String, id: String) async -> Result<Void, ErpApiError>
    func putRecords(module: String, entity: String, records: [[String: String]], removeIds: [String]) async -> Result<Void, ErpApiError>
    func approvalDesk() async -> Result<[String: Any], ErpApiError>
    func approvalAction(entity: String, id: String, action: String, comment: String) async -> Result<[String: Any], ErpApiError>
    func search(query: String) async -> Result<[[String: Any]], ErpApiError>
    func summary() async -> Result<[String: Any], ErpApiError>
    func listUsers() async -> Result<[[String: Any]], ErpApiError>
    func listRoles() async -> Result<[[String: Any]], ErpApiError>
}

public final class ErpApi: ErpApiClient {
    public var origin: String
    public var token: String?
    private let transport: ErpTransporting

    public init(origin: String = ErpConfig.liveFrontendOrigin, transport: ErpTransporting = URLSessionErpTransport()) {
        self.origin = ErpConfig.sanitizeOrigin(origin)
        self.transport = transport
    }

    public func login(username: String, password: String, keepSignedIn: Bool = true) async -> Result<ErpRemoteSession, ErpApiError> {
        let body: [String: Any] = [
            "emailOrUsername": username,
            "password": password,
            "keepSignedIn": keepSignedIn,
        ]
        switch await request(path: ErpAPI.Auth.login, method: "POST", body: body, authed: false) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            guard let data = json["data"] as? [String: Any],
                  let token = data["token"] as? String, !token.isEmpty,
                  let userJSON = data["user"] as? [String: Any],
                  let user = parseUser(userJSON)
            else {
                return .failure(.http(200, jsonString(json["error"]) ?? "Login succeeded but no API token was issued"))
            }
            self.token = token
            let expires = jsonString(data["expiresAt"]) ?? ""
            return .success(ErpRemoteSession(user: user, token: token, expiresAt: expires))
        }
    }

    public func me() async -> Result<ErpRemoteUser, ErpApiError> {
        switch await request(path: ErpAPI.Auth.me, method: "GET", body: nil, authed: true) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            let payload = (json["data"] as? [String: Any]) ?? json
            if let user = parseUser(payload) { return .success(user) }
            return .failure(.http(200, "Could not read the signed-in user."))
        }
    }

    public func logout() async {
        _ = await request(path: ErpAPI.Auth.logout, method: "POST", body: [:], authed: true)
        token = nil
    }

    public func requestPasswordReset(username: String) async -> Result<String, ErpApiError> {
        switch await request(
            path: ErpAPI.Auth.forgotPassword,
            method: "POST",
            body: ["emailOrUsername": username],
            authed: false
        ) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            let message = jsonString(json["message"])
                ?? "If an account exists, a reset code was sent."
            return .success(message)
        }
    }

    public func updateProfile(name: String, email: String, phone: String, title: String) async -> Result<ErpRemoteUser, ErpApiError> {
        switch await request(
            path: ErpAPI.Auth.profile,
            method: "PATCH",
            body: ["name": name, "email": email, "phone": phone, "title": title],
            authed: true
        ) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            let payload = (json["data"] as? [String: Any]) ?? json
            if let user = parseUser(payload) { return .success(user) }
            return .success(ErpRemoteUser(username: "", name: name, email: email, role: "", phone: phone, title: title))
        }
    }

    public func getRecords(module: String, entity: String) async -> Result<[[String: Any]], ErpApiError> {
        switch await request(path: ErpAPI.records(module: module, entity: entity), method: "GET", body: nil, authed: true) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            if let rows = json["data"] as? [[String: Any]] { return .success(rows) }
            if let rows = json["data"] as? [Any] {
                return .success(rows.compactMap { $0 as? [String: Any] })
            }
            return .success([])
        }
    }

    public func getRecord(module: String, entity: String, id: String) async -> Result<[String: Any], ErpApiError> {
        switch await request(path: ErpAPI.record(module: module, entity: entity, id: id), method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let row = json["data"] as? [String: Any] { return .success(row) }
            return .failure(.http(200, "Record missing in response."))
        }
    }

    public func createRecord(module: String, entity: String, record: [String: String]) async -> Result<[String: Any], ErpApiError> {
        switch await request(path: ErpAPI.records(module: module, entity: entity), method: "POST", body: stringMap(record), authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let row = json["data"] as? [String: Any] { return .success(row) }
            return .success(stringMap(record))
        }
    }

    public func patchRecord(module: String, entity: String, id: String, record: [String: String]) async -> Result<[String: Any], ErpApiError> {
        switch await request(path: ErpAPI.record(module: module, entity: entity, id: id), method: "PATCH", body: stringMap(record), authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let row = json["data"] as? [String: Any] { return .success(row) }
            return .success(stringMap(record))
        }
    }

    public func deleteRecord(module: String, entity: String, id: String) async -> Result<Void, ErpApiError> {
        switch await request(path: ErpAPI.record(module: module, entity: entity, id: id), method: "DELETE", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success: return .success(())
        }
    }

    public func putRecords(
        module: String,
        entity: String,
        records: [[String: String]],
        removeIds: [String] = []
    ) async -> Result<Void, ErpApiError> {
        var body: [String: Any] = [
            "records": records,
            "mode": "merge",
        ]
        if !removeIds.isEmpty { body["removeIds"] = removeIds }
        switch await request(path: ErpAPI.records(module: module, entity: entity), method: "PUT", body: body, authed: true) {
        case .failure(let error): return .failure(error)
        case .success: return .success(())
        }
    }

    public func approvalDesk() async -> Result<[String: Any], ErpApiError> {
        switch await request(path: ErpAPI.Approvals.desk, method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let data = json["data"] as? [String: Any] { return .success(data) }
            return .success(json)
        }
    }

    public func approvalAction(entity: String, id: String, action: String, comment: String) async -> Result<[String: Any], ErpApiError> {
        let path: String
        switch action {
        case "reject": path = ErpAPI.Approvals.reject(entity: entity, id: id)
        case "amend": path = ErpAPI.Approvals.amend(entity: entity, id: id)
        case "settle": path = ErpAPI.Approvals.settle(entity: entity, id: id)
        default: path = ErpAPI.Approvals.advance(entity: entity, id: id)
        }
        switch await request(path: path, method: "POST", body: ["comment": comment], authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let row = json["data"] as? [String: Any] { return .success(row) }
            return .success(json)
        }
    }

    public func search(query: String) async -> Result<[[String: Any]], ErpApiError> {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch await request(path: "\(ErpAPI.Data.search)?q=\(q)&limit=30", method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let rows = json["data"] as? [[String: Any]] { return .success(rows) }
            return .success([])
        }
    }

    public func summary() async -> Result<[String: Any], ErpApiError> {
        switch await request(path: ErpAPI.Data.summary, method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let data = json["data"] as? [String: Any] { return .success(data) }
            return .success(json)
        }
    }

    public func listUsers() async -> Result<[[String: Any]], ErpApiError> {
        switch await request(path: ErpAPI.Auth.users, method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let rows = json["data"] as? [[String: Any]] { return .success(rows) }
            return .success([])
        }
    }

    public func listRoles() async -> Result<[[String: Any]], ErpApiError> {
        switch await request(path: ErpAPI.Auth.roles, method: "GET", body: nil, authed: true) {
        case .failure(let error): return .failure(error)
        case .success(let json):
            if let rows = json["data"] as? [[String: Any]] { return .success(rows) }
            return .success([])
        }
    }

    private func stringMap(_ row: [String: String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: row.map { ($0.key, $0.value as Any) })
    }

    private func request(
        path: String,
        method: String,
        body: [String: Any]?,
        authed: Bool
    ) async -> Result<[String: Any], ErpApiError> {
        let root = origin.isEmpty ? ErpConfig.liveFrontendOrigin : origin
        guard let url = URL(string: root + path) else {
            return .failure(.network("Can't reach the workspace."))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("IAG-Central-iOS/\(appVersion)", forHTTPHeaderField: "User-Agent")
        if authed, let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard JSONSerialization.isValidJSONObject(body),
                  let data = try? JSONSerialization.data(withJSONObject: body)
            else {
                return .failure(.network("Could not encode the request."))
            }
            req.httpBody = data
        }
        do {
            let (data, response) = try await transport.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let errorText = jsonString(json["error"]) ?? HTTPURLResponse.localizedString(forStatusCode: status)
            if status == 401 || status == 403 {
                return .failure(.unauthorized(errorText.isEmpty ? "Invalid email/username or password." : errorText))
            }
            if status == 0 {
                return .failure(.network("Can't reach the workspace."))
            }
            if status >= 500 {
                return .failure(.network(errorText.isEmpty ? "The workspace is unavailable." : errorText))
            }
            if status >= 400 {
                return .failure(.http(status, errorText))
            }
            return .success(json)
        } catch {
            return .failure(.network("Can't reach the workspace."))
        }
    }

    private func parseUser(_ json: [String: Any]) -> ErpRemoteUser? {
        let username = jsonString(json["username"]) ?? ""
        let email = jsonString(json["email"]) ?? ""
        if username.isEmpty && email.isEmpty { return nil }
        let name = jsonString(json["name"]) ?? jsonString(json["fullName"]) ?? username
        let hasCrud = json["canView"] != nil || json["canCreate"] != nil || json["canEdit"] != nil || json["canDelete"] != nil
        return ErpRemoteUser(
            id: jsonString(json["id"]) ?? jsonString(json["uid"]) ?? "",
            username: username.isEmpty ? email : username,
            name: name,
            email: email,
            role: jsonString(json["role"]) ?? "Viewer",
            roleId: jsonString(json["roleId"]) ?? "",
            phone: jsonString(json["phone"]) ?? "",
            title: jsonString(json["title"]) ?? "",
            crud: hasCrud ? Crud.fromFlags(json) : nil,
            pagePermissions: parsePagePermissions(json["pagePermissions"])
        )
    }

    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func jsonString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber { return number.stringValue }
        return "\(value)"
    }
}
