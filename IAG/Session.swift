import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var name: String
    @Published private(set) var email: String
    @Published private(set) var signedIn: Bool
    @Published private(set) var toolID: String
    @Published private(set) var departmentName: String
    @Published private(set) var roleName: String

    var department: WorkDepartment { WorkDepartment(rawValue: departmentName) ?? .finance }
    var role: WorkRole { WorkRole(rawValue: roleName) ?? .finance }
    var access: ToolAccess { ToolAccess(department: department, role: role) }

    private enum Key {
        static let name = "iag.session.name"
        static let email = "iag.session.email"
        static let signedIn = "iag.session.signedIn"
        static let tool = "iag.session.tool"
        static let department = "iag.session.department"
        static let role = "iag.session.role"
    }

    init() {
        let defaults = UserDefaults.standard
        name = defaults.string(forKey: Key.name) ?? ""
        email = defaults.string(forKey: Key.email) ?? ""
        signedIn = defaults.bool(forKey: Key.signedIn)
        let storedTool = defaults.string(forKey: Key.tool) ?? ""
        toolID = storedTool.isEmpty ? "finance" : storedTool
        let storedDepartment = defaults.string(forKey: Key.department) ?? ""
        departmentName = storedDepartment.isEmpty ? WorkDepartment.finance.rawValue : storedDepartment
        let storedRole = defaults.string(forKey: Key.role) ?? ""
        roleName = storedRole.isEmpty ? WorkRole.finance.rawValue : storedRole
    }

    func signIn(name: String, email: String, toolID: String, department: WorkDepartment, role: WorkRole) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.departmentName = department.rawValue
        self.roleName = role.rawValue
        let access = ToolAccess(department: department, role: role)
        self.toolID = access.allows(toolID) ? toolID : access.preferredHomeID
        signedIn = true
        persist()
    }

    func open(toolID: String) {
        guard access.allows(toolID) else { return }
        self.toolID = toolID
        persist()
    }

    func signOut() {
        signedIn = false
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: Key.name)
        defaults.set(email, forKey: Key.email)
        defaults.set(signedIn, forKey: Key.signedIn)
        defaults.set(toolID, forKey: Key.tool)
        defaults.set(departmentName, forKey: Key.department)
        defaults.set(roleName, forKey: Key.role)
    }
}
