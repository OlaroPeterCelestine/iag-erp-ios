import Foundation

public struct Crud: Equatable, Sendable {
    public var view: Bool
    public var create: Bool
    public var edit: Bool
    public var delete: Bool

    public init(view: Bool, create: Bool, edit: Bool, delete: Bool) {
        self.view = view
        self.create = create
        self.edit = edit
        self.delete = delete
    }

    public var any: Bool { view || create || edit || delete }

    public static let none = Crud(view: false, create: false, edit: false, delete: false)
    public static let full = Crud(view: true, create: true, edit: true, delete: true)

    public func toFlags() -> [String: String] {
        [
            "canView": view ? "Yes" : "No",
            "canCreate": create ? "Yes" : "No",
            "canEdit": edit ? "Yes" : "No",
            "canDelete": delete ? "Yes" : "No",
        ]
    }

    public static func fromFlags(_ flags: [String: Any]?) -> Crud {
        func yes(_ value: Any?) -> Bool {
            NSRegularExpression.yesMatch("\(value ?? "No")")
        }
        return Crud(
            view: yes(flags?["canView"]),
            create: yes(flags?["canCreate"]),
            edit: yes(flags?["canEdit"]),
            delete: yes(flags?["canDelete"])
        )
    }
}

private extension NSRegularExpression {
    static func yesMatch(_ value: String) -> Bool {
        value.range(of: "^yes$", options: [.regularExpression, .caseInsensitive]) != nil
    }
}

public let pageWildcardKey = "*"

public struct RoleDefinition: Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var crud: Crud
    public var system: Bool
    public var pagePermissions: [String: Crud]

    public init(
        id: String,
        name: String,
        description: String = "",
        crud: Crud = .none,
        system: Bool = false,
        pagePermissions: [String: Crud] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.crud = crud
        self.system = system
        self.pagePermissions = pagePermissions
    }

    public var restrictToGrantedApps: Bool { pagePermissions[pageWildcardKey] != nil }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "id": id,
            "name": name,
            "description": description,
            "system": system,
            "canView": crud.toFlags()["canView"] as Any,
            "canCreate": crud.toFlags()["canCreate"] as Any,
            "canEdit": crud.toFlags()["canEdit"] as Any,
            "canDelete": crud.toFlags()["canDelete"] as Any,
        ]
        json["pagePermissions"] = pagePermissions.mapValues { $0.toFlags() }
        return json
    }

    public static func fromJSON(_ j: [String: Any]) -> RoleDefinition {
        var pages: [String: Crud] = [:]
        if let raw = j["pagePermissions"] as? [String: Any] {
            for (key, value) in raw {
                pages[key] = Crud.fromFlags(value as? [String: Any])
            }
        }
        let id = (j["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return RoleDefinition(
            id: id.isEmpty ? newRoleId() : id,
            name: (j["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            description: (j["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            crud: Crud.fromFlags(j),
            system: j["system"] as? Bool ?? false,
            pagePermissions: pages
        )
    }
}

public struct WorkspaceUser: Equatable, Sendable {
    public var username: String
    public var name: String
    public var role: String
    public var title: String
    public var email: String
    public var phone: String

    public init(username: String, name: String, role: String, title: String = "", email: String = "", phone: String = "") {
        self.username = username
        self.name = name
        self.role = role
        self.title = title
        self.email = email
        self.phone = phone
    }

    public func toJSON() -> [String: Any] {
        ["username": username, "name": name, "role": role, "title": title, "email": email, "phone": phone]
    }

    public static func fromJSON(_ j: [String: Any]) -> WorkspaceUser {
        WorkspaceUser(
            username: ((j["username"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            name: ((j["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            role: ((j["role"] as? String) ?? "Viewer").trimmingCharacters(in: .whitespacesAndNewlines),
            title: ((j["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            email: ((j["email"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            phone: ((j["phone"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public func newRoleId() -> String { "role-\(DispatchTime.now().uptimeNanoseconds)" }

public let builtInRoleCatalog: [(String, String)] = [
    ("Administrator", "Full CRUD across the workspace."),
    ("Super Admin", "Full system access — same as Administrator."),
    ("Quantity Surveyor", "QS desk on the material path."),
    ("Project Manager", "PM desk and assigned projects."),
    ("Accounts Assistant", "Accounts desk on the payment path."),
    ("Department Head", "HOD desk on leave requests."),
    ("HR", "HR desk on leave requests."),
    ("General Manager", "GM desk on the payment path."),
    ("CEO", "CEO desk before Finance pays."),
    ("Finance", "Make payment after CEO."),
    ("Stores Manager", "Stores desk on the material path."),
    ("Procurement", "Procurement follow-up after payment."),
    ("Accountant", "Accounts desk, including Make payment."),
    ("Contractor", "Projects and Contract Manager only."),
    ("Reviewer", "Notify only — no approval desk."),
    ("Approver", "Notify only — no approval desk."),
    ("Clerk", "View and create day-to-day documents."),
    ("Viewer", "Inquiry only."),
]

public func systemRoleDefinitions() -> [RoleDefinition] {
    builtInRoleCatalog.map { name, description in
        RoleDefinition(
            id: "role-\(normalizeRole(name).replacingOccurrences(of: " ", with: "-"))",
            name: name,
            description: description,
            crud: crudForRole(name),
            system: true
        )
    }
}

public func isBuiltInRoleName(_ name: String?) -> Bool {
    let key = normalizeRole(name)
    return builtInRoleCatalog.contains { normalizeRole($0.0) == key }
}

public func findRoleDefinition(_ roles: [RoleDefinition], _ name: String?) -> RoleDefinition? {
    let key = normalizeRole(name)
    guard !key.isEmpty else { return nil }
    return roles.first { normalizeRole($0.name) == key }
}

public func mergeStoredRoles(_ stored: [RoleDefinition]) -> [RoleDefinition] {
    let custom = stored.filter {
        !$0.system && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAdminRole($0.name) && !isBuiltInRoleName($0.name)
    }
    return systemRoleDefinitions() + custom
}

public struct DemoAccount: Equatable, Sendable {
    public var username: String
    public var name: String
    public var role: String
    public var title: String
    public var email: String
    public var phone: String

    public init(username: String, name: String, role: String, title: String, email: String = "", phone: String = "") {
        self.username = username
        self.name = name
        self.role = role
        self.title = title
        self.email = email
        self.phone = phone
    }
}

public let explicitGrantModules: Set<String> = [
    "rnd", "lab", "qa", "production", "benchmark", "crm", "logistics", "distribution",
    "fleet", "security", "investments", "assets", "capital", "contract-manager",
]

public let contractorModules: Set<String> = ["projects", "contract-manager"]

public let demoAccounts: [DemoAccount] = [
    DemoAccount(username: "admin", name: "Administrator", role: "Administrator", title: "Finance administrator", email: "admin@iag.africa", phone: "+256 700 000 001"),
    DemoAccount(username: "superadmin", name: "Super Admin", role: "Super Admin", title: "Platform owner", email: "superadmin@iag.africa", phone: "+256 700 000 000"),
    DemoAccount(username: "accountant", name: "Amina Accountant", role: "Accountant", title: "Accounts desk", email: "accountant@iag.africa", phone: ""),
    DemoAccount(username: "aa", name: "Alex Assistant", role: "Accounts Assistant", title: "Accounts desk", email: "aa@iag.africa", phone: ""),
    DemoAccount(username: "finance", name: "Fiona Finance", role: "Finance", title: "Make payment desk", email: "finance@iag.africa", phone: ""),
    DemoAccount(username: "clerk", name: "Chris Clerk", role: "Clerk", title: "Day-to-day documents", email: "clerk@iag.africa", phone: ""),
    DemoAccount(username: "viewer", name: "Vera Viewer", role: "Viewer", title: "Inquiry only", email: "viewer@iag.africa", phone: ""),
    DemoAccount(username: "hr", name: "Hannah HR", role: "HR", title: "HR desk", email: "hr@iag.africa", phone: ""),
    DemoAccount(username: "hod", name: "Daniel Head", role: "Department Head", title: "HOD desk", email: "hod@iag.africa", phone: ""),
    DemoAccount(username: "pm", name: "Patricia Manager", role: "Project Manager", title: "PM desk", email: "pm@iag.africa", phone: ""),
    DemoAccount(username: "contractor", name: "Carl Contractor", role: "Contractor", title: "Assigned projects", email: "contractor@iag.africa", phone: ""),
    DemoAccount(username: "gm", name: "Grace GM", role: "General Manager", title: "GM desk", email: "gm@iag.africa", phone: ""),
    DemoAccount(username: "ceo", name: "Cynthia CEO", role: "CEO", title: "CEO desk", email: "ceo@iag.africa", phone: ""),
    DemoAccount(username: "qs", name: "Quentin Surveyor", role: "Quantity Surveyor", title: "QS desk", email: "qs@iag.africa", phone: ""),
    DemoAccount(username: "stores", name: "Sam Stores", role: "Stores Manager", title: "Stores desk", email: "stores@iag.africa", phone: ""),
    DemoAccount(username: "procurement", name: "Paula Procurement", role: "Procurement", title: "Procurement desk", email: "procurement@iag.africa", phone: ""),
    DemoAccount(username: "reviewer", name: "Riley Reviewer", role: "Reviewer", title: "Notify only", email: "reviewer@iag.africa", phone: ""),
    DemoAccount(username: "approver", name: "Ava Approver", role: "Approver", title: "Notify only", email: "approver@iag.africa", phone: ""),
]

public func demoAccountFor(_ username: String) -> DemoAccount? {
    let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return demoAccounts.first { $0.username == u }
}

public func normalizeRole(_ role: String?) -> String {
    (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}

public func isAdminRole(_ role: String?) -> Bool {
    let r = normalizeRole(role)
    return r == "administrator" || r == "super admin" || r == "superadmin"
}

public func isContractorRole(_ role: String?) -> Bool { normalizeRole(role) == "contractor" }

public func crudForRole(_ role: String?, definition: RoleDefinition? = nil) -> Crud {
    if isAdminRole(role) || isAdminRole(definition?.name) { return .full }
    if let definition, !definition.system { return definition.crud }
    switch normalizeRole(role ?? definition?.name) {
    case "project manager", "accounts assistant", "department head", "hr", "human resources",
         "general manager", "ceo", "finance", "accountant", "quantity surveyor", "stores manager",
         "procurement", "contractor":
        return Crud(view: true, create: true, edit: true, delete: false)
    case "reviewer", "approver", "clerk":
        return Crud(view: true, create: true, edit: false, delete: false)
    default:
        return Crud(view: true, create: false, edit: false, delete: false)
    }
}

public func canAccessApprovalDesk(_ role: String?) -> Bool {
    if isAdminRole(role) { return true }
    switch normalizeRole(role) {
    case "quantity surveyor", "stores manager", "procurement", "hr", "human resources",
         "department head", "ceo", "general manager", "accounts assistant", "accountant",
         "accounts", "project manager", "finance":
        return true
    default:
        return false
    }
}

public func canAccessModule(_ role: String?, _ slug: String, definition: RoleDefinition? = nil) -> Bool {
    if isAdminRole(role) || isAdminRole(definition?.name) { return true }
    let pages = definition?.pagePermissions ?? [:]
    if let granted = pages[slug] { return granted.view }
    if let wild = pages[pageWildcardKey] { return wild.view }
    if isContractorRole(role) { return contractorModules.contains(slug) }
    let crud = crudForRole(role, definition: definition)
    if explicitGrantModules.contains(slug) { return false }
    if slug == "requests" || slug == "general-requests" || slug == "oral-payment-requests" {
        return crud.view
    }
    if !crud.view { return false }
    switch slug {
    case "payroll": return crud.create && crud.edit
    case "reports", "accounts", "documents", "folders": return crud.view
    case "banking", "sales", "purchases": return crud.create || crud.edit
    case "receipts-payments", "expense-claims", "inventory", "pos", "projects": return crud.create
    default: return crud.view
    }
}

public func canCreateIn(_ role: String?, _ moduleId: String, definition: RoleDefinition? = nil) -> Bool {
    guard canAccessModule(role, moduleId, definition: definition) else { return false }
    let pages = definition?.pagePermissions ?? [:]
    if let granted = pages[moduleId] { return granted.create }
    if let wild = pages[pageWildcardKey] { return wild.create }
    return crudForRole(role, definition: definition).create
}

public func canEditIn(_ role: String?, _ moduleId: String, definition: RoleDefinition? = nil) -> Bool {
    guard canAccessModule(role, moduleId, definition: definition) else { return false }
    let pages = definition?.pagePermissions ?? [:]
    if let granted = pages[moduleId] { return granted.edit }
    if let wild = pages[pageWildcardKey] { return wild.edit }
    return crudForRole(role, definition: definition).edit
}

public func canDeleteIn(_ role: String?, _ moduleId: String, definition: RoleDefinition? = nil) -> Bool {
    guard canAccessModule(role, moduleId, definition: definition) else { return false }
    let pages = definition?.pagePermissions ?? [:]
    if let granted = pages[moduleId] { return granted.delete }
    if let wild = pages[pageWildcardKey] { return wild.delete }
    return crudForRole(role, definition: definition).delete
}

public func canApproveIn(_ role: String?, _ moduleId: String, definition: RoleDefinition? = nil) -> Bool {
    guard canAccessModule(role, moduleId, definition: definition) else { return false }
    return canAccessApprovalDesk(role)
}

public func canVoidIn(_ role: String?, _ moduleId: String, definition: RoleDefinition? = nil) -> Bool {
    guard canAccessModule(role, moduleId, definition: definition) else { return false }
    if isAdminRole(role) { return true }
    let r = normalizeRole(role)
    return r == "finance" || r == "accountant" || r == "accounts assistant" || r == "accounts"
}

public func canRunPayroll(_ role: String?) -> Bool {
    if isAdminRole(role) { return true }
    let r = normalizeRole(role)
    return r == "hr" || r == "human resources" || r == "accountant" || r == "finance"
}

public let adminOnlySpecialNav: Set<String> = [
    "settings", "users", "request-emails", "activity-logs", "crash-analytics", "system-health", "analytics",
]

public func canAccessSpecialNav(_ role: String?, _ key: String, definition: RoleDefinition? = nil) -> Bool {
    if isAdminRole(role) || isAdminRole(definition?.name) { return true }
    if key == "profile" { return true }
    if adminOnlySpecialNav.contains(key) { return false }
    let pages = definition?.pagePermissions ?? [:]
    if let granted = pages[key] { return granted.view }
    let crud = crudForRole(role, definition: definition)
    switch key {
    case "dashboard", "trace", "guides", "qna", "release-notes", "templates", "comms", "accounting-documents", "payment-requests":
        return crud.view
    default:
        return false
    }
}

public func canManageGeofence(_ role: String?) -> Bool {
    if isAdminRole(role) { return true }
    let r = normalizeRole(role)
    return r == "hr" || r == "human resources"
}

public func isReconEntity(_ entity: String) -> Bool { entity.lowercased().contains("reconcil") }

public func isPayrollRunEntity(_ entity: String) -> Bool {
    let e = entity.lowercased()
    return e == "payroll runs" || e == "create payroll" || e == "payslip items" || e == "recurring payslips" || e == "statutory remittances"
}

public func isGeofenceEntity(_ entity: String) -> Bool { entity == "Sites" || entity == "Blocks" }

public func canCreateEntity(_ role: String?, _ moduleId: String, _ entity: String, definition: RoleDefinition? = nil) -> Bool {
    guard canCreateIn(role, moduleId, definition: definition) else { return false }
    if isReconEntity(entity) { return canVoidIn(role, moduleId, definition: definition) }
    if isPayrollRunEntity(entity) { return canRunPayroll(role) }
    if isGeofenceEntity(entity) { return canManageGeofence(role) }
    return true
}

public func canEditEntity(_ role: String?, _ moduleId: String, _ entity: String, definition: RoleDefinition? = nil) -> Bool {
    guard canEditIn(role, moduleId, definition: definition) else { return false }
    if isReconEntity(entity) { return canVoidIn(role, moduleId, definition: definition) }
    if isPayrollRunEntity(entity) { return canRunPayroll(role) }
    if isGeofenceEntity(entity) { return canManageGeofence(role) }
    return true
}

public func canDeleteEntity(_ role: String?, _ moduleId: String, _ entity: String, definition: RoleDefinition? = nil) -> Bool {
    guard canDeleteIn(role, moduleId, definition: definition) else { return false }
    if isReconEntity(entity) { return canVoidIn(role, moduleId, definition: definition) }
    if isPayrollRunEntity(entity) { return canRunPayroll(role) }
    if isGeofenceEntity(entity) { return canManageGeofence(role) }
    return true
}

public func isDraftStatus(_ status: String) -> Bool { status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "draft" }

public func isVoidedStatus(_ status: String) -> Bool {
    let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return s == "void" || s == "voided"
}

public func isApprovedStatus(_ status: String) -> Bool {
    let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return s == "approved" || s == "posted" || s == "paid"
}

public func defaultDepartmentForRole(_ role: String?) -> String? {
    if isContractorRole(role) { return "projects" }
    switch normalizeRole(role) {
    case "quantity surveyor", "project manager": return "projects"
    default: return nil
    }
}
