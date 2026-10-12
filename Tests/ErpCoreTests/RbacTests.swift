import XCTest
@testable import ErpCore

final class RbacTests: XCTestCase {
    private let testPassword = "unit-test-login"

    private func store() -> ErpStore {
        let s = ErpStore(persistence: MemoryKeyValueStore())
        s.load()
        s.seedTestPasswords(testPassword)
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
        XCTAssertEqual(s.login("nobody", testPassword), "Unknown user.")
        XCTAssertEqual(s.login("viewer", testPassword, departmentId: "banking"), "Your role cannot open that app.")
        XCTAssertFalse(s.isSignedIn)

        XCTAssertNil(s.login("viewer", testPassword))
        XCTAssertEqual(s.user?.role, "Viewer")
        XCTAssertFalse(s.canOpen("banking"))
        XCTAssertTrue(s.canOpen("reports"))
        XCTAssertFalse(s.canApprove)
        XCTAssertFalse(s.visibleModules.contains { $0.id == "banking" })
        XCTAssertTrue(s.visibleModules.contains { $0.id == "reports" })
        s.logout()

        XCTAssertEqual(s.login("contractor", testPassword, departmentId: "banking"), "Your role cannot open that app.")
        XCTAssertNil(s.login("contractor", testPassword))
        XCTAssertEqual(s.activeDepartmentId, "projects")
        XCTAssertNil(s.activeAppId)
        XCTAssertTrue(s.canOpen("contract-manager"))
        XCTAssertFalse(s.canOpen("sales"))
        s.setActiveDepartment("banking")
        XCTAssertEqual(s.activeDepartmentId, "projects")
        s.logout()

        XCTAssertNil(s.login("clerk", testPassword))
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

        XCTAssertNil(s.login("admin", testPassword))
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

        XCTAssertNil(s.login("admin", testPassword))
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
        XCTAssertNil(s.saveWorkspaceUser(username: "labtech", name: "Lina Lab", role: "Lab Tech", password: testPassword))
        s.logout()

        XCTAssertNil(s.login("labtech", testPassword))
        XCTAssertEqual(s.user?.role, "Lab Tech")
        XCTAssertTrue(s.canOpen("lab"))
        XCTAssertFalse(s.canOpen("banking"))
        XCTAssertTrue(s.canCreate("lab"))
        XCTAssertFalse(s.canApprove)
        XCTAssertEqual(s.activeDepartmentId, "lab")
        XCTAssertNil(s.activeAppId)
        XCTAssertEqual(s.visibleSuiteApps.map(\.id), ["lab"])
    }

    func testCatalogSeedsEveryWebErpFeature() {
        let modules = erpModules()
        let seed = completeCatalogSeed(modules)
        XCTAssertGreaterThanOrEqual(modules.count, 28)
        let byId = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, Set($0.entities)) })
        XCTAssertTrue(byId["fleet"]?.contains("Journey Plans") == true)
        XCTAssertTrue(byId["distribution"]?.contains("Beats") == true)
        XCTAssertTrue(byId["payroll"]?.contains("Leave Policies") == true)
        XCTAssertTrue(byId["inventory"]?.contains("Putaway Rules") == true)
        XCTAssertTrue(byId["purchases"]?.contains("Purchase Requisitions") == true)
        XCTAssertTrue(byId["maintenance"]?.contains("Work Orders") == true)
        XCTAssertTrue(byId["farmer-traceability"]?.contains("Farmers") == true)
        for module in modules {
            XCTAssertFalse(module.icon.isEmpty, "\(module.id) has no icon")
            if module.id == "clock-in" { continue }
            for entity in module.entities {
                XCTAssertTrue(
                    seed.contains { $0.moduleId == module.id && $0.entity == entity },
                    "\(module.id) missing \(entity)"
                )
            }
        }
        let s = store()
        XCTAssertNil(s.login("admin", testPassword))
        XCTAssertEqual(s.visibleModules.count, modules.count)
        XCTAssertTrue(canAccessSpecialNav("Administrator", "analytics"))
        XCTAssertTrue(s.visibleWorkspaceTools.contains { $0.id == "trace" })
        XCTAssertTrue(s.visibleWorkspaceTools.contains { $0.id == "analytics" })
        s.logout()
        XCTAssertNil(s.login("viewer", testPassword))
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
        XCTAssertNil(s.login("clerk", testPassword))
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

        XCTAssertNil(s.login("viewer", testPassword))
        XCTAssertTrue(s.canOpen("clock-in"))
        XCTAssertTrue(s.visibleModules.contains { $0.id == "clock-in" })
        XCTAssertTrue(s.punch(kind: "in", latitude: hqLatitude, longitude: hqLongitude, accuracy: 8)?.contains("Checked in") == true)
        s.logout()

        XCTAssertNil(s.login("contractor", testPassword))
        XCTAssertTrue(s.canOpen("clock-in"))
        XCTAssertTrue(s.canOpen("projects"))
        XCTAssertFalse(s.canOpen("payroll"))
    }

    func testSuiteAppsAreSeparateFullTools() {
        XCTAssertEqual(suiteApps.map(\.id).sorted(), [
            "contracts", "crm", "dms", "finance", "fleet", "hr", "inventory", "lab", "logistics", "maintenance", "pos",
            "procurement", "production", "projects", "quality", "requests", "sales", "security", "trace",
        ].sorted())
        XCTAssertEqual(suiteAppById("dms")?.label, "Distribution")
        XCTAssertEqual(suiteAppById("sales")?.label, "ERP")
        XCTAssertEqual(suiteAppById("pos")?.label, "BurrP!")
        XCTAssertEqual(suiteAppById("projects")?.label, "Project Manager")
        XCTAssertEqual(suiteAppById("contracts")?.label, "Contract Manager")
        XCTAssertEqual(suiteAppById("fleet")?.label, "Fleet")
        XCTAssertEqual(suiteAppById("inventory")?.moduleIds, ["inventory"])
        XCTAssertEqual(suiteAppById("lab")?.moduleIds, ["lab"])
        XCTAssertEqual(suiteAppById("procurement")?.moduleIds, ["purchases"])
        XCTAssertEqual(suiteAppById("logistics")?.moduleIds, ["logistics", "distribution"])
        XCTAssertFalse(suiteAppById("quality")?.moduleIds.contains("lab") == true)
        XCTAssertTrue(canOpenSuiteApp("Administrator", "crm"))
        XCTAssertTrue(canOpenSuiteApp("Administrator", "pos"))
        XCTAssertTrue(canOpenSuiteApp("Administrator", "contracts"))
        XCTAssertTrue(canOpenSuiteApp("Administrator", "dms"))
        XCTAssertTrue(canOpenSuiteApp("Administrator", "fleet"))
        XCTAssertEqual(suiteAppById("records")?.id, "dms")
        XCTAssertEqual(suiteAppById("contract-manager")?.id, "contracts")
        XCTAssertTrue(canOpenSuiteApp("Procurement", "procurement"))
        XCTAssertFalse(canOpenSuiteApp("Procurement", "security"))
        XCTAssertTrue(canOpenSuiteApp("HR", "hr"))
        XCTAssertFalse(canOpenSuiteApp("Viewer", "security"))

        let s = store()
        XCTAssertNil(s.login("admin", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertEqual(s.visibleSuiteApps.count, suiteApps.count)
        s.openApp("finance")
        XCTAssertEqual(s.activeAppId, "finance")
        XCTAssertTrue(s.appModules.contains { $0.id == "banking" })
        XCTAssertFalse(s.appModules.contains { $0.id == "security" })
        s.openApp("security")
        XCTAssertEqual(s.activeAppId, "security")
        XCTAssertEqual(s.appModules.map(\.id), ["security"])
        s.closeApp()
        XCTAssertNil(s.activeAppId)
        s.logout()

        XCTAssertNil(s.login("procurement", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertTrue(s.visibleSuiteApps.contains { $0.id == "procurement" })
        XCTAssertTrue(s.visibleSuiteApps.contains { $0.id == "finance" })
        XCTAssertFalse(s.visibleSuiteApps.contains { $0.id == "security" })
        s.openApp("procurement")
        XCTAssertTrue(s.appModules.contains { $0.id == "purchases" })
        XCTAssertFalse(s.appModules.contains { $0.id == "banking" })
        s.logout()

        XCTAssertNil(s.login("hr", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertTrue(s.visibleSuiteApps.contains { $0.id == "hr" })
        s.logout()

        XCTAssertEqual(s.login("clerk", testPassword, departmentId: "security"), "Your role cannot open that app.")
        XCTAssertNil(s.login("clerk", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertTrue(s.visibleSuiteApps.contains { $0.id == "finance" })
    }

    func testQuickActionsFollowAppAndRbac() {
        let s = store()
        XCTAssertNil(s.login("admin", testPassword))
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "clock" })
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "approvals" })
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "access" })
        XCTAssertEqual(
            Set(s.launcherQuickActions.compactMap(\.appId)),
            Set(s.visibleSuiteApps.map(\.id))
        )
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "receipt" })
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "invoice" })
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "lead" })
        XCTAssertTrue(s.launcherQuickActions.contains { $0.id == "po" })
        s.openApp("finance")
        let financeIds = s.homeQuickActions.map(\.id)
        XCTAssertTrue(financeIds.contains("clock"))
        XCTAssertTrue(financeIds.contains("receipt"))
        XCTAssertTrue(financeIds.contains("payment"))
        XCTAssertFalse(financeIds.contains("po"))
        XCTAssertLessThanOrEqual(s.homeQuickActions.count, 8)
        s.openApp("sales")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "invoice" })
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "customer" })
        XCTAssertFalse(s.homeQuickActions.contains { $0.id == "lead" })
        s.openApp("crm")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "lead" })
        s.openApp("pos")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "ticket" })
        s.openApp("contracts")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "contract" })
        s.openApp("fleet")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "vehicle" })
        s.openApp("dms")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "folder" })
        s.logout()

        XCTAssertNil(s.login("viewer", testPassword))
        XCTAssertNil(s.activeAppId)
        s.openApp("finance")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "clock" })
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "reports" })
        XCTAssertFalse(s.homeQuickActions.contains { $0.id == "receipt" })
        XCTAssertFalse(s.homeQuickActions.contains { $0.id == "approvals" })
        s.logout()

        XCTAssertNil(s.login("procurement", testPassword))
        XCTAssertNil(s.activeAppId)
        s.openApp("procurement")
        XCTAssertTrue(s.homeQuickActions.contains { $0.id == "po" })
        XCTAssertFalse(s.homeQuickActions.contains { $0.id == "invoice" })
    }

    func testWelcomeStatsShowLiveCounts() {
        let s = store()
        XCTAssertNil(s.login("admin", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertEqual(s.welcomeStats.map(\.id), ["apps", "records", "todo", "clock"])
        XCTAssertEqual(s.welcomeStats.first { $0.id == "apps" }?.value, "\(s.visibleSuiteApps.count)")
        XCTAssertEqual(s.welcomeStats.first { $0.id == "clock" }?.value, "Out")
        s.openApp("finance")
        XCTAssertEqual(s.welcomeStats.map(\.id), ["desks", "records", "todo", "clock"])
        XCTAssertEqual(s.welcomeStats.first { $0.id == "desks" }?.value, "\(s.appModules.count)")
        s.logout()

        XCTAssertNil(s.login("viewer", testPassword))
        XCTAssertNil(s.activeAppId)
        XCTAssertFalse(s.welcomeStats.contains { $0.id == "todo" })
        XCTAssertTrue(s.welcomeStats.contains { $0.id == "apps" })
        XCTAssertTrue(s.welcomeStats.contains { $0.id == "clock" })
    }

    func testFleetAndDistributionMapsPlotKnownPlaces() {
        let modules = erpModules()
        let vehicles = modules.first { $0.id == "fleet" }?.seed ?? []
        let fleet = fleetMapPins(vehicles)
        XCTAssertEqual(fleet.map(\.title).sorted(), ["UAV 778C", "UAX 221K", "UBE 104M"])
        XCTAssertEqual(fleet.first { $0.title == "UAX 221K" }?.latitude ?? 0, 0.3853, accuracy: 0.0001)
        XCTAssertEqual(fleet.first { $0.title == "UAV 778C" }?.longitude ?? 0, 31.736111, accuracy: 0.0001)

        let stops = distributionMapPins(modules.first { $0.id == "distribution" }?.seed ?? [])
        XCTAssertEqual(stops.count, 4)
        XCTAssertTrue(stops.contains { $0.title == "DO-2026-088" })
        XCTAssertEqual(stops.first { $0.title == "DO-2026-088" }?.latitude ?? 0, 0.3372, accuracy: 0.0001)

        let named = seedRecord(module: "fleet", entity: "Vehicles", title: "Van", subtitle: "Kololo shop", status: "Active")
        XCTAssertEqual(fleetMapPins([named]).count, 1)
        let fuel = seedRecord(module: "fleet", entity: "Fuel Requests", title: "FUEL", subtitle: "Namanve", status: "Pending")
        XCTAssertTrue(fleetMapPins([fuel]).isEmpty)

        let fleetTabs = shellTabs(appId: "fleet", role: "Administrator", canApprove: true, canClockIn: true)
        XCTAssertEqual(Array(fleetTabs.map(\.id).prefix(3)), ["home", "map", "vehicles"])
        XCTAssertEqual(fleetTabs.first { $0.id == "map" }?.moduleId, "fleet")
        let deliveryTabs = shellTabs(appId: "logistics", role: "Administrator", canApprove: true, canClockIn: true)
        XCTAssertEqual(deliveryTabs.first { $0.id == "map" }?.moduleId, "distribution")
    }

    func testNoticesStayOutOfTheApprovalQueue() {
        let s = store()
        XCTAssertNil(s.login("admin", testPassword))
        let waiting = Set(s.pendingApprovals.map(\.id))
        XCTAssertFalse(s.notices.isEmpty)
        XCTAssertTrue(s.notices.allSatisfy { !waiting.contains($0.id) && s.isNoticeStatus($0.status) && !s.isOpenStatus($0.status) })
        XCTAssertTrue(s.notices.contains { $0.status == "Approved" })
        XCTAssertFalse(s.notices.contains { $0.status == "Pending" || $0.status == "Active" })
        s.logout()

        XCTAssertNil(s.login("viewer", testPassword))
        XCTAssertFalse(s.canApprove)
        XCTAssertFalse(s.notices.isEmpty)
        XCTAssertTrue(s.notices.allSatisfy { !s.pendingApprovals.map(\.id).contains($0.id) })
    }

    func testPasswordsAreHashedAndHaveNoSharedDefault() {
        let persistence = MemoryKeyValueStore()
        let s = ErpStore(persistence: persistence)
        s.load()
        XCTAssertEqual(s.login("admin", "anything-at-all"), "No password set. Use Forgot password to create one.")
        XCTAssertNil(s.resetPassword(username: "admin", newPassword: testPassword, confirm: testPassword))
        XCTAssertNil(s.login("admin", testPassword))
        let raw = persistence.get(storeKey) ?? ""
        XCTAssertFalse(raw.contains(testPassword))
        XCTAssertTrue(raw.contains(passwordDigest("admin", testPassword)))
    }

    func testContinueOnThisDeviceSavesFirstPasswordAndAcceptsLiveEmail() {
        let s = ErpStore(persistence: MemoryKeyValueStore())
        s.load()
        XCTAssertNil(s.loginOnThisDevice("admin@iag.local", "ChangeMe"))
        XCTAssertTrue(s.isSignedIn)
        XCTAssertEqual(s.user?.username, "admin")
        XCTAssertFalse(s.remoteSession)
        s.logout()
        XCTAssertNil(s.login("admin", "ChangeMe"))
    }

    func testContinueOnThisDeviceReplacesWrongLocalPassword() {
        let s = ErpStore(persistence: MemoryKeyValueStore())
        s.load()
        XCTAssertNil(s.loginOnThisDevice("admin", "ChangeMe"))
        s.logout()
        XCTAssertNil(s.loginOnThisDevice("admin", "NewPass1"))
        s.logout()
        XCTAssertNil(s.login("admin", "NewPass1"))
        XCTAssertEqual(s.login("admin", "ChangeMe"), "Wrong password.")
    }

    func testUserNoticeHidesTechnicalLoginErrors() {
        XCTAssertEqual(userNotice(from: "Wrong password.").title, "Couldn't sign in")
        XCTAssertEqual(
            userNotice(from: ErpStore.describeLiveLoginFailure(password: "shortpw", apiMessage: "Invalid email/username or password.")).title,
            "Couldn't sign in"
        )
        XCTAssertFalse(userNotice(from: "HTTP 401 Unauthorized").message.lowercased().contains("401"))
        XCTAssertEqual(userNotice(from: "Can't reach the workspace.").title, "No connection")
        XCTAssertEqual(userNotice(from: "Use at least 6 characters.").title, "Password too short")
    }

    func testLegacyPlaintextPasswordsAreMigratedOnLoad() {
        let persistence = MemoryKeyValueStore()
        let legacy = "legacy-secret"
        persistence.put(storeKey, "{\"passwords\":{\"admin\":\"\(legacy)\"}}")
        let s = ErpStore(persistence: persistence)
        s.load()
        XCTAssertNil(s.login("admin", legacy))
        let raw = persistence.get(storeKey) ?? ""
        XCTAssertFalse(raw.contains(legacy))
        XCTAssertTrue(raw.contains(passwordDigest("admin", legacy)))
    }

    func testAdoptApiRolesKeepsDatabaseSystemRoles() {
        let api = [
            RoleDefinition(id: "role-admin-db", name: "Administrator", crud: .full, system: true),
            RoleDefinition(
                id: "r1",
                name: "Field Clerk",
                crud: Crud(view: true, create: true, edit: false, delete: false),
                system: false,
                pagePermissions: ["sales": Crud(view: true, create: true, edit: false, delete: false)]
            ),
        ]
        let adopted = adoptApiRoles(api)
        XCTAssertEqual(findRoleDefinition(adopted, "Administrator")?.id, "role-admin-db")
        XCTAssertTrue(findRoleDefinition(adopted, "Field Clerk")?.crud.create == true)
        XCTAssertEqual(findRoleDefinition(adopted, "Field Clerk")?.pagePermissions["sales"]?.view, true)
        XCTAssertNotNil(findRoleDefinition(adopted, "Clerk"))
        let merged = mergeStoredRoles(api)
        XCTAssertNotEqual(findRoleDefinition(merged, "Administrator")?.id, "role-admin-db")
        XCTAssertEqual(findRoleDefinition(merged, "Field Clerk")?.id, "r1")
    }
}
