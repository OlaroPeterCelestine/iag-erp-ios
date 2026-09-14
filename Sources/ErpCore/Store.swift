import Foundation

public let storeKey = "iag-erp-ios-v1"

public final class ErpStore {
    public let modules: [ErpModule]
    private let persistence: KeyValueStore
    private var listeners: [() -> Void] = []

    public private(set) var user: AuthUser?
    public var records: [ErpRecord] = []
    public var roles: [RoleDefinition] = systemRoleDefinitions()
    public var workspaceUsers: [WorkspaceUser] = []
    public var search: String = ""
    public private(set) var booted = false
    public private(set) var activeDepartmentId: String?
    public private(set) var activeAppId: String?
    public private(set) var themeMode: String = "system"
    public private(set) var remoteSession = false
    public private(set) var lastRemoteError: String?
    private var passwords: [String: String] = [:]
    private var apiToken: String = ""
    private var knownRemoteIds = Set<String>()
    private let api: ErpApiClient?

    public init(
        modules: [ErpModule] = erpModules(),
        persistence: KeyValueStore = MemoryKeyValueStore(),
        api: ErpApiClient? = nil
    ) {
        self.modules = modules
        self.persistence = persistence
        self.api = api
        if let api {
            api.origin = ErpConfig.origin(from: persistence)
        }
    }

    public var frontendOrigin: String {
        api?.origin ?? ErpConfig.origin(from: persistence)
    }

    public var usesFrontend: Bool { api != nil }

    public var isSignedIn: Bool { user != nil }
    public var roleName: String? { user?.role }
    public var isAdmin: Bool { isAdminRole(roleName) }
    public var currentRole: RoleDefinition? { roleOf(roleName) }
    public var kpis: [Kpi] { defaultKpis }
    public var visibleModules: [ErpModule] { modules.filter { canAccessModule(roleName, $0.id, definition: currentRole) } }
    public var visibleSuiteApps: [SuiteApp] {
        suiteApps.filter { canOpenSuiteApp(roleName, $0.id, definition: currentRole) }
    }
    public var activeSuiteApp: SuiteApp? { suiteAppById(activeAppId) }
    public var appModules: [ErpModule] {
        guard let app = activeSuiteApp else { return visibleModules }
        return visibleModules.filter { app.moduleIds.contains($0.id) }
    }
    public var appPendingApprovals: [ErpRecord] {
        guard activeSuiteApp != nil else { return pendingApprovals }
        let ids = Set(appModules.map(\.id))
        return pendingApprovals.filter { ids.contains($0.moduleId) }
    }
    public var visibleWorkspaceTools: [WorkspaceTool] {
        workspaceTools.filter { canAccessSpecialNav(roleName, $0.id, definition: currentRole) }
    }
    public var approvalEntities: Set<String> { Set(modules.flatMap(\.approvalEntities)) }
    public var canApprove: Bool { canAccessApprovalDesk(roleName) }
    public var canClockIn: Bool { user != nil && crudForRole(roleName, definition: currentRole).view }
    public var customRoles: [RoleDefinition] { roles.filter { !$0.system } }
    public var pendingApprovals: [ErpRecord] { pendingApprovalsFor(nil) }
    public var recent: [ErpRecord] { Array(records.prefix(8)) }
    public var accountingDocuments: [ErpRecord] {
        let needles = ["invoice", "quote", "order", "note", "receipt", "payment", "payslip", "journal", "transfer", "claim", "request"]
        return records.filter { rec in
            canOpen(rec.moduleId) && needles.contains { rec.entity.lowercased().contains($0) }
        }
    }

    public var homeQuickActions: [QuickAction] {
        Array(quickActionCatalog.filter { action in
            if let appId = action.appId {
                guard activeAppId == appId else { return false }
            } else {
                guard activeAppId != nil else { return false }
            }
            return allowsQuickAction(action)
        }.prefix(8))
    }

    public var launcherQuickActions: [QuickAction] {
        var out: [QuickAction] = []
        for action in quickActionCatalog where action.appId == nil && allowsQuickAction(action) {
            out.append(action)
        }
        var seenApps = Set<String>()
        let visible = Set(visibleSuiteApps.map(\.id))
        for action in quickActionCatalog {
            guard let appId = action.appId, visible.contains(appId), !seenApps.contains(appId) else { continue }
            guard allowsQuickAction(action) else { continue }
            seenApps.insert(appId)
            out.append(action)
        }
        return out
    }

    public func recordCount(forApp app: SuiteApp) -> Int {
        records.filter { app.moduleIds.contains($0.moduleId) && canOpen($0.moduleId) }.count
    }

    public var welcomeStats: [WelcomeStat] {
        let scoped = records.filter { rec in
            guard canOpen(rec.moduleId) else { return false }
            if let app = activeSuiteApp { return app.moduleIds.contains(rec.moduleId) }
            return true
        }
        var stats: [WelcomeStat] = []
        if activeAppId == nil {
            stats.append(WelcomeStat(id: "apps", label: "Apps", value: "\(visibleSuiteApps.count)"))
        } else {
            stats.append(WelcomeStat(id: "desks", label: "Desks", value: "\(appModules.count)"))
        }
        stats.append(WelcomeStat(id: "records", label: "Records", value: "\(scoped.count)"))
        if canApprove {
            let pending = activeAppId == nil ? pendingApprovals.count : appPendingApprovals.count
            stats.append(WelcomeStat(id: "todo", label: "To do", value: "\(pending)"))
        }
        if canClockIn {
            stats.append(WelcomeStat(id: "clock", label: "Clock", value: openAttendanceToday() == nil ? "Out" : "In"))
        }
        return Array(stats.prefix(4))
    }

    public func allowsQuickAction(_ action: QuickAction) -> Bool {
        switch action.kind {
        case .clock:
            return canClockIn
        case .approvals:
            return canApprove
        case .access:
            return isAdmin
        case .create:
            guard canOpen(action.moduleId) else { return false }
            if let entity = action.entity { return canCreate(action.moduleId, entity) }
            return canCreate(action.moduleId)
        case .list:
            return canOpen(action.moduleId)
        }
    }

    public func count(moduleId: String, entity: String) -> Int {
        recordsFor(moduleId, entity).count
    }

    public func recordsFor(_ moduleId: String, _ entity: String) -> [ErpRecord] {
        if entity == "My punches" { return myPunches() }
        if entity == "Punch Log" && moduleId == "clock-in" { return forEntity("payroll", "Punch Log") }
        return forEntity(moduleId, entity)
    }

    public func searchHits(_ query: String) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        var hits: [SearchHit] = []
        for module in appModules {
            if module.label.lowercased().contains(q) || module.description.lowercased().contains(q) {
                hits.append(SearchHit(kind: .module, title: module.label, subtitle: module.group, moduleId: module.id))
            }
            for entity in module.entities where entity.lowercased().contains(q) {
                hits.append(SearchHit(kind: .entity, title: entity, subtitle: module.label, moduleId: module.id, entity: entity))
            }
        }
        for tool in visibleWorkspaceTools where tool.label.lowercased().contains(q) || tool.description.lowercased().contains(q) {
            hits.append(SearchHit(kind: .tool, title: tool.label, subtitle: tool.group, moduleId: tool.id))
        }
        for rec in records where canOpen(rec.moduleId) {
            if activeSuiteApp != nil && !appModules.contains(where: { $0.id == rec.moduleId }) { continue }
            if rec.title.lowercased().contains(q) || rec.subtitle.lowercased().contains(q) || rec.entity.lowercased().contains(q) {
                hits.append(SearchHit(kind: .record, title: rec.title, subtitle: "\(rec.entity) · \(rec.status)", moduleId: rec.moduleId, entity: rec.entity, recordId: rec.id))
            }
            if hits.count >= 40 { break }
        }
        return Array(hits.prefix(30))
    }

    public func geofenceZones() -> [GeofenceZone] {
        let sites = forEntity("payroll", "Sites").compactMap { zoneFromRecord($0, kind: "site") }
        let blocks = forEntity("payroll", "Blocks").compactMap { zoneFromRecord($0, kind: "block") }
        return blocks + sites
    }

    public func myPunches() -> [ErpRecord] {
        let name = (user?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return forEntity("payroll", "Attendance").filter { recordField($0, "employee", "Employee") == name || $0.subtitle.contains(name) || $0.title.contains(name) }
    }

    public func openAttendanceToday() -> ErpRecord? {
        let today = todayIsoDate()
        return myPunches().first { rec in
            rec.date == today && !recordField(rec, "clockIn", "Clock in").isEmpty && recordField(rec, "clockOut", "Clock out").isEmpty
        }
    }

    @discardableResult
    public func punch(kind: String, latitude: Double, longitude: Double, accuracy: Double) -> String? {
        guard canClockIn else { return "Sign in to clock in." }
        let check = verifyAgainstZones(GeoPoint(latitude: latitude, longitude: longitude), geofenceZones(), accuracyMeters: accuracy)
        let name = user?.name ?? "Staff"
        let clock = nowClock()
        let today = todayIsoDate()
        if check.status == "Outside" {
            addPunchLog(kind: kind, name: name, check: check, latitude: latitude, longitude: longitude, accuracy: accuracy)
            return check.note
        }
        if kind == "in" {
            if openAttendanceToday() != nil { return "You already have an open check-in today. Clock out first." }
            let site = check.zone?.kind == "site" ? (check.zone?.name ?? "") : (check.zone?.siteName ?? "")
            let block = check.zone?.kind == "block" ? (check.zone?.name ?? "") : ""
            insertRecord(ErpRecord(
                id: newId(),
                moduleId: "payroll",
                entity: "Attendance",
                title: "ATT-\(today.replacingOccurrences(of: "-", with: ""))-\(clock.replacingOccurrences(of: ":", with: ""))",
                subtitle: "\(name) · \(check.zone?.name ?? "On site")",
                status: "Present",
                date: today,
                fields: [
                    "employee": name,
                    "site": site,
                    "block": block,
                    "clockIn": clock,
                    "clockOut": "",
                    "hours": "",
                    "latitude": String(format: "%.6f", latitude),
                    "longitude": String(format: "%.6f", longitude),
                    "accuracyMeters": "\(Int(accuracy.rounded()))",
                    "verification": check.status,
                    "verificationNote": check.note,
                ]
            ))
            return "Checked in at \(clock) · \(check.status) · \(check.note)"
        }
        guard let open = openAttendanceToday() else { return "No open check-in found for today." }
        let clockIn = recordField(open, "clockIn", "Clock in")
        open.subtitle = "\(name) · out \(clock)"
        open.fields["clockOut"] = clock
        open.fields["hours"] = hoursBetween(clockIn, clock)
        open.fields["latitude"] = String(format: "%.6f", latitude)
        open.fields["longitude"] = String(format: "%.6f", longitude)
        open.fields["accuracyMeters"] = "\(Int(accuracy.rounded()))"
        open.fields["verification"] = check.status
        persist()
        notify()
        pushRemote(open)
        return "Checked out at \(clock) · \(check.status)"
    }

    private func addPunchLog(kind: String, name: String, check: GeofenceCheck, latitude: Double, longitude: Double, accuracy: Double) {
        insertRecord(ErpRecord(
            id: newId(),
            moduleId: "payroll",
            entity: "Punch Log",
            title: "Rejected \(kind) · \(nowClock())",
            subtitle: name,
            status: "Rejected",
            date: todayIsoDate(),
            fields: [
                "employee": name,
                "kind": kind,
                "latitude": String(format: "%.6f", latitude),
                "longitude": String(format: "%.6f", longitude),
                "accuracyMeters": "\(Int(accuracy.rounded()))",
                "verification": check.status,
                "verificationNote": check.note,
            ]
        ))
    }

    public func addListener(_ listener: @escaping () -> Void) {
        listeners.append(listener)
    }

    private func notify() { listeners.forEach { $0() } }

    public func roleOf(_ name: String?) -> RoleDefinition? { findRoleDefinition(roles, name) }
    public func canOpen(_ moduleId: String) -> Bool { canAccessModule(roleName, moduleId, definition: currentRole) }
    public func canCreate(_ moduleId: String, _ entity: String? = nil) -> Bool {
        if let entity { return canCreateEntity(roleName, moduleId, entity, definition: currentRole) }
        return canCreateIn(roleName, moduleId, definition: currentRole)
    }
    public func canEdit(_ moduleId: String, _ entity: String? = nil) -> Bool {
        if let entity { return canEditEntity(roleName, moduleId, entity, definition: currentRole) }
        return canEditIn(roleName, moduleId, definition: currentRole)
    }
    public func canDelete(_ moduleId: String, _ entity: String? = nil) -> Bool {
        if let entity { return canDeleteEntity(roleName, moduleId, entity, definition: currentRole) }
        return canDeleteIn(roleName, moduleId, definition: currentRole)
    }
    public func canApproveModule(_ moduleId: String) -> Bool { canApproveIn(roleName, moduleId, definition: currentRole) }
    public func canVoid(_ moduleId: String) -> Bool { canVoidIn(roleName, moduleId, definition: currentRole) }

    func seedTestPasswords(_ password: String) {
        for account in demoAccounts {
            passwords[account.username.lowercased()] = passwordDigest(account.username, password)
        }
    }

    private func passwordMatches(_ username: String, _ password: String) -> Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let stored = passwords[u], !stored.isEmpty else { return false }
        if isPasswordHash(stored) { return stored == passwordDigest(u, password) }
        if stored == password {
            passwords[u] = passwordDigest(u, password)
            persist()
            return true
        }
        return false
    }

    private func storePassword(_ username: String, _ password: String) {
        passwords[username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = passwordDigest(username, password)
    }

    private func migrateLegacyPasswords() {
        var changed = false
        for (user, value) in passwords {
            if !value.isEmpty && !isPasswordHash(value) {
                passwords[user] = passwordDigest(user, value)
                changed = true
            }
        }
        if changed { persist() }
    }

    public func moduleById(_ id: String) -> ErpModule? { modules.first { $0.id == id } }
    public func forEntity(_ moduleId: String, _ entity: String) -> [ErpRecord] { records.filter { $0.moduleId == moduleId && $0.entity == entity } }
    public func forModule(_ moduleId: String) -> [ErpRecord] { records.filter { $0.moduleId == moduleId } }

    public func isOpenStatus(_ status: String) -> Bool {
        let s = status.lowercased()
        return s.contains("pending") || s.contains("open") || s.contains("submitted")
    }

    public func pendingApprovalsFor(_ moduleId: String?) -> [ErpRecord] {
        let rows = moduleId == nil ? records : forModule(moduleId!)
        let def = currentRole
        return rows.filter { approvalEntities.contains($0.entity) && isOpenStatus($0.status) && canAccessModule(roleName, $0.moduleId, definition: def) }
    }

    public func filtered(_ moduleId: String, _ entity: String) -> [ErpRecord] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let list = forEntity(moduleId, entity)
        if q.isEmpty { return list }
        return list.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) || $0.status.lowercased().contains(q) }
    }

    public func load() {
        guard let raw = persistence.get(storeKey), let data = raw.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            records = seed()
            roles = systemRoleDefinitions()
            workspaceUsers = []
            persist()
            booted = true
            notify()
            return
        }
        if let userJSON = j["user"] as? [String: Any] { user = AuthUser.fromJSON(userJSON) }
        apiToken = (j["apiToken"] as? String) ?? ""
        remoteSession = !apiToken.isEmpty
        api?.token = apiToken.isEmpty ? nil : apiToken
        lastRemoteError = nil
        let dept = j["activeDepartmentId"] as? String
        activeDepartmentId = (dept?.isEmpty ?? true) || moduleById(dept ?? "") == nil ? nil : dept
        let app = j["activeAppId"] as? String
        if let app, suiteAppById(app) != nil {
            activeAppId = app
        } else if let dept = activeDepartmentId {
            activeAppId = suiteAppContaining(dept)?.id
        } else {
            activeAppId = nil
        }
        if let pw = j["passwords"] as? [String: Any] {
            passwords = Dictionary(uniqueKeysWithValues: pw.map { ($0.key.lowercased(), "\($0.value)") })
        }
        migrateLegacyPasswords()
        readAccessLists(j)
        if let rows = j["records"] as? [[String: Any]] {
            records = rows.map(ErpRecord.fromJSON)
        }
        if records.isEmpty && !remoteSession { records = seed() }
        if remoteSession {
            knownRemoteIds = Set(records.map(\.id))
        } else {
            mergeMissingCatalogRecords()
        }
        enforceAccess()
        if let mode = j["themeMode"] as? String, mode == "light" || mode == "dark" { themeMode = mode }
        booted = true
        notify()
    }

    public func persist() {
        var json: [String: Any] = [
            "themeMode": themeMode,
            "passwords": passwords,
            "roles": roles.map { $0.toJSON() },
            "workspaceUsers": workspaceUsers.map { $0.toJSON() },
            "records": records.map { $0.toJSON() },
        ]
        json["user"] = user?.toJSON() ?? NSNull()
        json["activeDepartmentId"] = activeDepartmentId ?? NSNull()
        json["activeAppId"] = activeAppId ?? NSNull()
        json["apiToken"] = apiToken
        json["remoteSession"] = remoteSession
        if JSONSerialization.isValidJSONObject(json),
           let data = try? JSONSerialization.data(withJSONObject: json),
           let raw = String(data: data, encoding: .utf8) {
            persistence.put(storeKey, raw)
        }
    }

    private func readAccessLists(_ j: [String: Any]) {
        let stored = (j["roles"] as? [[String: Any]] ?? []).map(RoleDefinition.fromJSON)
        roles = remoteSession ? adoptApiRoles(stored) : mergeStoredRoles(stored)
        workspaceUsers = (j["workspaceUsers"] as? [[String: Any]] ?? [])
            .map(WorkspaceUser.fromJSON)
            .filter { !$0.username.isEmpty && demoAccountFor($0.username) == nil }
    }

    public func workspaceUserFor(_ username: String) -> WorkspaceUser? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return workspaceUsers.first { $0.username == u }
    }

    public func knownUsername(_ username: String) -> Bool {
        let u = canonicalLoginUsername(username)
        return demoAccountFor(u) != nil || workspaceUserFor(u) != nil
    }

    public func accountFor(_ username: String) -> AuthUser? {
        if let demo = demoAccountFor(username) { return AuthUser.demo(demo.username) }
        let u = canonicalLoginUsername(username)
        guard let custom = workspaceUserFor(u) else { return nil }
        return AuthUser(username: custom.username, name: custom.name.isEmpty ? custom.username : custom.name, role: custom.role, email: custom.email, phone: custom.phone, title: custom.title)
    }

    private func roleCanOpen(_ role: String?, _ slug: String) -> Bool {
        canAccessModule(role, slug, definition: roleOf(role))
    }

    @discardableResult
    public func login(_ username: String, _ password: String, departmentId: String? = nil) -> String? {
        guard let nextUser = accountFor(username) else { return "Unknown user." }
        let u = nextUser.username.lowercased()
        if passwords[u]?.isEmpty != false {
            return "No password set. Use Forgot password to create one."
        }
        if !passwordMatches(u, password) { return "Wrong password." }
        return adoptUser(nextUser, departmentId: departmentId)
    }

    /// Offline trial: saves the typed password on this phone, then signs in locally.
    @discardableResult
    public func loginOnThisDevice(_ username: String, _ password: String, departmentId: String? = nil) -> String? {
        let missing = login(username, password, departmentId: departmentId)
        if missing == "No password set. Use Forgot password to create one." || missing == "Wrong password." {
            if let err = resetPassword(username: username, newPassword: password, confirm: password) {
                return err
            }
            return login(username, password, departmentId: departmentId)
        }
        return missing
    }

    @discardableResult
    public func loginAsync(_ username: String, _ password: String, departmentId: String? = nil) async -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let api else { return login(u, password, departmentId: departmentId) }
        lastRemoteError = nil
        let remote = await api.login(username: u, password: password, keepSignedIn: true)
        switch remote {
        case .success(let session):
            let adopted = applyRemoteSession(session, departmentId: departmentId)
            await refreshDirectory()
            upsertRoleFromRemoteUser(session.user)
            persist()
            notify()
            await refreshApprovals()
            return adopted
        case .failure(let error) where error.isNetwork:
            lastRemoteError = error.message
            if passwords[canonicalLoginUsername(u)]?.isEmpty == false {
                return login(u, password, departmentId: departmentId)
            }
            return error.message
        case .failure(let error):
            lastRemoteError = error.message
            if error.isUnauthorized {
                return ErpStore.describeLiveLoginFailure(password: password, apiMessage: error.message)
            }
            return error.message
        }
    }

    /// Live accounts must use the web ERP password. The old 7-character demo
    /// password is rejected by Postgres after the first forced change.
    public static func describeLiveLoginFailure(password: String, apiMessage: String) -> String {
        if password.count < 10 {
            return "Live sign-in needs your web ERP password (10+ characters). Tap Continue on this device to try the app here."
        }
        return apiMessage
    }

    public func resumeRemoteSession() async {
        guard let api, remoteSession, !apiToken.isEmpty else { return }
        api.token = apiToken
        switch await api.me() {
        case .success(let remoteUser):
            user = remoteUser.authUser
            persist()
            notify()
            await refreshDirectory()
            upsertRoleFromRemoteUser(remoteUser)
            persist()
            notify()
            await refreshApprovals()
        case .failure(let error) where error.isUnauthorized:
            clearRemoteSession()
            user = nil
            activeDepartmentId = nil
            activeAppId = nil
            persist()
            notify()
        case .failure(let error):
            lastRemoteError = error.message
            notify()
        }
    }

    public func setFrontendOrigin(_ origin: String) {
        let next = ErpConfig.sanitizeOrigin(origin)
        ErpConfig.saveOrigin(next, to: persistence)
        api?.origin = next.isEmpty ? ErpConfig.liveFrontendOrigin : next
        notify()
    }

    public func refreshEntity(_ moduleId: String, _ entity: String) async {
        guard let api, remoteSession else { return }
        let target = apiStorageTarget(moduleId: moduleId, entity: entity)
        switch await api.getRecords(module: target.module, entity: target.entity) {
        case .failure(let error):
            lastRemoteError = error.message
            notify()
        case .success(let rows):
            let mapped = rows.map { recordFromApi($0, moduleId: moduleId, entity: entity) }
            let oldIds = records.filter { $0.moduleId == moduleId && $0.entity == entity }.map(\.id)
            knownRemoteIds.subtract(oldIds)
            records.removeAll { $0.moduleId == moduleId && $0.entity == entity }
            records.insert(contentsOf: mapped, at: 0)
            knownRemoteIds.formUnion(mapped.map(\.id))
            persist()
            notify()
        }
    }

    public func refreshDirectory() async {
        guard let api, remoteSession else { return }
        if case .success(let rows) = await api.listRoles() {
            roles = adoptApiRoles(rows.map(RoleDefinition.fromJSON))
            persist()
            notify()
        }
        guard isAdmin else { return }
        if case .success(let rows) = await api.listUsers() {
            workspaceUsers = rows.compactMap(workspaceUserFromApi)
            persist()
            notify()
        }
    }

    private func upsertRoleFromRemoteUser(_ remote: ErpRemoteUser) {
        let name = remote.role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var next = findRoleDefinition(roles, name) ?? RoleDefinition(
            id: remote.roleId.isEmpty ? newRoleId() : remote.roleId,
            name: name,
            description: "Workspace role",
            crud: remote.crud ?? .none,
            system: isAdminRole(name) || isBuiltInRoleName(name),
            pagePermissions: remote.pagePermissions
        )
        if !remote.roleId.isEmpty { next.id = remote.roleId }
        if let crud = remote.crud { next.crud = crud }
        if !remote.pagePermissions.isEmpty { next.pagePermissions = remote.pagePermissions }
        if let idx = roles.firstIndex(where: { normalizeRole($0.name) == normalizeRole(name) }) {
            roles[idx] = next
        } else {
            roles.append(next)
        }
    }

    public func refreshApprovals() async {
        guard let api, remoteSession else { return }
        switch await api.approvalDesk() {
        case .failure(let error):
            lastRemoteError = error.message
            notify()
        case .success(let data):
            let items = (data["items"] as? [[String: Any]]) ?? []
            for item in items {
                mergeApprovalItem(item)
            }
            persist()
            notify()
        }
    }

    @discardableResult
    public func requestFrontendPasswordReset(_ username: String) async -> Result<String, ErpApiError> {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let api else {
            return .failure(.network("Can't send a reset email right now."))
        }
        return await api.requestPasswordReset(username: u)
    }

    private func applyRemoteSession(_ session: ErpRemoteSession, departmentId: String?) -> String? {
        api?.token = session.token
        apiToken = session.token
        remoteSession = true
        lastRemoteError = nil
        records.removeAll()
        knownRemoteIds.removeAll()
        let adopted = adoptUser(session.user.authUser, departmentId: departmentId)
        return adopted
    }

    private func clearRemoteSession() {
        apiToken = ""
        remoteSession = false
        api?.token = nil
        lastRemoteError = nil
    }

    private func pushRemote(_ record: ErpRecord, remove: Bool = false) {
        guard let api, remoteSession else { return }
        let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
        let payload = apiPayload(from: record)
        let known = knownRemoteIds.contains(record.id)
        Task { [weak self] in
            if remove {
                switch await api.deleteRecord(module: target.module, entity: target.entity, id: record.id) {
                case .success:
                    await MainActor.run { [weak self] in
                        self?.knownRemoteIds.remove(record.id)
                    }
                case .failure(let error):
                    let message = error.message
                    await MainActor.run { [weak self] in
                        self?.noteRemoteError(message)
                    }
                }
                return
            }
            if known {
                switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
                case .success(let row):
                    await MainActor.run { [weak self] in
                        self?.adoptRemoteRow(row, replacing: record)
                    }
                case .failure(let error) where error.isNotFound:
                    switch await api.createRecord(module: target.module, entity: target.entity, record: payload) {
                    case .success(let row):
                        await MainActor.run { [weak self] in
                            self?.adoptRemoteRow(row, replacing: record)
                        }
                    case .failure(let created):
                        let message = created.message
                        await MainActor.run { [weak self] in
                            self?.noteRemoteError(message)
                        }
                    }
                case .failure(let error):
                    let message = error.message
                    await MainActor.run { [weak self] in
                        self?.noteRemoteError(message)
                    }
                }
            } else {
                switch await api.createRecord(module: target.module, entity: target.entity, record: payload) {
                case .success(let row):
                    await MainActor.run { [weak self] in
                        self?.adoptRemoteRow(row, replacing: record)
                    }
                case .failure(let error) where error.isConflict:
                    switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
                    case .success(let row):
                        await MainActor.run { [weak self] in
                            self?.adoptRemoteRow(row, replacing: record)
                        }
                    case .failure(let patched):
                        let message = patched.message
                        await MainActor.run { [weak self] in
                            self?.noteRemoteError(message)
                        }
                    }
                case .failure(let error):
                    let message = error.message
                    await MainActor.run { [weak self] in
                        self?.noteRemoteError(message)
                    }
                }
            }
        }
    }

    private func adoptRemoteRow(_ row: [String: Any], replacing record: ErpRecord) {
        let mapped = recordFromApi(row, moduleId: record.moduleId, entity: record.entity)
        record.title = mapped.title
        record.subtitle = mapped.subtitle
        record.status = mapped.status
        record.date = mapped.date
        record.amount = mapped.amount
        record.fields = mapped.fields
        knownRemoteIds.insert(record.id)
        if mapped.id != record.id {
            if let idx = records.firstIndex(where: { $0.id == record.id }) {
                records[idx] = mapped
            }
            knownRemoteIds.remove(record.id)
            knownRemoteIds.insert(mapped.id)
        }
        persist()
        notify()
    }

    private func mergeApprovalItem(_ item: [String: Any]) {
        let id = jsonText(item["id"]) ?? ""
        guard !id.isEmpty else { return }
        let moduleId = jsonText(item["module"]) ?? ""
        let entityKey = jsonText(item["entity"]) ?? ""
        let payload = (item["record"] as? [String: Any]) ?? item
        if let existing = records.first(where: { $0.id == id }) {
            adoptRemoteRow(payload, replacing: existing)
            if let status = jsonText(item["status"]), !status.isEmpty { existing.status = status }
            return
        }
        guard !moduleId.isEmpty else { return }
        let entity = records.first(where: { $0.moduleId == moduleId && apiEntityKey($0.entity) == entityKey })?.entity
            ?? moduleById(moduleId)?.entities.first { apiEntityKey($0) == entityKey }
            ?? entityKey
        let mapped = recordFromApi(payload, moduleId: moduleId, entity: entity)
        records.insert(mapped, at: 0)
        knownRemoteIds.insert(mapped.id)
    }

    private func workspaceUserFromApi(_ row: [String: Any]) -> WorkspaceUser? {
        let username = (jsonText(row["username"]) ?? jsonText(row["email"]) ?? "").lowercased()
        guard !username.isEmpty, demoAccountFor(username) == nil else { return nil }
        return WorkspaceUser(
            username: username,
            name: jsonText(row["name"]) ?? username,
            role: jsonText(row["role"]) ?? "Viewer",
            title: jsonText(row["title"]) ?? "",
            email: jsonText(row["email"]) ?? "",
            phone: jsonText(row["phone"]) ?? ""
        )
    }

    private func jsonText(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return "\(value)"
    }

    private func noteRemoteError(_ message: String) {
        lastRemoteError = message
        notify()
    }

    @discardableResult
    private func adoptUser(_ nextUser: AuthUser, departmentId: String?) -> String? {
        let requested = departmentId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let def = findRoleDefinition(roles, nextUser.role)
        var nextApp: String?
        var nextDept: String?
        if let requested, !requested.isEmpty {
            if suiteAppById(requested) != nil {
                if !canOpenSuiteApp(nextUser.role, requested, definition: def) { return "Your role cannot open that app." }
                nextApp = requested
            } else if moduleById(requested) != nil {
                if !roleCanOpen(nextUser.role, requested) { return "Your role cannot open that app." }
                nextApp = suiteAppContaining(requested)?.id
                nextDept = requested
            } else {
                return "Unknown department."
            }
        }
        if nextApp == nil {
            let homeApp = defaultSuiteAppForRole(nextUser.role)
            if let homeApp, canOpenSuiteApp(nextUser.role, homeApp, definition: def) {
                nextApp = homeApp
            } else {
                let visible = suiteApps.filter { canOpenSuiteApp(nextUser.role, $0.id, definition: def) }
                if visible.count == 1 { nextApp = visible[0].id }
            }
        }
        if nextDept == nil, let nextApp, let app = suiteAppById(nextApp) {
            nextDept = app.moduleIds.first { roleCanOpen(nextUser.role, $0) }
        }
        if nextDept == nil {
            let home = defaultDepartmentForRole(nextUser.role)
            if let home, moduleById(home) != nil, roleCanOpen(nextUser.role, home) {
                nextDept = home
                if nextApp == nil { nextApp = suiteAppContaining(home)?.id }
            }
        }
        user = nextUser
        activeAppId = nextApp
        activeDepartmentId = nextDept
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func resetPassword(username: String, newPassword: String, confirm: String) -> String? {
        let u = canonicalLoginUsername(username)
        if !knownUsername(u) { return "Unknown user." }
        if newPassword.count < 6 { return "Use at least 6 characters." }
        if newPassword != confirm { return "Passwords do not match." }
        passwords[u] = passwordDigest(u, newPassword)
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func updateProfile(name: String, email: String, phone: String, title: String) -> String? {
        guard let current = user else { return "Sign in to edit your profile." }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name is required." }
        user = AuthUser(username: current.username, name: trimmed, role: current.role, email: email.trimmingCharacters(in: .whitespacesAndNewlines), phone: phone.trimmingCharacters(in: .whitespacesAndNewlines), title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        if let idx = workspaceUsers.firstIndex(where: { $0.username == current.username }) {
            let row = workspaceUsers[idx]
            workspaceUsers[idx] = WorkspaceUser(username: row.username, name: trimmed, role: row.role, title: title.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines), phone: phone.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func updateProfileAsync(name: String, email: String, phone: String, title: String) async -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name is required." }
        if let api, remoteSession {
            switch await api.updateProfile(name: trimmed, email: email, phone: phone, title: title) {
            case .success(let remote):
                let current = user
                user = AuthUser(
                    username: current?.username ?? remote.username,
                    name: remote.name.isEmpty ? trimmed : remote.name,
                    role: remote.role.isEmpty ? (current?.role ?? "Viewer") : remote.role,
                    email: remote.email.isEmpty ? email : remote.email,
                    phone: remote.phone.isEmpty ? phone : remote.phone,
                    title: remote.title.isEmpty ? title : remote.title
                )
                persist()
                notify()
                return nil
            case .failure(let error):
                return error.message
            }
        }
        return updateProfile(name: name, email: email, phone: phone, title: title)
    }

    public func setThemeMode(_ mode: String) {
        themeMode = mode
        persist()
        notify()
    }

    public func openApp(_ appId: String) {
        guard canOpenSuiteApp(roleName, appId, definition: currentRole) else { return }
        activeAppId = appId
        if let app = suiteAppById(appId) {
            activeDepartmentId = app.moduleIds.first { canOpen($0) }
        }
        persist()
        notify()
    }

    public func closeApp() {
        activeAppId = nil
        persist()
        notify()
    }

    public func setActiveDepartment(_ departmentId: String?) {
        let dept = departmentId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if dept == nil || dept?.isEmpty == true || moduleById(dept ?? "") == nil {
            activeDepartmentId = nil
        } else if let user, !roleCanOpen(user.role, dept!) {
            return
        } else {
            activeDepartmentId = dept
            if let app = suiteAppContaining(dept!) { activeAppId = app.id }
        }
        persist()
        notify()
    }

    private func enforceAccess() {
        guard let current = user else { return }
        if let appId = activeAppId, !canOpenSuiteApp(current.role, appId, definition: roleOf(current.role)) {
            activeAppId = defaultSuiteAppForRole(current.role)
        }
        if let dept = activeDepartmentId, moduleById(dept) != nil && roleCanOpen(current.role, dept) {
            if activeAppId == nil { activeAppId = suiteAppContaining(dept)?.id }
            return
        }
        let home = defaultDepartmentForRole(current.role)
        activeDepartmentId = (home != nil && moduleById(home!) != nil && roleCanOpen(current.role, home!)) ? home : nil
        if activeAppId == nil, let dept = activeDepartmentId {
            activeAppId = suiteAppContaining(dept)?.id
        }
    }

    public func logout() {
        let remote = api
        let hadRemote = remoteSession
        user = nil
        activeDepartmentId = nil
        activeAppId = nil
        clearRemoteSession()
        persist()
        notify()
        if hadRemote, let remote {
            Task { await remote.logout() }
        }
    }

    public func setSearch(_ q: String) {
        search = q
        notify()
    }

    public func setStatus(_ record: ErpRecord, _ status: String) {
        record.status = status
        persist()
        notify()
        let chainAdvance = ErpAPI.isChainEntity(record.entity) && !isDraftStatus(status) && status.lowercased() != "submitted" && status.lowercased() != "posted"
        if !chainAdvance { pushRemote(record) }
    }

    public func addRecord(_ record: ErpRecord) {
        if let user, !canCreateEntity(user.role, record.moduleId, record.entity, definition: currentRole) { return }
        insertRecord(record)
    }

    private func insertRecord(_ record: ErpRecord) {
        records.insert(record, at: 0)
        persist()
        notify()
        pushRemote(record)
    }

    @discardableResult
    public func submitRecord(_ record: ErpRecord) -> String? {
        if let err = submitGate(record) { return err }
        setStatus(record, approvalEntities.contains(record.entity) ? "Submitted" : "Posted")
        return nil
    }

    @discardableResult
    public func submitRecordAsync(_ record: ErpRecord) async -> String? {
        if let err = submitGate(record) { return err }
        let next = approvalEntities.contains(record.entity) ? "Submitted" : "Posted"
        if let api, remoteSession {
            var payload = apiPayload(from: record)
            payload["status"] = next
            let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
            switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
            case .success(let row):
                adoptRemoteRow(row, replacing: record)
                record.status = jsonText(row["status"]) ?? next
                persist()
                notify()
                return nil
            case .failure(let error) where error.isNotFound:
                return submitRecord(record)
            case .failure(let error):
                return error.message
            }
        }
        return submitRecord(record)
    }

    @discardableResult
    public func approveRecord(_ record: ErpRecord) -> String? {
        if let err = approvalGate(record) { return err }
        setStatus(record, "Approved")
        return nil
    }

    @discardableResult
    public func approveRecordAsync(_ record: ErpRecord, comment: String = "") async -> String? {
        if let err = approvalGate(record) { return err }
        if let api, remoteSession {
            if ErpAPI.isChainEntity(record.entity) {
                switch await api.approvalAction(entity: apiEntityKey(record.entity), id: record.id, action: "advance", comment: comment) {
                case .success(let row):
                    applyApprovalPayload(row, onto: record)
                    persist()
                    notify()
                    return nil
                case .failure(let error):
                    return error.message
                }
            }
            var payload = apiPayload(from: record)
            payload["status"] = "Approved"
            let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
            switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
            case .success(let row):
                adoptRemoteRow(row, replacing: record)
                return nil
            case .failure(let error):
                return error.message
            }
        }
        return approveRecord(record)
    }

    @discardableResult
    public func rejectRecord(_ record: ErpRecord) -> String? {
        if let err = approvalGate(record) { return err }
        setStatus(record, "Rejected")
        return nil
    }

    @discardableResult
    public func rejectRecordAsync(_ record: ErpRecord, comment: String = "Rejected from IAG Central.") async -> String? {
        if let err = approvalGate(record) { return err }
        let reason = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Rejected from IAG Central." : comment
        if let api, remoteSession {
            if ErpAPI.isChainEntity(record.entity) {
                switch await api.approvalAction(entity: apiEntityKey(record.entity), id: record.id, action: "reject", comment: reason) {
                case .success(let row):
                    applyApprovalPayload(row, onto: record)
                    persist()
                    notify()
                    return nil
                case .failure(let error):
                    return error.message
                }
            }
            var payload = apiPayload(from: record)
            payload["status"] = "Rejected"
            let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
            switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
            case .success(let row):
                adoptRemoteRow(row, replacing: record)
                return nil
            case .failure(let error):
                return error.message
            }
        }
        return rejectRecord(record)
    }

    @discardableResult
    public func voidRecord(_ record: ErpRecord) -> String? {
        if let err = voidGate(record) { return err }
        setStatus(record, "Void")
        return nil
    }

    @discardableResult
    public func voidRecordAsync(_ record: ErpRecord) async -> String? {
        if let err = voidGate(record) { return err }
        if let api, remoteSession {
            var payload = apiPayload(from: record)
            payload["status"] = "Void"
            let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
            switch await api.patchRecord(module: target.module, entity: target.entity, id: record.id, record: payload) {
            case .success(let row):
                adoptRemoteRow(row, replacing: record)
                return nil
            case .failure(let error):
                return error.message
            }
        }
        return voidRecord(record)
    }

    @discardableResult
    public func deleteRecord(_ record: ErpRecord) -> String? {
        if !canDeleteEntity(roleName, record.moduleId, record.entity, definition: currentRole) {
            return "Your role cannot delete records here."
        }
        records.removeAll { $0.id == record.id }
        persist()
        notify()
        pushRemote(record, remove: true)
        return nil
    }

    @discardableResult
    public func deleteRecordAsync(_ record: ErpRecord) async -> String? {
        if !canDeleteEntity(roleName, record.moduleId, record.entity, definition: currentRole) {
            return "Your role cannot delete records here."
        }
        if let api, remoteSession {
            let target = apiStorageTarget(moduleId: record.moduleId, entity: record.entity)
            switch await api.deleteRecord(module: target.module, entity: target.entity, id: record.id) {
            case .success:
                records.removeAll { $0.id == record.id }
                knownRemoteIds.remove(record.id)
                persist()
                notify()
                return nil
            case .failure(let error):
                return error.message
            }
        }
        return deleteRecord(record)
    }

    private func submitGate(_ record: ErpRecord) -> String? {
        guard user != nil else { return "Sign in first." }
        if !canCreateEntity(user?.role, record.moduleId, record.entity, definition: currentRole) &&
            !canEditEntity(user?.role, record.moduleId, record.entity, definition: currentRole) {
            return "Your role cannot submit this record."
        }
        if !isDraftStatus(record.status) { return "Only drafts can be submitted." }
        return nil
    }

    private func approvalGate(_ record: ErpRecord) -> String? {
        if !canApproveIn(roleName, record.moduleId, definition: currentRole) {
            return "Your role has no approval desk for this app."
        }
        if !approvalEntities.contains(record.entity) || !isOpenStatus(record.status) {
            return "This record is not waiting for approval."
        }
        return nil
    }

    private func voidGate(_ record: ErpRecord) -> String? {
        if !canVoidIn(roleName, record.moduleId, definition: currentRole) {
            return "Your role cannot void records here."
        }
        if isDraftStatus(record.status) || isVoidedStatus(record.status) {
            return "This record cannot be voided."
        }
        if !isApprovedStatus(record.status) {
            return "Only posted, paid, or approved records can be voided."
        }
        return nil
    }

    private func applyApprovalPayload(_ json: [String: Any], onto record: ErpRecord) {
        if let rec = json["record"] as? [String: Any] {
            adoptRemoteRow(rec, replacing: record)
        }
        if let status = jsonText(json["status"]), !status.isEmpty {
            record.status = status
        }
    }

    @discardableResult
    public func saveRole(_ role: RoleDefinition) -> String? {
        if !isAdmin { return "Only administrators can manage roles." }
        let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Role name is required." }
        if isAdminRole(name) || isBuiltInRoleName(name) { return "That name is a built-in role." }
        if role.system { return "Built-in roles cannot be changed." }
        let key = normalizeRole(name)
        if roles.contains(where: { $0.id != role.id && normalizeRole($0.name) == key }) {
            return "A role with that name already exists."
        }
        let next = RoleDefinition(
            id: role.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? newRoleId() : role.id,
            name: name,
            description: role.description.trimmingCharacters(in: .whitespacesAndNewlines),
            crud: role.crud,
            system: false,
            pagePermissions: role.pagePermissions
        )
        if let idx = roles.firstIndex(where: { $0.id == next.id }) {
            roles[idx] = next
        } else {
            roles.append(next)
        }
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func deleteRole(_ id: String) -> String? {
        if !isAdmin { return "Only administrators can manage roles." }
        guard let role = roles.first(where: { $0.id == id }) else { return "Role not found." }
        if role.system { return "Built-in roles cannot be deleted." }
        if workspaceUsers.contains(where: { normalizeRole($0.role) == normalizeRole(role.name) }) {
            return "Reassign users on this role first."
        }
        roles.removeAll { $0.id == id }
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func saveWorkspaceUser(username: String, name: String, role: String, title: String = "", email: String = "", phone: String = "", password: String? = nil) -> String? {
        if !isAdmin { return "Only administrators can manage users." }
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.isEmpty || u.range(of: "^[a-z0-9._-]{3,32}$", options: .regularExpression) == nil {
            return "Use 3–32 letters, numbers, dots, or dashes."
        }
        if demoAccountFor(u) != nil { return "That username is reserved." }
        if roleOf(role) == nil { return "Unknown role." }
        if isAdminRole(role) { return "Use the built-in admin accounts." }
        if let password, !password.isEmpty, password.count < 6 { return "Use at least 6 characters." }
        let row = WorkspaceUser(
            username: u,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? u : name.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if let idx = workspaceUsers.firstIndex(where: { $0.username == u }) {
            workspaceUsers[idx] = row
        } else {
            workspaceUsers.append(row)
        }
        if let password, !password.isEmpty { storePassword(u, password) }
        if user?.username == u {
            user = AuthUser(username: row.username, name: row.name, role: row.role, email: row.email, phone: row.phone, title: row.title)
        }
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func deleteWorkspaceUser(_ username: String) -> String? {
        if !isAdmin { return "Only administrators can manage users." }
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if user?.username == u { return "You cannot delete the signed-in user." }
        if demoAccountFor(u) != nil { return "Built-in users cannot be deleted." }
        if workspaceUserFor(u) == nil { return "User not found." }
        workspaceUsers.removeAll { $0.username != u ? false : true }
        passwords.removeValue(forKey: u)
        persist()
        notify()
        return nil
    }

    private func seed() -> [ErpRecord] { completeCatalogSeed(modules) }

    private func mergeMissingCatalogRecords() {
        let have = Set(records.map { "\($0.moduleId)|\($0.entity)" })
        var extras: [ErpRecord] = []
        for module in modules {
            for entity in module.entities {
                let key = "\(module.id)|\(entity)"
                if have.contains(key) { continue }
                extras.append(sampleRecord(module: module, entity: entity))
            }
        }
        if extras.isEmpty { return }
        records = extras + records
        persist()
    }
}
