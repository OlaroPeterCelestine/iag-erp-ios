import XCTest
@testable import ErpCore

final class RbacTests: XCTestCase {
    private func store() -> ErpStore {
        let s = ErpStore(persistence: MemoryKeyValueStore())
        s.load()
        return s
    }

    func testAdminSeesEveryDepartmentIncludingExplicitGrantApps() {
        XCTAssertTrue(canAccessModule("Administrator", "banking"))
        XCTAssertTrue(canAccessModule("Administrator", "fleet"))
        XCTAssertTrue(canAccessModule("Administrator", "crm"))
        XCTAssertTrue(canAccessModule("Super Admin", "pos"))
        XCTAssertTrue(canDeleteIn("Administrator", "sales"))
        XCTAssertTrue(canAccessApprovalDesk("Administrator"))
    }

    func testViewerIsInquiryOnlyOnReportsAndRequests() {
        XCTAssertTrue(canAccessModule("Viewer", "reports"))
        XCTAssertTrue(canAccessModule("Viewer", "accounts"))
        XCTAssertTrue(canAccessModule("Viewer", "general-requests"))
        XCTAssertFalse(canAccessModule("Viewer", "banking"))
        XCTAssertFalse(canAccessModule("Viewer", "sales"))
        XCTAssertFalse(canAccessModule("Viewer", "payroll"))
        XCTAssertFalse(canAccessModule("Viewer", "fleet"))
        XCTAssertFalse(canAccessModule("Viewer", "pos"))
        XCTAssertFalse(canCreateIn("Viewer", "reports"))
        XCTAssertFalse(canAccessApprovalDesk("Viewer"))
    }

    func testClerkCanCreateDayToDayButCannotEditDeleteOrApprove() {
        XCTAssertTrue(canAccessModule("Clerk", "banking"))
        XCTAssertTrue(canAccessModule("Clerk", "sales"))
        XCTAssertTrue(canAccessModule("Clerk", "pos"))
        XCTAssertFalse(canAccessModule("Clerk", "payroll"))
        XCTAssertFalse(canAccessModule("Clerk", "fleet"))
        XCTAssertTrue(canCreateIn("Clerk", "sales"))
        XCTAssertFalse(canEditIn("Clerk", "sales"))
        XCTAssertFalse(canDeleteIn("Clerk", "sales"))
        XCTAssertFalse(canAccessApprovalDesk("Clerk"))
        XCTAssertFalse(canCreateEntity("Clerk", "banking", "Reconciliations"))
    }

    func testContractorIsLockedToProjectsAndContractManager() {
        XCTAssertTrue(canAccessModule("Contractor", "projects"))
        XCTAssertTrue(canAccessModule("Contractor", "contract-manager"))
        XCTAssertFalse(canAccessModule("Contractor", "banking"))
        XCTAssertFalse(canAccessModule("Contractor", "payroll"))
        XCTAssertFalse(canAccessModule("Contractor", "reports"))
        XCTAssertFalse(canAccessApprovalDesk("Contractor"))
    }

    func testHrCanRunPayrollAndFencesAccountantCanVoidButNotFences() {
        XCTAssertTrue(canAccessModule("HR", "payroll"))
        XCTAssertFalse(canAccessModule("HR", "fleet"))
        XCTAssertTrue(canRunPayroll("HR"))
        XCTAssertTrue(canManageGeofence("HR"))
        XCTAssertTrue(canVoidIn("Accountant", "banking"))
        XCTAssertFalse(canManageGeofence("Accountant"))
        XCTAssertFalse(canCreateEntity("Accountant", "payroll", "Sites"))
        XCTAssertTrue(canCreateEntity("HR", "payroll", "Sites"))
        XCTAssertTrue(canRunPayroll("Accountant"))
        XCTAssertTrue(canAccessApprovalDesk("Accountant"))
        XCTAssertFalse(canAccessApprovalDesk("Reviewer"))
    }

    func testLoginEnforcesDepartmentGrantsAndWorkflowSod() {
        let s = store()
        XCTAssertEqual(s.login("nobody", "iagdemo"), "Unknown user.")
        XCTAssertEqual(s.login("viewer", "iagdemo", departmentId: "banking"), "Your role cannot open that app.")
        XCTAssertFalse(s.isSignedIn)

        XCTAssertNil(s.login("viewer", "iagdemo"))
        XCTAssertEqual(s.user?.role, "Viewer")
        XCTAssertFalse(s.canOpen("banking"))
        XCTAssertTrue(s.canOpen("reports"))
        XCTAssertFalse(s.canApprove)
        XCTAssertFalse(s.visibleModules.contains { $0.id == "banking" })
        XCTAssertTrue(s.visibleModules.contains { $0.id == "reports" })
        s.logout()

        XCTAssertEqual(s.login("contractor", "iagdemo", departmentId: "banking"), "Your role cannot open that app.")
        XCTAssertNil(s.login("contractor", "iagdemo"))
        XCTAssertEqual(s.activeDepartmentId, "projects")
        XCTAssertTrue(s.canOpen("contract-manager"))
        XCTAssertFalse(s.canOpen("sales"))
        s.setActiveDepartment("banking")
        XCTAssertEqual(s.activeDepartmentId, "projects")
        s.logout()

        XCTAssertNil(s.login("clerk", "iagdemo"))
        XCTAssertTrue(s.canCreate("sales", "Sales Invoices"))
        XCTAssertFalse(s.canEdit("sales", "Sales Invoices"))
        XCTAssertFalse(s.canDelete("sales", "Sales Invoices"))
        XCTAssertFalse(s.canApprove)

        let draft = ErpRecord(
            id: "rbac-draft",
            moduleId: "sales",
            entity: "Sales Invoices",
            title: "SI-TEST",
            subtitle: "RBAC",
            status: "Draft",
            date: "2026-08-25"
        )
        s.addRecord(draft)
        XCTAssertTrue(s.records.contains { $0.id == "rbac-draft" })
        XCTAssertNil(s.submitRecord(draft))
        XCTAssertEqual(draft.status, "Posted")
        XCTAssertNotNil(s.approveRecord(draft))
        XCTAssertNotNil(s.deleteRecord(draft))
        s.logout()

        XCTAssertNil(s.login("admin", "iagdemo"))
        XCTAssertTrue(s.canOpen("fleet"))
        XCTAssertTrue(s.canDelete("sales", "Sales Invoices"))
        XCTAssertTrue(s.canApprove)
        let pending = s.records.first { $0.title == "EXP-2026-019" }!
        XCTAssertNil(s.approveRecord(pending))
        XCTAssertEqual(pending.status, "Approved")
        XCTAssertNil(s.voidRecord(pending))
        XCTAssertEqual(pending.status, "Void")
    }

    func testCustomRolesUseCrudPlusOptionalAppGrants() {
        let lab = RoleDefinition(
            id: "role-lab-tech",
            name: "Lab Tech",
            crud: Crud(view: true, create: true, edit: true, delete: false),
            pagePermissions: [
                pageWildcardKey: .none,
                "lab": Crud(view: true, create: true, edit: true, delete: false),
            ]
        )
        XCTAssertTrue(canAccessModule("Lab Tech", "lab", definition: lab))
        XCTAssertTrue(canCreateIn("Lab Tech", "lab", definition: lab))
        XCTAssertFalse(canAccessModule("Lab Tech", "banking", definition: lab))
        XCTAssertFalse(canAccessModule("Lab Tech", "fleet", definition: lab))
        XCTAssertFalse(canAccessApprovalDesk("Lab Tech"))
        XCTAssertFalse(canDeleteIn("Lab Tech", "lab", definition: lab))
    }

    func testAdminCanCreateCustomRoleAndUserThenThatUserSignsIn() {
        let s = store()
        XCTAssertNotNil(s.saveRole(RoleDefinition(id: "x", name: "Lab Tech")))

        XCTAssertNil(s.login("admin", "iagdemo"))
        XCTAssertNil(s.saveRole(RoleDefinition(
            id: "role-lab-tech",
            name: "Lab Tech",
            description: "Lab bench",
            crud: Crud(view: true, create: true, edit: true, delete: false),
            pagePermissions: [
                pageWildcardKey: .none,
                "lab": Crud(view: true, create: true, edit: true, delete: false),
            ]
        )))
        XCTAssertNil(s.saveWorkspaceUser(username: "labtech", name: "Lina Lab", role: "Lab Tech", password: "iagdemo"))
        s.logout()

        XCTAssertNil(s.login("labtech", "iagdemo"))
        XCTAssertEqual(s.user?.role, "Lab Tech")
        XCTAssertTrue(s.canOpen("lab"))
        XCTAssertFalse(s.canOpen("banking"))
        XCTAssertTrue(s.canCreate("lab"))
        XCTAssertFalse(s.canApprove)
        XCTAssertEqual(s.activeDepartmentId, "lab")
    }

    func testCatalogSeedsEveryWebErpFeature() {
        let modules = erpModules()
        let seed = completeCatalogSeed(modules)
        XCTAssertGreaterThanOrEqual(modules.count, 28)
        for module in modules {
            if module.id == "clock-in" { continue }
            for entity in module.entities {
                XCTAssertTrue(
                    seed.contains { $0.moduleId == module.id && $0.entity == entity },
                    "\(module.id) missing \(entity)"
                )
            }
        }
        let s = store()
        XCTAssertNil(s.login("admin", "iagdemo"))
        XCTAssertEqual(s.visibleModules.count, modules.count)
        XCTAssertTrue(canAccessSpecialNav("Administrator", "analytics"))
        XCTAssertTrue(s.visibleWorkspaceTools.contains { $0.id == "trace" })
        XCTAssertTrue(s.visibleWorkspaceTools.contains { $0.id == "analytics" })
        s.logout()
        XCTAssertNil(s.login("viewer", "iagdemo"))
        XCTAssertTrue(canAccessSpecialNav("Viewer", "guides"))
        XCTAssertFalse(canAccessSpecialNav("Viewer", "analytics"))
        XCTAssertTrue(s.visibleWorkspaceTools.contains { $0.id == "trace" })
        XCTAssertFalse(s.visibleWorkspaceTools.contains { $0.id == "analytics" })
    }

    func testEveryWebDepartmentAndClockInAreOnThePhone() {
        let modules = erpModules()
        let ids = Set(modules.map(\.id))
        for id in webErpDepartmentIds {
            XCTAssertTrue(ids.contains(id), "missing web department \(id)")
        }
        XCTAssertTrue(ids.contains("clock-in"))
        XCTAssertTrue(canAccessModule("Viewer", "clock-in"))
        XCTAssertTrue(canAccessModule("Clerk", "clock-in"))
        XCTAssertTrue(canAccessModule("Contractor", "clock-in"))
        XCTAssertTrue(canCreateIn("Viewer", "clock-in"))

        let s = store()
        XCTAssertNil(s.login("clerk", "iagdemo"))
        XCTAssertTrue(s.canOpen("clock-in"))
        XCTAssertFalse(s.canOpen("payroll"))
        XCTAssertTrue(s.canClockIn)
        XCTAssertFalse(s.geofenceZones().isEmpty)

        let inside = s.punch(kind: "in", latitude: hqLatitude, longitude: hqLongitude, accuracy: 8)
        XCTAssertTrue(inside?.contains("Checked in") == true, inside ?? "nil")
        XCTAssertNotNil(s.openAttendanceToday())
        XCTAssertEqual(s.openAttendanceToday()?.status, "Present")
        XCTAssertEqual(s.openAttendanceToday()?.fields["verification"], "Verified")

        let outside = s.punch(kind: "out", latitude: 0, longitude: 0, accuracy: 8)
        XCTAssertTrue(outside?.localizedCaseInsensitiveContains("outside") == true, outside ?? "nil")
        XCTAssertNotNil(s.openAttendanceToday())
        XCTAssertTrue(s.forEntity("payroll", "Punch Log").contains { $0.status == "Rejected" })

        let out = s.punch(kind: "out", latitude: hqLatitude, longitude: hqLongitude, accuracy: 8)
        XCTAssertTrue(out?.contains("Checked out") == true, out ?? "nil")
        XCTAssertNil(s.openAttendanceToday())
        s.logout()

        XCTAssertNil(s.login("viewer", "iagdemo"))
        XCTAssertTrue(s.canOpen("clock-in"))
        XCTAssertTrue(s.visibleModules.contains { $0.id == "clock-in" })
        XCTAssertTrue(s.punch(kind: "in", latitude: hqLatitude, longitude: hqLongitude, accuracy: 8)?.contains("Checked in") == true)
        s.logout()

        XCTAssertNil(s.login("contractor", "iagdemo"))
        XCTAssertTrue(s.canOpen("clock-in"))
        XCTAssertTrue(s.canOpen("projects"))
        XCTAssertFalse(s.canOpen("payroll"))
    }
}
