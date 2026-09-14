import XCTest
@testable import ErpCore

final class FakeTransport: ErpTransporting {
    var originPrefix = "https://iag-frontend-five.vercel.app"
    var users: [String: (password: String, user: [String: Any], token: String)] = [:]
    var collections: [String: [[String: Any]]] = [:]
    var failNetwork = false
    var lastPath = ""
    var paths: [String] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if failNetwork { throw URLError(.notConnectedToInternet) }
        let path = request.url?.path ?? ""
        lastPath = path
        paths.append(path)
        func json(_ status: Int, _ body: [String: Any]) throws -> (Data, URLResponse) {
            let data = try JSONSerialization.data(withJSONObject: body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
        if path == "/api/auth/login" {
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            let username = "\(body?["emailOrUsername"] ?? "")".lowercased()
            let password = "\(body?["password"] ?? "")"
            guard let row = users[username], row.password == password else {
                return try json(401, ["ok": false, "error": "Invalid email/username or password."])
            }
            return try json(200, [
                "ok": true,
                "data": [
                    "user": row.user,
                    "token": row.token,
                    "expiresAt": "2026-12-31T00:00:00Z",
                    "tokenType": "Bearer",
                ],
            ])
        }
        if path == "/api/auth/me" {
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            guard auth.hasPrefix("Bearer "), let match = users.values.first(where: { auth.hasSuffix($0.token) }) else {
                return try json(401, ["ok": false, "error": "Unauthorized"])
            }
            return try json(200, ["data": rowUser(match.user)])
        }
        if path == "/api/auth/forgot-password" {
            return try json(200, ["ok": true, "message": "If an account exists, a reset code has been sent."])
        }
        if path == "/api/auth/logout" {
            return try json(200, ["ok": true])
        }
        if path == "/api/auth/profile" {
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
            var user = users.values.first?.user ?? [:]
            for (key, value) in body { user[key] = value }
            return try json(200, ["data": user])
        }
        if path == "/api/auth/users" {
            return try json(200, ["data": users.values.map { $0.user }])
        }
        if path == "/api/auth/roles" {
            return try json(200, ["data": [
                [
                    "id": "role-admin-db",
                    "name": "Administrator",
                    "canView": "Yes",
                    "canCreate": "Yes",
                    "canEdit": "Yes",
                    "canDelete": "Yes",
                    "system": true,
                ],
                [
                    "id": "r1",
                    "name": "Field Clerk",
                    "canView": "Yes",
                    "canCreate": "Yes",
                    "canEdit": "No",
                    "canDelete": "No",
                    "system": false,
                    "pagePermissions": [
                        "sales": ["canView": "Yes", "canCreate": "Yes", "canEdit": "No", "canDelete": "No"],
                    ],
                ],
            ]])
        }
        if path == "/api/approvals/desk" {
            return try json(200, ["ok": true, "data": ["items": [] as [Any], "count": 0]])
        }
        if path.hasPrefix("/api/approvals/") {
            let rest = String(path.dropFirst("/api/approvals/".count))
            let parts = rest.split(separator: "/").map(String.init)
            let action = parts.last ?? "advance"
            let id = parts.count >= 2 ? parts[1] : ""
            let status = action == "reject" ? "Rejected" : "PM Approved"
            return try json(200, [
                "ok": true,
                "data": [
                    "id": id,
                    "status": status,
                    "record": ["id": id, "status": status, "name": "PR-1"],
                ],
            ])
        }
        if path.hasPrefix("/api/records/") {
            let rest = String(path.dropFirst("/api/records/".count))
            let parts = rest.split(separator: "/").map(String.init)
            let method = request.httpMethod ?? "GET"
            if parts.count >= 2 {
                let key = "\(parts[0])/\(parts[1])"
                if method == "PUT" {
                    return try json(200, ["ok": true])
                }
                if method == "POST" && parts.count == 2 {
                    var row = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
                    if jsonString(row["id"]) == nil { row["id"] = "new-1" }
                    var list = collections[key] ?? []
                    list.append(row)
                    collections[key] = list
                    return try json(201, ["ok": true, "data": row])
                }
                if parts.count >= 3 {
                    let id = parts[2]
                    if method == "DELETE" {
                        collections[key] = (collections[key] ?? []).filter { jsonString($0["id"]) != id }
                        return try json(200, ["ok": true])
                    }
                    if method == "PATCH" {
                        let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
                        var list = collections[key] ?? []
                        if let idx = list.firstIndex(where: { jsonString($0["id"]) == id }) {
                            var row = list[idx]
                            for (k, v) in body { row[k] = v }
                            list[idx] = row
                            collections[key] = list
                            return try json(200, ["ok": true, "data": row])
                        }
                        return try json(404, ["ok": false, "error": "not found"])
                    }
                    let row = (collections[key] ?? []).first { jsonString($0["id"]) == id } ?? [:]
                    return try json(200, ["data": row])
                }
                return try json(200, ["data": collections[key] ?? []])
            }
        }
        return try json(404, ["ok": false, "error": "not found"])
    }

    private func jsonString(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rowUser(_ user: [String: Any]) -> [String: Any] { user }
}

final class ApiTests: XCTestCase {
    func testDefaultFrontendOriginIsTheLiveApp() {
        XCTAssertEqual(ErpConfig.liveFrontendOrigin, "https://iag-frontend-five.vercel.app")
        XCTAssertEqual(ErpConfig.origin(), "https://iag-frontend-five.vercel.app")
        XCTAssertEqual(ErpConfig.sanitizeOrigin("iag-frontend-five.vercel.app/"), "https://iag-frontend-five.vercel.app")
        let store = MemoryKeyValueStore()
        ErpConfig.saveOrigin("http://127.0.0.1:3180", to: store)
        XCTAssertEqual(ErpConfig.origin(from: store), "http://127.0.0.1:3180")
    }

    func testEntityKeysMatchFrontendSlugs() {
        XCTAssertEqual(apiEntityKey("Bank & Cash Accounts"), "bank-and-cash-accounts")
        XCTAssertEqual(apiEntityKey("Warehouses & Locations"), "inventory-locations")
        XCTAssertEqual(apiEntityKey("Payment Requests (IPC)"), "payment-requests")
        XCTAssertEqual(apiEntityKey("New Project"), "projects")
        XCTAssertEqual(apiStorageTarget(moduleId: "receipts-payments", entity: "Receipts").module, "banking")
        XCTAssertEqual(apiStorageTarget(moduleId: "clock-in", entity: "My punches").entity, "attendance")
        XCTAssertEqual(apiStorageTarget(moduleId: "general-requests", entity: "General Requests").module, "requests")
    }

    func testRemoteLoginUsesFrontendAndFallsBackWhenOffline() async {
        let transport = FakeTransport()
        transport.users["admin"] = (
            password: "Secret123!",
            user: ["id": "u1", "username": "admin", "name": "Admin", "email": "admin@iag.africa", "role": "Administrator"],
            token: "tok-admin"
        )
        let persistence = MemoryKeyValueStore()
        let api = ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport)
        let s = ErpStore(persistence: persistence, api: api)
        s.load()

        let signedIn = await s.loginAsync("admin", "Secret123!")
        XCTAssertNil(signedIn)
        XCTAssertTrue(s.remoteSession)
        XCTAssertEqual(s.user?.username, "admin")
        XCTAssertEqual(s.frontendOrigin, ErpConfig.liveFrontendOrigin)
        XCTAssertEqual(api.token, "tok-admin")
        XCTAssertEqual(s.roleOf("Administrator")?.id, "role-admin-db")
        XCTAssertEqual(s.roleOf("Field Clerk")?.id, "r1")
        XCTAssertTrue(s.roleOf("Field Clerk")?.crud.create == true)

        let reloaded = ErpStore(persistence: persistence, api: ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport))
        reloaded.load()
        XCTAssertEqual(reloaded.roleOf("Administrator")?.id, "role-admin-db")
        XCTAssertEqual(reloaded.roleOf("Field Clerk")?.id, "r1")

        transport.failNetwork = true
        let offline = ErpStore(persistence: MemoryKeyValueStore(), api: ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport))
        offline.load()
        offline.seedTestPasswords("unit-test-login")
        let offlineLogin = await offline.loginAsync("admin", "unit-test-login")
        XCTAssertNil(offlineLogin)
        XCTAssertTrue(offline.isSignedIn)
        XCTAssertFalse(offline.remoteSession)

        let unreachable = ErpStore(persistence: MemoryKeyValueStore(), api: ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport))
        unreachable.load()
        let unreachableError = await unreachable.loginAsync("nobody", "nope")
        XCTAssertEqual(
            unreachableError,
            "Can't reach the workspace."
        )
    }

    func testWrongFrontendPasswordDoesNotUseLocalTrial() async {
        let transport = FakeTransport()
        transport.users["admin"] = (
            password: "RemoteOnly!",
            user: ["username": "admin", "name": "Admin", "role": "Administrator"],
            token: "tok"
        )
        let s = ErpStore(persistence: MemoryKeyValueStore(), api: ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport))
        s.load()
        s.seedTestPasswords("unit-test-login")
        let rejected = await s.loginAsync("admin", "unit-test-login")
        XCTAssertEqual(rejected, "Invalid email/username or password.")
        XCTAssertFalse(s.isSignedIn)

        let shortRejected = await s.loginAsync("admin", "shortpw")
        XCTAssertEqual(
            shortRejected,
            ErpStore.describeLiveLoginFailure(password: "shortpw", apiMessage: "Invalid email/username or password.")
        )
        XCTAssertFalse(s.isSignedIn)
    }

    func testRefreshEntityMapsFrontendRecords() async {
        let transport = FakeTransport()
        transport.users["clerk"] = (
            password: "Secret123!",
            user: ["username": "clerk", "name": "Clerk", "role": "Clerk"],
            token: "tok-clerk"
        )
        transport.collections["sales/customers"] = [
            ["id": "c1", "name": "Cafe Javas", "status": "Active", "amount": "6200000", "description": "Kampala"],
        ]
        let api = ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport)
        let s = ErpStore(persistence: MemoryKeyValueStore(), api: api)
        s.load()
        let signedIn = await s.loginAsync("clerk", "Secret123!")
        XCTAssertNil(signedIn)
        await s.refreshEntity("sales", "Customers")
        XCTAssertEqual(s.recordsFor("sales", "Customers").first?.title, "Cafe Javas")
        XCTAssertEqual(transport.lastPath, "/api/records/sales/customers")
    }

    func testItemCrudAndChainApprovalUseRestEndpoints() async {
        let transport = FakeTransport()
        transport.users["admin"] = (
            password: "Secret123!",
            user: ["username": "admin", "name": "Admin", "role": "Administrator"],
            token: "tok-admin"
        )
        let api = ErpApi(origin: ErpConfig.liveFrontendOrigin, transport: transport)
        let s = ErpStore(persistence: MemoryKeyValueStore(), api: api)
        s.load()
        let signedIn = await s.loginAsync("admin", "Secret123!")
        XCTAssertNil(signedIn)

        let draft = ErpRecord(
            id: "pr-9",
            moduleId: "projects",
            entity: "Payment Requests (IPC)",
            title: "PR-9",
            subtitle: "IPC",
            status: "Draft",
            date: "2026-09-14"
        )
        s.addRecord(draft)
        draft.status = "Submitted"
        let approved = await s.approveRecordAsync(draft)
        XCTAssertNil(approved)
        XCTAssertTrue(transport.paths.contains("/api/approvals/payment-requests/pr-9/advance"))
        XCTAssertEqual(draft.status, "PM Approved")

        let removed = await s.deleteRecordAsync(draft)
        XCTAssertNil(removed)
        XCTAssertTrue(transport.paths.contains("/api/records/projects/payment-requests/pr-9"))
        XCTAssertTrue(s.recordsFor("projects", "Payment Requests (IPC)").isEmpty)
    }

    func testChainEntityKeys() {
        XCTAssertTrue(ErpAPI.isChainEntity("Payment Requests (IPC)"))
        XCTAssertTrue(ErpAPI.isChainEntity("Material Requests"))
        XCTAssertFalse(ErpAPI.isChainEntity("Expense Claims"))
        XCTAssertEqual(ErpAPI.Auth.login, "/api/auth/login")
        XCTAssertEqual(ErpAPI.records(module: "sales", entity: "customers"), "/api/records/sales/customers")
    }
}
