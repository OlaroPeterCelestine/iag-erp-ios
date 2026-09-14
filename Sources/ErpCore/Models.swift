import Foundation

public let appName = "IAG Central"
public let appVersion = "1.0.0"

func erpJsonText(_ j: [String: Any], _ key: String, fallback: String = "") -> String {
    guard let value = j[key], !(value is NSNull) else { return fallback }
    if let text = value as? String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
    if let number = value as? NSNumber { return number.stringValue }
    return "\(value)"
}

public struct AuthUser: Equatable, Sendable {
    public var username: String
    public var name: String
    public var role: String
    public var email: String
    public var phone: String
    public var title: String

    public init(username: String, name: String, role: String, email: String = "", phone: String = "", title: String = "") {
        self.username = username
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.title = title
    }

    public var initials: String {
        let parts = name.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.isEmpty { return username.isEmpty ? "?" : String(username.prefix(1)).uppercased() }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return "\(parts[0].prefix(1))\(parts[parts.count - 1].prefix(1))".uppercased()
    }

    public func toJSON() -> [String: Any] {
        ["username": username, "name": name, "role": role, "email": email, "phone": phone, "title": title]
    }

    public static func fromJSON(_ j: [String: Any]) -> AuthUser {
        let username = erpJsonText(j, "username")
        let defaults = AuthUser.demo(username)
        let email = erpJsonText(j, "email")
        let phone = erpJsonText(j, "phone")
        let title = erpJsonText(j, "title")
        return AuthUser(
            username: username,
            name: erpJsonText(j, "name", fallback: defaults.name),
            role: erpJsonText(j, "role", fallback: defaults.role),
            email: email.isEmpty ? defaults.email : email,
            phone: phone.isEmpty ? defaults.phone : phone,
            title: title.isEmpty ? defaults.title : title
        )
    }

    public static func demo(_ username: String) -> AuthUser {
        guard let account = demoAccountFor(username) else {
            let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return AuthUser(username: u, name: u, role: "Viewer")
        }
        return AuthUser(
            username: account.username,
            name: account.name,
            role: account.role,
            email: account.email,
            phone: account.phone,
            title: account.title
        )
    }
}

public final class ErpRecord: Equatable {
    public let id: String
    public let moduleId: String
    public let entity: String
    public var title: String
    public var subtitle: String
    public var status: String
    public var date: String
    public var amount: Double?
    public var fields: [String: String]

    public init(
        id: String,
        moduleId: String,
        entity: String,
        title: String,
        subtitle: String,
        status: String,
        date: String,
        amount: Double? = nil,
        fields: [String: String] = [:]
    ) {
        self.id = id
        self.moduleId = moduleId
        self.entity = entity
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.date = date
        self.amount = amount
        self.fields = fields
    }

    public static func == (lhs: ErpRecord, rhs: ErpRecord) -> Bool { lhs.id == rhs.id }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "id": id,
            "moduleId": moduleId,
            "entity": entity,
            "title": title,
            "subtitle": subtitle,
            "status": status,
            "date": date,
            "fields": fields,
        ]
        if let amount { json["amount"] = amount }
        return json
    }

    public static func fromJSON(_ j: [String: Any]) -> ErpRecord {
        var fields: [String: String] = [:]
        if let raw = j["fields"] as? [String: Any] {
            for (k, v) in raw { fields[k] = "\(v)" }
        }
        let id = erpJsonText(j, "id")
        return ErpRecord(
            id: id.isEmpty ? newId() : id,
            moduleId: erpJsonText(j, "moduleId"),
            entity: erpJsonText(j, "entity"),
            title: erpJsonText(j, "title"),
            subtitle: erpJsonText(j, "subtitle"),
            status: erpJsonText(j, "status", fallback: "Draft"),
            date: erpJsonText(j, "date"),
            amount: (j["amount"] as? NSNumber)?.doubleValue,
            fields: fields
        )
    }
}

public struct WelcomeStat: Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var value: String
    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct Kpi: Equatable, Sendable {
    public var label: String
    public var value: String
    public var hint: String
    public var up: Bool
    public init(label: String, value: String, hint: String, up: Bool = true) {
        self.label = label
        self.value = value
        self.hint = hint
        self.up = up
    }
}

public struct ErpModule: Equatable {
    public var id: String
    public var label: String
    public var group: String
    public var description: String
    public var icon: String
    public var color: UInt32
    public var entities: [String]
    public var approvalEntities: Set<String>
    public var seed: [ErpRecord]

    public init(
        id: String,
        label: String,
        group: String,
        description: String = "",
        icon: String,
        color: UInt32,
        entities: [String],
        approvalEntities: Set<String> = [],
        seed: [ErpRecord] = []
    ) {
        self.id = id
        self.label = label
        self.group = group
        self.description = description
        self.icon = icon
        self.color = color
        self.entities = entities
        self.approvalEntities = approvalEntities
        self.seed = seed
    }

    public static func == (lhs: ErpModule, rhs: ErpModule) -> Bool { lhs.id == rhs.id }
}

public protocol KeyValueStore: AnyObject {
    func get(_ key: String) -> String?
    func put(_ key: String, _ value: String)
}

public final class MemoryKeyValueStore: KeyValueStore {
    private var data: [String: String] = [:]
    public init() {}
    public func get(_ key: String) -> String? { data[key] }
    public func put(_ key: String, _ value: String) { data[key] = value }
}

public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults
    public init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func get(_ key: String) -> String? { defaults.string(forKey: key) }
    public func put(_ key: String, _ value: String) { defaults.set(value, forKey: key) }
}

public func formatMoney(_ amount: Double) -> String {
    let abs = abs(amount)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    let body = formatter.string(from: NSNumber(value: abs)) ?? "0"
    return "\(amount < 0 ? "-" : "")UGX \(body)"
}

public func todayIsoDate() -> String {
    let c = Calendar.current
    let d = Date()
    return String(format: "%04d-%02d-%02d", c.component(.year, from: d), c.component(.month, from: d), c.component(.day, from: d))
}

public func newId() -> String {
    "\(DispatchTime.now().uptimeNanoseconds)-\(Int(Date().timeIntervalSince1970 * 1000) % 997)"
}

public func seedRecord(
    module: String,
    entity: String,
    title: String,
    subtitle: String,
    status: String,
    date: String? = nil,
    amount: Double? = nil,
    fields: [String: String] = [:]
) -> ErpRecord {
    ErpRecord(
        id: newId(),
        moduleId: module,
        entity: entity,
        title: title,
        subtitle: subtitle,
        status: status,
        date: date ?? "2026-08-20",
        amount: amount,
        fields: fields
    )
}

public let departmentGroups = [
    "Treasury", "Requests", "Commercial", "Inventory & production", "Projects",
    "Operations", "Quality", "People", "Accounting", "Records",
]

public struct SuiteApp: Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var description: String
    public var moduleIds: [String]
    public var icon: String
    public var color: UInt32
}

public let suiteApps: [SuiteApp] = [
    SuiteApp(id: "finance", label: "Finance", description: "Banking, receipts, claims, accounts, reports, assets, capital, and investments.", moduleIds: ["banking", "receipts-payments", "expense-claims", "accounts", "reports", "investments", "assets", "capital"], icon: "banknote", color: 0xFF0369A1),
    SuiteApp(id: "sales", label: "Sales", description: "Customers, quotes, orders, invoices, and credit notes.", moduleIds: ["sales"], icon: "storefront", color: 0xFF059669),
    SuiteApp(id: "crm", label: "CRM", description: "Leads, accounts, opportunities, follow-ups, and complaints.", moduleIds: ["crm"], icon: "person.3", color: 0xFFBE123C),
    SuiteApp(id: "pos", label: "POS", description: "Tills, tickets, KOTs, cash sessions, and daily closings.", moduleIds: ["pos"], icon: "creditcard", color: 0xFF0F766E),
    SuiteApp(id: "procurement", label: "Procurement", description: "Suppliers, purchase documents, goods receipts, and inventory.", moduleIds: ["purchases", "inventory"], icon: "cart", color: 0xFF2563EB),
    SuiteApp(id: "production", label: "Production", description: "Plans, machines, batches, roast, packaging, downtime, and yield.", moduleIds: ["production"], icon: "gearshape.2", color: 0xFFB45309),
    SuiteApp(id: "fleet", label: "Fleet", description: "Vehicles, drivers, fuel, trips, and maintenance.", moduleIds: ["fleet"], icon: "car.fill", color: 0xFFD97706),
    SuiteApp(id: "logistics", label: "Logistics", description: "Shipments, dispatch, routes, distribution, and deliveries.", moduleIds: ["logistics", "distribution"], icon: "shippingbox", color: 0xFF0F766E),
    SuiteApp(id: "projects", label: "Projects", description: "Projects, Gantt, IPC, materials, and work programs.", moduleIds: ["projects"], icon: "briefcase", color: 0xFF4F46E5),
    SuiteApp(id: "contracts", label: "Contract Management", description: "Contracts, contractors, amendments, invoices, and bonds.", moduleIds: ["contract-manager"], icon: "doc.badge.checkmark", color: 0xFF047857),
    SuiteApp(id: "hr", label: "HR & Payroll", description: "Employees, attendance, leave, payroll runs, and payslips.", moduleIds: ["payroll"], icon: "person.2", color: 0xFF7C3AED),
    SuiteApp(id: "security", label: "Security", description: "Gate passes, visitor passes, and security incidents.", moduleIds: ["security"], icon: "shield.checkered", color: 0xFF334155),
    SuiteApp(id: "quality", label: "Quality", description: "R&D, lab, QA, and work-system benchmarks.", moduleIds: ["rnd", "lab", "qa", "benchmark"], icon: "flask", color: 0xFF6D28D9),
    SuiteApp(id: "requests", label: "Requests", description: "General and oral payment requests through the approval desks.", moduleIds: ["general-requests", "oral-payment-requests"], icon: "list.clipboard", color: 0xFF7C3AED),
    SuiteApp(id: "dms", label: "DMS", description: "Cabinets, folders, documents, versions, and file shares.", moduleIds: ["folders", "documents"], icon: "folder.fill", color: 0xFFA16207),
]

public func suiteAppById(_ id: String?) -> SuiteApp? {
    guard let id, !id.isEmpty else { return nil }
    let key: String
    switch id {
    case "records": key = "dms"
    case "contract-manager", "contract-management": key = "contracts"
    default: key = id
    }
    return suiteApps.first { $0.id == key }
}

public func suiteAppContaining(_ moduleId: String) -> SuiteApp? {
    suiteApps.first { $0.moduleIds.contains(moduleId) }
}

public func canOpenSuiteApp(_ role: String?, _ appId: String, definition: RoleDefinition? = nil) -> Bool {
    guard let app = suiteAppById(appId) else { return false }
    return app.moduleIds.contains { canAccessModule(role, $0, definition: definition) }
}

public func defaultSuiteAppForRole(_ role: String?) -> String? {
    if isAdminRole(role) { return nil }
    if isContractorRole(role) { return "projects" }
    switch normalizeRole(role) {
    case "quantity surveyor", "project manager": return "projects"
    case "procurement", "stores manager": return "procurement"
    case "hr", "human resources": return "hr"
    case "accountant", "accounts assistant", "accounts", "finance", "clerk": return "finance"
    case "viewer": return "finance"
    default: return nil
    }
}

public let workspaceGroups = ["Command", "Records", "Requests", "People", "Help", "Admin"]

public struct SearchHit: Equatable, Identifiable {
    public enum Kind: String { case module, entity, record, tool }
    public var id: String
    public var kind: Kind
    public var title: String
    public var subtitle: String
    public var moduleId: String
    public var entity: String?
    public var recordId: String?

    public init(kind: Kind, title: String, subtitle: String, moduleId: String, entity: String? = nil, recordId: String? = nil) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.moduleId = moduleId
        self.entity = entity
        self.recordId = recordId
        switch kind {
        case .module: self.id = "module:\(moduleId)"
        case .entity: self.id = "entity:\(moduleId):\(entity ?? "")"
        case .record: self.id = "record:\(recordId ?? title)"
        case .tool: self.id = "tool:\(moduleId)"
        }
    }
}

public struct WorkspaceTool: Equatable, Identifiable {
    public var id: String
    public var label: String
    public var group: String
    public var description: String
    public var adminOnly: Bool

    public init(id: String, label: String, group: String, description: String, adminOnly: Bool = false) {
        self.id = id
        self.label = label
        self.group = group
        self.description = description
        self.adminOnly = adminOnly
    }
}

public let workspaceTools: [WorkspaceTool] = [
    WorkspaceTool(id: "trace", label: "Trace", group: "Command", description: "Search an invoice, plate, lot, employee, or document across every desk."),
    WorkspaceTool(id: "analytics", label: "Analytics", group: "Command", description: "Record counts and activity by department.", adminOnly: true),
    WorkspaceTool(id: "accounting-documents", label: "Accounting documents", group: "Records", description: "Sales, purchase, payroll, and payment documents in one pack."),
    WorkspaceTool(id: "templates", label: "Templates", group: "Records", description: "Reusable request and document templates."),
    WorkspaceTool(id: "payment-requests", label: "Approval desks", group: "Requests", description: "Open requests waiting on a desk, plus your own returned items."),
    WorkspaceTool(id: "clock-in", label: "Clock In", group: "People", description: "GPS clock-in and clock-out against Sites and Blocks."),
    WorkspaceTool(id: "guides", label: "Guides", group: "Help", description: "How desks, approvals, and segregation of duties work."),
    WorkspaceTool(id: "qna", label: "Q&A", group: "Help", description: "Common questions from operators."),
    WorkspaceTool(id: "release-notes", label: "Release notes", group: "Help", description: "What shipped in this app."),
    WorkspaceTool(id: "activity-logs", label: "Activity", group: "Admin", description: "Who changed records.", adminOnly: true),
    WorkspaceTool(id: "system-health", label: "System health", group: "Admin", description: "Local store, roles, and record counts.", adminOnly: true),
    WorkspaceTool(id: "settings", label: "Settings", group: "Admin", description: "Theme and workspace options.", adminOnly: true),
]

public enum QuickActionKind: String, Sendable {
    case create, list, clock, approvals, access
}

public struct QuickAction: Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var icon: String
    public var color: UInt32
    public var kind: QuickActionKind
    public var appId: String?
    public var moduleId: String
    public var entity: String?

    public init(
        id: String,
        label: String,
        icon: String,
        color: UInt32,
        kind: QuickActionKind,
        appId: String? = nil,
        moduleId: String,
        entity: String? = nil
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.color = color
        self.kind = kind
        self.appId = appId
        self.moduleId = moduleId
        self.entity = entity
    }
}

public let quickActionCatalog: [QuickAction] = [
    QuickAction(id: "clock", label: "Clock in", icon: "clock.fill", color: 0xFF047857, kind: .clock, moduleId: "clock-in"),
    QuickAction(id: "approvals", label: "Approvals", icon: "checkmark.rectangle.fill", color: 0xFFC47820, kind: .approvals, moduleId: "general-requests"),
    QuickAction(id: "access", label: "Users", icon: "shield.checkered", color: 0xFF334155, kind: .access, moduleId: "payroll"),
    QuickAction(id: "receipt", label: "Receipt", icon: "arrow.down.circle", color: 0xFF0F766E, kind: .create, appId: "finance", moduleId: "receipts-payments", entity: "Receipts"),
    QuickAction(id: "payment", label: "Payment", icon: "arrow.up.circle", color: 0xFF0369A1, kind: .create, appId: "finance", moduleId: "receipts-payments", entity: "Payments"),
    QuickAction(id: "claim", label: "Claim", icon: "receipt", color: 0xFFB45309, kind: .create, appId: "finance", moduleId: "expense-claims", entity: "Expense Claims"),
    QuickAction(id: "journal", label: "Journal", icon: "book", color: 0xFF0F172A, kind: .create, appId: "finance", moduleId: "accounts", entity: "Journal Entries"),
    QuickAction(id: "reports", label: "Reports", icon: "chart.bar", color: 0xFF0369A1, kind: .list, appId: "finance", moduleId: "reports", entity: "Balance Sheet"),
    QuickAction(id: "transfer", label: "Transfer", icon: "arrow.left.arrow.right", color: 0xFF0369A1, kind: .create, appId: "finance", moduleId: "banking", entity: "Inter Account Transfers"),
    QuickAction(id: "po", label: "New PO", icon: "cart.fill", color: 0xFF2563EB, kind: .create, appId: "procurement", moduleId: "purchases", entity: "Purchase Orders"),
    QuickAction(id: "grn", label: "GRN", icon: "shippingbox", color: 0xFF0E7490, kind: .create, appId: "procurement", moduleId: "purchases", entity: "Goods Receipts"),
    QuickAction(id: "supplier", label: "Supplier", icon: "person.2", color: 0xFF2563EB, kind: .create, appId: "procurement", moduleId: "purchases", entity: "Suppliers"),
    QuickAction(id: "item", label: "Item", icon: "cube.box", color: 0xFF0E7490, kind: .create, appId: "procurement", moduleId: "inventory", entity: "Inventory Items"),
    QuickAction(id: "prod-order", label: "Order", icon: "gearshape.2", color: 0xFFB45309, kind: .create, appId: "production", moduleId: "production", entity: "Production Orders"),
    QuickAction(id: "batch", label: "Batch", icon: "square.stack.3d.up", color: 0xFFB45309, kind: .create, appId: "production", moduleId: "production", entity: "Batch Records"),
    QuickAction(id: "roast", label: "Roast", icon: "flame", color: 0xFFC2410C, kind: .create, appId: "production", moduleId: "production", entity: "Roast Batches"),
    QuickAction(id: "downtime", label: "Down", icon: "pause.circle", color: 0xFF57534E, kind: .create, appId: "production", moduleId: "production", entity: "Downtime Logs"),
    QuickAction(id: "gate", label: "Gate", icon: "lock.open", color: 0xFF334155, kind: .create, appId: "security", moduleId: "security", entity: "Gate Passes"),
    QuickAction(id: "visitor", label: "Visitor", icon: "person.badge.plus", color: 0xFF334155, kind: .create, appId: "security", moduleId: "security", entity: "Visitor Passes"),
    QuickAction(id: "incident", label: "Incident", icon: "exclamationmark.triangle", color: 0xFFB91C1C, kind: .create, appId: "security", moduleId: "security", entity: "Security Incidents"),
    QuickAction(id: "leave", label: "Leave", icon: "calendar", color: 0xFF7C3AED, kind: .create, appId: "hr", moduleId: "payroll", entity: "Leave Requests"),
    QuickAction(id: "employee", label: "Staff", icon: "person.crop.rectangle", color: 0xFF7C3AED, kind: .create, appId: "hr", moduleId: "payroll", entity: "Employees"),
    QuickAction(id: "payroll", label: "Payroll", icon: "banknote", color: 0xFF7C3AED, kind: .create, appId: "hr", moduleId: "payroll", entity: "Payroll Runs"),
    QuickAction(id: "project", label: "Project", icon: "briefcase", color: 0xFF4F46E5, kind: .create, appId: "projects", moduleId: "projects", entity: "New Project"),
    QuickAction(id: "ipc", label: "IPC", icon: "doc.badge.plus", color: 0xFF4F46E5, kind: .create, appId: "projects", moduleId: "projects", entity: "Payment Requests (IPC)"),
    QuickAction(id: "material", label: "Material", icon: "hammer", color: 0xFF4F46E5, kind: .create, appId: "projects", moduleId: "projects", entity: "Material Requests"),
    QuickAction(id: "contractor", label: "Contractor", icon: "person.badge.shield.checkmark", color: 0xFF047857, kind: .create, appId: "contracts", moduleId: "contract-manager", entity: "Contractors"),
    QuickAction(id: "contract", label: "Contract", icon: "doc.badge.checkmark", color: 0xFF047857, kind: .create, appId: "contracts", moduleId: "contract-manager", entity: "Contracts"),
    QuickAction(id: "fuel", label: "Fuel", icon: "fuelpump", color: 0xFFD97706, kind: .create, appId: "fleet", moduleId: "fleet", entity: "Fuel Requests"),
    QuickAction(id: "trip", label: "Trip", icon: "map", color: 0xFFD97706, kind: .create, appId: "fleet", moduleId: "fleet", entity: "Trip Requests"),
    QuickAction(id: "maintenance", label: "Service", icon: "wrench.and.screwdriver", color: 0xFFD97706, kind: .create, appId: "fleet", moduleId: "fleet", entity: "Maintenance Requests"),
    QuickAction(id: "vehicle", label: "Vehicle", icon: "car.fill", color: 0xFFD97706, kind: .create, appId: "fleet", moduleId: "fleet", entity: "Vehicles"),
    QuickAction(id: "invoice", label: "Invoice", icon: "doc.text.fill", color: 0xFF059669, kind: .create, appId: "sales", moduleId: "sales", entity: "Sales Invoices"),
    QuickAction(id: "customer", label: "Customer", icon: "person.crop.circle.badge.plus", color: 0xFF059669, kind: .create, appId: "sales", moduleId: "sales", entity: "Customers"),
    QuickAction(id: "quote", label: "Quote", icon: "doc.plaintext", color: 0xFF059669, kind: .create, appId: "sales", moduleId: "sales", entity: "Sales Quotes"),
    QuickAction(id: "lead", label: "Lead", icon: "star", color: 0xFFBE123C, kind: .create, appId: "crm", moduleId: "crm", entity: "Leads"),
    QuickAction(id: "opportunity", label: "Deal", icon: "target", color: 0xFFBE123C, kind: .create, appId: "crm", moduleId: "crm", entity: "Opportunities"),
    QuickAction(id: "ticket", label: "Ticket", icon: "ticket", color: 0xFF0F766E, kind: .create, appId: "pos", moduleId: "pos", entity: "Open Tickets"),
    QuickAction(id: "pos-sale", label: "Sale", icon: "creditcard", color: 0xFF0F766E, kind: .create, appId: "pos", moduleId: "pos", entity: "POS Sales"),
    QuickAction(id: "session", label: "Shift", icon: "lock.laptopcomputer", color: 0xFF0F766E, kind: .create, appId: "pos", moduleId: "pos", entity: "Cash Sessions"),
    QuickAction(id: "shipment", label: "Ship", icon: "shippingbox.fill", color: 0xFF0F766E, kind: .create, appId: "logistics", moduleId: "logistics", entity: "Shipments"),
    QuickAction(id: "dispatch", label: "Dispatch", icon: "list.bullet.rectangle", color: 0xFF0F766E, kind: .list, appId: "logistics", moduleId: "logistics", entity: "Dispatch Board"),
    QuickAction(id: "delivery", label: "Deliver", icon: "bicycle", color: 0xFF0D9488, kind: .create, appId: "logistics", moduleId: "distribution", entity: "Delivery Runs"),
    QuickAction(id: "lab", label: "Lab", icon: "testtube.2", color: 0xFF6D28D9, kind: .create, appId: "quality", moduleId: "lab", entity: "Lab Requests"),
    QuickAction(id: "qa", label: "QA", icon: "checkmark.seal", color: 0xFF0369A1, kind: .create, appId: "quality", moduleId: "qa", entity: "Quality Checks"),
    QuickAction(id: "nc", label: "NC", icon: "xmark.octagon", color: 0xFFB91C1C, kind: .create, appId: "quality", moduleId: "qa", entity: "Non-conformances"),
    QuickAction(id: "gen-request", label: "Request", icon: "list.clipboard", color: 0xFF7C3AED, kind: .create, appId: "requests", moduleId: "general-requests", entity: "General Requests"),
    QuickAction(id: "oral", label: "Oral pay", icon: "mic", color: 0xFFC2410C, kind: .create, appId: "requests", moduleId: "oral-payment-requests", entity: "Oral Payment Requests"),
    QuickAction(id: "folder", label: "Folder", icon: "folder.badge.plus", color: 0xFFA16207, kind: .create, appId: "dms", moduleId: "folders", entity: "Folders"),
    QuickAction(id: "attachment", label: "File", icon: "paperclip", color: 0xFF57534E, kind: .list, appId: "dms", moduleId: "documents", entity: "Documents"),
]

public let defaultKpis: [Kpi] = [
    Kpi(label: "Assets", value: "UGX 2.4B", hint: "Balance sheet"),
    Kpi(label: "Liabilities", value: "UGX 890M", hint: "Payables + loans", up: false),
    Kpi(label: "Equity", value: "UGX 1.5B", hint: "Capital + retained"),
    Kpi(label: "Net profit", value: "UGX 124M", hint: "YTD vs last year"),
]
