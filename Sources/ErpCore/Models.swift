import Foundation

public let demoPassword = "iagdemo"
public let appVersion = "1.0.0"

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
        let username = j["username"] as? String ?? ""
        let defaults = AuthUser.demo(username)
        let email = ((j["email"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = ((j["phone"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = ((j["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return AuthUser(
            username: username,
            name: j["name"] as? String ?? defaults.name,
            role: j["role"] as? String ?? defaults.role,
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
        return ErpRecord(
            id: j["id"] as? String ?? newId(),
            moduleId: j["moduleId"] as? String ?? "",
            entity: j["entity"] as? String ?? "",
            title: j["title"] as? String ?? "",
            subtitle: j["subtitle"] as? String ?? "",
            status: j["status"] as? String ?? "Draft",
            date: j["date"] as? String ?? "",
            amount: (j["amount"] as? NSNumber)?.doubleValue,
            fields: fields
        )
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

public let defaultKpis: [Kpi] = [
    Kpi(label: "Assets", value: "UGX 2.4B", hint: "Balance sheet"),
    Kpi(label: "Liabilities", value: "UGX 890M", hint: "Payables + loans", up: false),
    Kpi(label: "Equity", value: "UGX 1.5B", hint: "Capital + retained"),
    Kpi(label: "Net profit", value: "UGX 124M", hint: "YTD vs last year"),
]
