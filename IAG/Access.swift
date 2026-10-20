import Foundation

enum WorkDepartment: String, CaseIterable, Identifiable {
    case finance = "Finance"
    case humanResources = "Human Resources"
    case stores = "Stores"
    case procurement = "Procurement"
    case fleet = "Fleet"
    case logistics = "Logistics"
    case distribution = "Distribution"
    case projects = "Projects"
    case sales = "Sales"
    case production = "Production"
    case maintenance = "Maintenance"
    case laboratory = "Laboratory"
    case traceability = "Traceability"
    case security = "Security"
    case administration = "Administration"
    case executive = "Executive"

    var id: String { rawValue }

    var toolIDs: Set<String> {
        switch self {
        case .finance:
            return ["finance", "erp", "auditor", "pos"]
        case .humanResources:
            return ["hr"]
        case .stores:
            return ["inventory"]
        case .procurement:
            return ["procurement"]
        case .fleet:
            return ["fleet"]
        case .logistics:
            return ["logistics"]
        case .distribution:
            return ["distribution"]
        case .projects:
            return ["project-manager", "contract-manager"]
        case .sales:
            return ["crm"]
        case .production:
            return ["production"]
        case .maintenance:
            return ["maintenance"]
        case .laboratory:
            return ["lab"]
        case .traceability:
            return ["farmer-traceability"]
        case .security:
            return ["security"]
        case .administration:
            return ["admin", "erp-api"]
        case .executive:
            return []
        }
    }

    var homeToolID: String {
        switch self {
        case .finance: return "finance"
        case .humanResources: return "hr"
        case .stores: return "inventory"
        case .procurement: return "procurement"
        case .fleet: return "fleet"
        case .logistics: return "logistics"
        case .distribution: return "distribution"
        case .projects: return "project-manager"
        case .sales: return "crm"
        case .production: return "production"
        case .maintenance: return "maintenance"
        case .laboratory: return "lab"
        case .traceability: return "farmer-traceability"
        case .security: return "security"
        case .administration: return "admin"
        case .executive: return "finance"
        }
    }
}

enum WorkRole: String, CaseIterable, Identifiable {
    case administrator = "Administrator"
    case superAdmin = "Super Admin"
    case ceo = "CEO"
    case generalManager = "General Manager"
    case departmentHead = "Department Head"
    case finance = "Finance"
    case accountant = "Accountant"
    case accountsAssistant = "Accounts Assistant"
    case hr = "HR"
    case storesManager = "Stores Manager"
    case procurement = "Procurement"
    case projectManager = "Project Manager"
    case quantitySurveyor = "Quantity Surveyor"
    case contractor = "Contractor"
    case clerk = "Clerk"
    case approver = "Approver"
    case reviewer = "Reviewer"
    case viewer = "Viewer"

    var id: String { rawValue }

    var opensEveryTool: Bool {
        switch self {
        case .administrator, .superAdmin, .ceo, .generalManager:
            return true
        default:
            return false
        }
    }

    var canCreate: Bool {
        switch self {
        case .viewer, .reviewer, .approver:
            return false
        default:
            return true
        }
    }

    var canEdit: Bool {
        switch self {
        case .viewer, .reviewer, .approver, .clerk:
            return false
        default:
            return true
        }
    }

    var canDelete: Bool {
        switch self {
        case .administrator, .superAdmin, .departmentHead:
            return true
        default:
            return false
        }
    }

    var capabilitySentence: String {
        switch self {
        case .administrator, .superAdmin:
            return "Full access, including delete."
        case .departmentHead:
            return "Full access in the department, including delete."
        case .ceo, .generalManager:
            return "Can add and edit. Cannot delete."
        case .clerk:
            return "Can add records. Cannot edit or delete them."
        case .viewer, .reviewer, .approver:
            return "Can open records. Cannot add, edit, or delete."
        case .contractor:
            return "Project Manager and Contract Manager only. Can add and edit."
        default:
            return "Can add and edit records in the department. Cannot delete."
        }
    }
}

struct ToolAccess {
    let department: WorkDepartment
    let role: WorkRole

    var canCreate: Bool { role.canCreate }
    var canEdit: Bool { role.canEdit }
    var canDelete: Bool { role.canDelete }

    func allows(_ toolID: String) -> Bool {
        if role == .contractor {
            return toolID == "project-manager" || toolID == "contract-manager"
        }
        if role.opensEveryTool || department == .executive {
            return true
        }
        return department.toolIDs.contains(toolID)
    }

    func allowed(_ systems: [SystemCatalog]) -> [SystemCatalog] {
        systems.filter { allows($0.id) }
    }

    var preferredHomeID: String {
        if role == .contractor { return "project-manager" }
        if role.opensEveryTool || department == .executive { return "finance" }
        return department.homeToolID
    }

    func homeToolID(in systems: [SystemCatalog]) -> String {
        let open = allowed(systems)
        if open.contains(where: { $0.id == preferredHomeID }) {
            return preferredHomeID
        }
        return open.first?.id ?? preferredHomeID
    }

    func opensSentence(in systems: [SystemCatalog]) -> String {
        if role == .contractor {
            return "Contractor opens Project Manager and Contract Manager only. \(role.capabilitySentence)"
        }
        if role.opensEveryTool {
            return "\(role.rawValue) opens every tool, not only \(department.rawValue). \(role.capabilitySentence)"
        }
        if department == .executive {
            return "Executive opens every tool. \(role.capabilitySentence)"
        }
        let names = systems.filter { department.toolIDs.contains($0.id) }.map(\.name)
        let list = names.isEmpty ? "no tools" : names.joined(separator: ", ")
        return "\(department.rawValue) opens \(list). \(role.capabilitySentence)"
    }
}
