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
    public private(set) var themeMode: String = "system"
    private var passwords: [String: String] = [:]

    public init(modules: [ErpModule] = erpModules(), persistence: KeyValueStore = MemoryKeyValueStore()) {
        self.modules = modules
        self.persistence = persistence
    }

    public var isSignedIn: Bool { user != nil }
    public var roleName: String? { user?.role }
    public var isAdmin: Bool { isAdminRole(roleName) }
    public var currentRole: RoleDefinition? { roleOf(roleName) }
    public var kpis: [Kpi] { defaultKpis }
    public var visibleModules: [ErpModule] { modules.filter { canAccessModule(roleName, $0.id, definition: currentRole) } }
    public var visibleWorkspaceTools: [WorkspaceTool] {
        workspaceTools.filter { canAccessSpecialNav(roleName, $0.id, definition: currentRole) }
    }
    public var approvalEntities: Set<String> { Set(modules.flatMap(\.approvalEntities)) }
    public var canApprove: Bool { canAccessApprovalDesk(roleName) }
    public var customRoles: [RoleDefinition] { roles.filter { !$0.system } }
    public var pendingApprovals: [ErpRecord] { pendingApprovalsFor(nil) }
    public var recent: [ErpRecord] { Array(records.prefix(8)) }
    public var accountingDocuments: [ErpRecord] {
        let needles = ["invoice", "quote", "order", "note", "receipt", "payment", "payslip", "journal", "transfer", "claim", "request"]
        return records.filter { rec in
            canOpen(rec.moduleId) && needles.contains { rec.entity.lowercased().contains($0) }
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
        for module in visibleModules {
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
            if rec.title.lowercased().contains(q) || rec.subtitle.lowercased().contains(q) || rec.entity.lowercased().contains(q) {
                hits.append(SearchHit(kind: .record, title: rec.title, subtitle: "\(rec.entity) · \(rec.status)", moduleId: rec.moduleId, entity: rec.entity, recordId: rec.id))
            }
            if hits.count >= 40 { break }
        }
        return Array(hits.prefix(30))
    }

    public var canClockIn: Bool { user != nil && crudForRole(roleName, definition: currentRole).view }

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
    public func passwordFor(_ username: String) -> String { passwords[username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? demoPassword }
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
        let dept = j["activeDepartmentId"] as? String
        activeDepartmentId = (dept?.isEmpty ?? true) || moduleById(dept ?? "") == nil ? nil : dept
        if let pw = j["passwords"] as? [String: Any] {
            passwords = Dictionary(uniqueKeysWithValues: pw.map { ($0.key.lowercased(), "\($0.value)") })
        }
        readAccessLists(j)
        if let rows = j["records"] as? [[String: Any]] {
            records = rows.map(ErpRecord.fromJSON)
        }
        if records.isEmpty { records = seed() }
        mergeMissingCatalogRecords()
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
        if JSONSerialization.isValidJSONObject(json),
           let data = try? JSONSerialization.data(withJSONObject: json),
           let raw = String(data: data, encoding: .utf8) {
            persistence.put(storeKey, raw)
        }
    }

    private func readAccessLists(_ j: [String: Any]) {
        let stored = (j["roles"] as? [[String: Any]] ?? []).map(RoleDefinition.fromJSON)
        roles = mergeStoredRoles(stored)
        workspaceUsers = (j["workspaceUsers"] as? [[String: Any]] ?? [])
            .map(WorkspaceUser.fromJSON)
            .filter { !$0.username.isEmpty && demoAccountFor($0.username) == nil }
    }

    public func workspaceUserFor(_ username: String) -> WorkspaceUser? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return workspaceUsers.first { $0.username == u }
    }

    public func knownUsername(_ username: String) -> Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return demoAccountFor(u) != nil || workspaceUserFor(u) != nil
    }

    public func accountFor(_ username: String) -> AuthUser? {
        if let demo = demoAccountFor(username) { return AuthUser.demo(demo.username) }
        guard let custom = workspaceUserFor(username) else { return nil }
        return AuthUser(username: custom.username, name: custom.name.isEmpty ? custom.username : custom.name, role: custom.role, email: custom.email, phone: custom.phone, title: custom.title)
    }

    private func roleCanOpen(_ role: String?, _ slug: String) -> Bool {
        canAccessModule(role, slug, definition: roleOf(role))
    }

    @discardableResult
    public func login(_ username: String, _ password: String, departmentId: String? = nil) -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let nextUser = accountFor(u) else { return "Unknown user." }
        if password != passwordFor(u) { return "Wrong password." }
        let dept = departmentId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dept, !dept.isEmpty, moduleById(dept) == nil { return "Unknown department." }
        var nextDept = (dept?.isEmpty ?? true) ? nil : dept
        if let nextDept, !roleCanOpen(nextUser.role, nextDept) { return "Your role cannot open that app." }
        if nextDept == nil {
            let home = defaultDepartmentForRole(nextUser.role)
            if let home, moduleById(home) != nil, roleCanOpen(nextUser.role, home) {
                nextDept = home
            } else {
                let visible = modules.filter { roleCanOpen(nextUser.role, $0.id) }.map(\.id)
                if visible.count == 1 { nextDept = visible[0] }
            }
        }
        user = nextUser
        activeDepartmentId = nextDept
        persist()
        notify()
        return nil
    }

    @discardableResult
    public func resetPassword(username: String, newPassword: String, confirm: String) -> String? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !knownUsername(u) { return "Unknown user." }
        if newPassword.count < 6 { return "Use at least 6 characters." }
        if newPassword != confirm { return "Passwords do not match." }
        passwords[u] = newPassword
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

    public func setThemeMode(_ mode: String) {
        themeMode = mode
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
        }
        persist()
        notify()
    }

    private func enforceAccess() {
        guard let current = user, let dept = activeDepartmentId else { return }
        if moduleById(dept) != nil && roleCanOpen(current.role, dept) { return }
        let home = defaultDepartmentForRole(current.role)
        activeDepartmentId = (home != nil && moduleById(home!) != nil && roleCanOpen(current.role, home!)) ? home : nil
    }

    public func logout() {
        user = nil
        activeDepartmentId = nil
        persist()
        notify()
    }

    public func setSearch(_ q: String) {
        search = q
        notify()
    }

    public func setStatus(_ record: ErpRecord, _ status: String) {
        record.status = status
        persist()
        notify()
    }

    public func addRecord(_ record: ErpRecord) {
        if let user, !canCreateEntity(user.role, record.moduleId, record.entity, definition: currentRole) { return }
        insertRecord(record)
    }

    private func insertRecord(_ record: ErpRecord) {
        records.insert(record, at: 0)
        persist()
        notify()
    }

    @discardableResult
    public func submitRecord(_ record: ErpRecord) -> String? {
        guard user != nil else { return "Sign in first." }
        if !canCreateEntity(user?.role, record.moduleId, record.entity, definition: currentRole) &&
            !canEditEntity(user?.role, record.moduleId, record.entity, definition: currentRole) {
            return "Your role cannot submit this record."
        }
        if !isDraftStatus(record.status) { return "Only drafts can be submitted." }
        setStatus(record, approvalEntities.contains(record.entity) ? "Submitted" : "Posted")
        return nil
    }

    @discardableResult
    public func approveRecord(_ record: ErpRecord) -> String? {
        if !canApproveIn(roleName, record.moduleId, definition: currentRole) {
            return "Your role has no approval desk for this app."
        }
        if !approvalEntities.contains(record.entity) || !isOpenStatus(record.status) {
            return "This record is not waiting for approval."
        }
        setStatus(record, "Approved")
        return nil
    }

    @discardableResult
    public func rejectRecord(_ record: ErpRecord) -> String? {
        if !canApproveIn(roleName, record.moduleId, definition: currentRole) {
            return "Your role has no approval desk for this app."
        }
        if !approvalEntities.contains(record.entity) || !isOpenStatus(record.status) {
            return "This record is not waiting for approval."
        }
        setStatus(record, "Rejected")
        return nil
    }

    @discardableResult
    public func voidRecord(_ record: ErpRecord) -> String? {
        if !canVoidIn(roleName, record.moduleId, definition: currentRole) {
            return "Your role cannot void records here."
        }
        if isDraftStatus(record.status) || isVoidedStatus(record.status) {
            return "This record cannot be voided."
        }
        if !isApprovedStatus(record.status) {
            return "Only posted, paid, or approved records can be voided."
        }
        setStatus(record, "Void")
        return nil
    }

    @discardableResult
    public func deleteRecord(_ record: ErpRecord) -> String? {
        if !canDeleteEntity(roleName, record.moduleId, record.entity, definition: currentRole) {
            return "Your role cannot delete records here."
        }
        records.removeAll { $0.id == record.id }
        persist()
        notify()
        return nil
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
        if let password, !password.isEmpty { passwords[u] = password }
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
