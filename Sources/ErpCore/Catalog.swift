import Foundation

public func erpModules() -> [ErpModule] {
    [
        ErpModule(id: "banking", label: "Banking", group: "Treasury", description: "Bank and cash accounts linked to the chart of accounts, then statements, transfers, and reconciliations.", icon: "building.columns", color: 0xFF0369A1, entities: ["Bank & Cash Accounts", "Inter Account Transfers", "Bank Statements", "Reconciliations"], seed: [
            seedRecord(module: "banking", entity: "Bank & Cash Accounts", title: "Stanbic Current — UGX", subtitle: "**** 4412 · Main Shop", status: "Active", amount: 186_400_000, fields: ["Institution": "Stanbic", "Currency": "UGX", "GL": "1000 Cash-UGX"]),
            seedRecord(module: "banking", entity: "Bank & Cash Accounts", title: "Centenary — Operations", subtitle: "**** 8821 · HQ", status: "Active", amount: 54_200_000),
            seedRecord(module: "banking", entity: "Bank & Cash Accounts", title: "Cash till — Front", subtitle: "POS float", status: "Active", amount: 850_000),
        ]),
        ErpModule(id: "receipts-payments", label: "Receipts & Payments", group: "Treasury", description: "Money in and money out — receipts, payments, and the rules that categorise them.", icon: "arrow.left.arrow.right", color: 0xFF0F766E, entities: ["Receipts", "Payments", "Receipt Rules", "Payment Rules"], seed: [
            seedRecord(module: "receipts-payments", entity: "Receipts", title: "RCPT-2026-0412", subtitle: "Nakumatt Kisementi", status: "Cleared", amount: 12_800_000),
        ]),
        ErpModule(id: "expense-claims", label: "Expense Claims", group: "Requests", description: "Payers and claims paid with personal funds or allowance rates.", icon: "receipt", color: 0xFFB45309, entities: ["Expense Claim Payers", "Expense Claims"], approvalEntities: ["Expense Claims"], seed: [
            seedRecord(module: "expense-claims", entity: "Expense Claims", title: "EXP-2026-019", subtitle: "Field travel — Masaka", status: "Pending", amount: 420_000, fields: ["Claimant": "Daniel Okello", "Account": "Travel"]),
            seedRecord(module: "expense-claims", entity: "Expense Claims", title: "EXP-2026-018", subtitle: "Client lunch", status: "Approved", amount: 180_000, fields: ["Claimant": "Sarah Nambi"]),
        ]),
        ErpModule(id: "general-requests", label: "General Requests", group: "Requests", description: "General (non-project) requests through accounts, GM, CEO, and finance.", icon: "list.clipboard", color: 0xFF7C3AED, entities: ["General Requests"], approvalEntities: ["General Requests"], seed: [
            seedRecord(module: "general-requests", entity: "General Requests", title: "REQ-2026-077", subtitle: "New laptop for QA", status: "Pending", fields: ["Requested by": "Lab Manager", "Priority": "High"]),
        ]),
        ErpModule(id: "oral-payment-requests", label: "Oral Payment Requests", group: "Requests", description: "Verbal payment requests captured and sent through the approval desk.", icon: "mic", color: 0xFFC2410C, entities: ["Oral Payment Requests"], approvalEntities: ["Oral Payment Requests"], seed: [
            seedRecord(module: "oral-payment-requests", entity: "Oral Payment Requests", title: "OPR-2026-011", subtitle: "Casual wages — loading", status: "Pending", amount: 350_000),
        ]),
        ErpModule(id: "sales", label: "Sales", group: "Commercial", description: "Customers, quotes, orders, invoices, credit notes, and related sales documents.", icon: "storefront", color: 0xFF059669, entities: ["Customers", "Customer Ledgers", "Sales Quotes", "Sales Orders", "Sales Invoices", "Credit Notes", "Late Payment Fees", "Delivery Notes", "Billable Time", "Billable Expenses", "Withholding Tax Receipts", "Customer Portals", "Recurring Sales Invoices", "Revenue Contracts"], seed: [
            seedRecord(module: "sales", entity: "Customers", title: "Cafe Javas Kampala", subtitle: "CUST-0142", status: "Active", amount: 6_200_000),
            seedRecord(module: "sales", entity: "Sales Invoices", title: "SI-2026-188", subtitle: "Cafe Javas Kampala", status: "Posted", amount: 4_200_000),
        ]),
        ErpModule(id: "purchases", label: "Purchases", group: "Commercial", description: "Suppliers, quotes, orders, invoices, goods receipts, and withholding tax.", icon: "cart", color: 0xFF2563EB, entities: ["Suppliers", "Supplier Ledgers", "Purchase Quotes", "Purchase Orders", "Purchase Invoices", "Debit Notes", "Goods Receipts", "Recurring Purchase Invoices", "Withholding Tax"], seed: [
            seedRecord(module: "purchases", entity: "Suppliers", title: "Kyagalanyi Coffee Ltd", subtitle: "SUP-0031", status: "Active"),
            seedRecord(module: "purchases", entity: "Purchase Orders", title: "PO-2026-044", subtitle: "Green bean — AA", status: "Open", amount: 98_000_000),
        ]),
        ErpModule(id: "inventory", label: "Inventory", group: "Inventory & production", description: "Items, warehouses, stock movements, green bean, roast, packaging, and stocktakes.", icon: "cube.box", color: 0xFF0E7490, entities: ["Inventory Items", "Non-inventory Items", "Inventory Kits", "Stock In", "Inventory Transfers", "Warehouses & Locations", "Inventory Write-offs", "Inventory Sales", "Green Bean Intakes", "Production Orders", "Roast Batches", "Quality Checks", "Packaging Runs", "Stocktakes", "Landed Costs"], seed: [
            seedRecord(module: "inventory", entity: "Inventory Items", title: "Arabica AA — green", subtitle: "INV-BEAN-AA", status: "Active"),
            seedRecord(module: "inventory", entity: "Warehouses & Locations", title: "Main warehouse", subtitle: "Namanve", status: "Active"),
        ]),
        ErpModule(id: "projects", label: "Project Manager", group: "Projects", description: "Projects, Gantt, material and IPC requests, equipment, documents, and work programs.", icon: "briefcase", color: 0xFF4F46E5, entities: ["New Project", "Project Updates", "Gantt Chart", "Project Managers", "Material Requests", "Payment Requests (IPC)", "Equipment & Vehicle Requests", "Document Requests", "Work Programs", "Variations of Work"], approvalEntities: ["Payment Requests (IPC)", "Material Requests", "Equipment & Vehicle Requests", "Document Requests"], seed: [
            seedRecord(module: "projects", entity: "New Project", title: "Roastery expansion", subtitle: "PRJ-004", status: "Active", amount: 420_000_000),
            seedRecord(module: "projects", entity: "Payment Requests (IPC)", title: "IPC-2026-006", subtitle: "Civil works — certificate 2", status: "Pending", amount: 48_000_000),
            seedRecord(module: "projects", entity: "Material Requests", title: "MR-2026-021", subtitle: "Cement and steel", status: "Approved"),
        ]),
        ErpModule(id: "contract-manager", label: "Contract Management", group: "Projects", description: "Contracts, contractors, amendments, invoices, bonds, and completion certificates.", icon: "doc.badge.checkmark", color: 0xFF047857, entities: ["Contracts", "Contractors", "Contract Amendments", "Contractor Invoices", "Contractor Ledgers", "Performance Bonds", "Completion Certificates"], seed: [
            seedRecord(module: "contract-manager", entity: "Contracts", title: "CTR-2026-012", subtitle: "Roastery civil works", status: "Active", amount: 180_000_000),
            seedRecord(module: "contract-manager", entity: "Contractors", title: "Mukwano Builders", subtitle: "CTR-012", status: "Active"),
            seedRecord(module: "contract-manager", entity: "Contractor Invoices", title: "CINV-2026-008", subtitle: "Certificate 2", status: "Pending", amount: 48_000_000),
        ]),
        ErpModule(id: "fleet", label: "Fleet", group: "Operations", description: "Vehicles, drivers, fuel, trips, maintenance, map analytics, and fleet cost.", icon: "car.fill", color: 0xFFD97706, entities: ["Vehicles", "Drivers", "Fuel Requests", "Fuel Logs", "Trip Requests", "Maintenance Requests", "Map Analytics", "Service Reminders", "Fleet Cost Report"], approvalEntities: ["Fuel Requests", "Trip Requests", "Maintenance Requests"], seed: [
            seedRecord(module: "fleet", entity: "Vehicles", title: "UAX 221K", subtitle: "Isuzu NPR", status: "Active"),
            seedRecord(module: "fleet", entity: "Drivers", title: "Joseph Ssewanyana", subtitle: "DRV-008", status: "Active"),
            seedRecord(module: "fleet", entity: "Fuel Requests", title: "FUEL-2026-044", subtitle: "UAX 221K · Namanve", status: "Pending", amount: 420_000),
        ]),
        ErpModule(id: "security", label: "Security", group: "Operations", description: "Gate passes, visitor passes, and security incidents.", icon: "shield.checkered", color: 0xFF334155, entities: ["Gate Passes", "Visitor Passes", "Security Incidents"], seed: [
            seedRecord(module: "security", entity: "Visitor Passes", title: "VP-2026-331", subtitle: "URA audit team", status: "Open", date: todayIsoDate()),
        ]),
        ErpModule(id: "crm", label: "CRM", group: "Commercial", description: "Accounts, leads, opportunities, contacts, follow-ups, and complaints.", icon: "person.3", color: 0xFFBE123C, entities: ["Accounts", "Leads", "Opportunities", "Contacts", "Follow-ups", "Complaints", "Activities"], seed: [
            seedRecord(module: "crm", entity: "Accounts", title: "Shoprite Uganda", subtitle: "Retail", status: "Active"),
            seedRecord(module: "crm", entity: "Leads", title: "Shoprite Lugogo", subtitle: "Retail listing", status: "Open"),
            seedRecord(module: "crm", entity: "Opportunities", title: "OPP-2026-014", subtitle: "Listing pack · Q4", status: "Open", amount: 48_000_000),
        ]),
        ErpModule(id: "logistics", label: "Logistics", group: "Operations", description: "Shipments, dispatch board, routes, proof of delivery, and carriers.", icon: "map", color: 0xFF0F766E, entities: ["Shipments", "Dispatch Board", "Routes", "Proof of Delivery", "Carriers"], seed: [
            seedRecord(module: "logistics", entity: "Shipments", title: "SHP-2026-077", subtitle: "Namanve → Javas Kololo", status: "In transit"),
        ]),
        ErpModule(id: "distribution", label: "Distribution", group: "Operations", description: "Distribution orders, picking, packing, delivery runs, allocations, and returns.", icon: "arrow.triangle.branch", color: 0xFF0D9488, entities: ["Distribution Orders", "Picking Lists", "Packing Lists", "Delivery Runs", "Stock Allocations", "Distribution Returns"], seed: [
            seedRecord(module: "distribution", entity: "Delivery Runs", title: "RUN-2026-14", subtitle: "Kampala city loop", status: "Scheduled", date: todayIsoDate()),
        ]),
        ErpModule(id: "rnd", label: "R&D", group: "Quality", description: "Experiments, formulations, sensory panels, spec sheets, pilots, and cost models.", icon: "flask", color: 0xFF7C3AED, entities: ["Experiments", "Formulations", "Sensory Panels", "Spec Sheets", "Pilot Batches", "Cost Models", "AI Insights"]),
        ErpModule(id: "lab", label: "Lab", group: "Quality", description: "Lab requests, samples, trials, methods, calibrations, results, and stability.", icon: "testtube.2", color: 0xFF6D28D9, entities: ["Product Simulations", "Lab Requests", "Lab Samples", "Lab Trials", "Lab Methods", "Instrument Calibrations", "Lab Results", "Stability Studies"], seed: [
            seedRecord(module: "lab", entity: "Lab Results", title: "LAB-2026-033", subtitle: "Cupping — AA lot 12", status: "Verified"),
        ]),
        ErpModule(id: "qa", label: "Quality Assurance", group: "Quality", description: "Incoming and in-process checks, release decisions, NCs, CAPA, and hold logs.", icon: "checkmark.seal", color: 0xFF0369A1, entities: ["Quality Checks", "Incoming Inspections", "In-process Checks", "Release Decisions", "Non-conformances", "CAPA Actions", "Hold & Release Log"], seed: [
            seedRecord(module: "qa", entity: "Quality Checks", title: "QC-2026-090", subtitle: "Roast batch RB-441", status: "Released"),
        ]),
        ErpModule(id: "production", label: "Production", group: "Inventory & production", description: "Plans, orders, machines, BOMs, batches, roast, packaging, downtime, and yield.", icon: "gearshape.2", color: 0xFFB45309, entities: ["Production Plans", "Production Orders", "Machines", "Bill of Materials", "Batch Records", "Roast Batches", "Packaging Runs", "Downtime Logs", "Yield Reports"], seed: [
            seedRecord(module: "production", entity: "Production Orders", title: "MO-2026-118", subtitle: "House blend 250g", status: "In progress"),
        ]),
        ErpModule(id: "benchmark", label: "Work Systems", group: "Quality", description: "Work systems, benchmarks, KPIs, cycle time, productivity, gaps, and improvements.", icon: "chart.bar", color: 0xFF57534E, entities: ["Work Systems", "Benchmark Studies", "KPI Definitions", "Cycle Time Studies", "Productivity Scores", "Gap Analyses", "Improvement Actions"]),
        ErpModule(id: "pos", label: "POS", group: "Commercial", description: "Front-of-house restaurant POS: dine-in floor, KOTs, receipts, kitchen display, and shift close.", icon: "creditcard", color: 0xFF0F766E, entities: ["POS Terminal", "POS Locations", "POS Products", "POS Services", "POS Stock In", "Registers", "Cash Sessions", "Dining Tables", "Open Tickets", "POS Sales", "POS Returns", "Daily Closings"], seed: [
            seedRecord(module: "pos", entity: "POS Terminal", title: "Front Till", subtitle: "Main Shop", status: "Active"),
            seedRecord(module: "pos", entity: "Open Tickets", title: "T-104", subtitle: "Table 6 · dine-in", status: "Open", amount: 86_000),
            seedRecord(module: "pos", entity: "POS Sales", title: "POS-20260824-0012", subtitle: "Front Till · Cash", status: "Paid", amount: 28_500),
        ]),
        ErpModule(id: "payroll", label: "HR & Payroll", group: "People", description: "Employees, attendance, leave, payroll runs, payslips, and statutory remittances.", icon: "person.crop.rectangle", color: 0xFF7C3AED, entities: ["Employees", "Departments", "Sites", "Blocks", "Attendance", "Punch Log", "Attendance Exceptions", "Attendance Summary", "Leave Requests", "Holidays", "Job Positions", "Onboarding", "Create Payroll", "Payroll Runs", "Payslip Items", "Payslips", "Recurring Payslips", "Statutory Remittances"], approvalEntities: ["Leave Requests"], seed: [
            seedRecord(module: "payroll", entity: "Employees", title: "Sarah Nambi", subtitle: "Sales · EMP-014", status: "Active", fields: ["Department": "Sales"]),
            seedRecord(module: "payroll", entity: "Employees", title: "Daniel Okello", subtitle: "Operations · EMP-022", status: "Active", fields: ["Department": "Operations"]),
            seedRecord(module: "payroll", entity: "Sites", title: "IAG Head Office", subtitle: "Kampala · 150 m fence", status: "Active", fields: ["Code": "SITE-HQ", "Address": "Kampala", "Latitude": "0.347596", "Longitude": "32.582520", "Radius (m)": "150"]),
            seedRecord(module: "payroll", entity: "Sites", title: "Africa Coffee Park", subtitle: "Masaka · 250 m fence", status: "Active", fields: ["Code": "SITE-ACP", "Address": "Masaka", "Latitude": "-0.341111", "Longitude": "31.736111", "Radius (m)": "250"]),
            seedRecord(module: "payroll", entity: "Blocks", title: "ACP Wet mill", subtitle: "Africa Coffee Park", status: "Active", fields: ["Latitude": "-0.341111", "Longitude": "31.736111", "Radius (m)": "80"]),
            seedRecord(module: "payroll", entity: "Leave Requests", title: "LV-2026-009", subtitle: "Sarah Nambi · annual", status: "Pending"),
        ]),
        ErpModule(id: "clock-in", label: "Clock In", group: "People", description: "Geofence clock-in and clock-out for every staff login — same Sites and Blocks as HR.", icon: "clock", color: 0xFFEA580C, entities: ["Clock In", "My punches", "Punch Log"], seed: []),
        ErpModule(id: "investments", label: "Investments", group: "Accounting", description: "Investment holdings and related accounting.", icon: "chart.pie", color: 0xFF0F766E, entities: ["Investments"]),
        ErpModule(id: "assets", label: "Fixed Assets", group: "Accounting", description: "Fixed and intangible assets, depreciation, amortization, and leases.", icon: "building.2", color: 0xFF1D4ED8, entities: ["Fixed Assets", "Depreciation Entries", "Intangible Assets", "Amortization Entries", "Leases"], seed: [
            seedRecord(module: "assets", entity: "Fixed Assets", title: "Probat roaster P12", subtitle: "FA-ROAST-01", status: "Active", amount: 310_000_000),
        ]),
        ErpModule(id: "capital", label: "Capital Accounts", group: "Accounting", description: "Capital accounts, subaccounts, and share-based payments.", icon: "wallet.pass", color: 0xFF4338CA, entities: ["Capital Accounts", "Capital Subaccounts", "Share-based Payments"]),
        ErpModule(id: "accounts", label: "Accounts", group: "Accounting", description: "Chart of accounts, journals, matching, provisions, ledgers, and trial balance.", icon: "book", color: 0xFF0F172A, entities: ["Chart of Accounts", "Control Accounts", "Special Accounts", "Journal Entries", "Recurring Journal Entries", "Matching Entries", "Provisions", "Ledgers", "Trial Balance"], seed: [
            seedRecord(module: "accounts", entity: "Journal Entries", title: "JE-2026-240", subtitle: "Roast depreciation", status: "Posted", amount: 2_100_000),
        ]),
        ErpModule(id: "folders", label: "Cabinets & Folders", group: "Records", description: "Cabinets, folders, and file requests for the document store.", icon: "folder", color: 0xFFA16207, entities: ["Cabinets", "Folders", "File Requests"], seed: [
            seedRecord(module: "folders", entity: "Cabinets", title: "Statutory", subtitle: "Finance packs", status: "Active"),
            seedRecord(module: "folders", entity: "Folders", title: "Finance — 2026", subtitle: "Statutory packs", status: "Active"),
            seedRecord(module: "folders", entity: "File Requests", title: "FR-2026-009", subtitle: "URA TIN pack", status: "Open"),
        ]),
        ErpModule(id: "documents", label: "DMS Documents", group: "Records", description: "Documents, incoming files, versions, shares, and attachment history.", icon: "doc", color: 0xFF57534E, entities: ["Documents", "Incoming Files", "Versions", "Shares", "Attachments", "History", "Deleted Records"], seed: [
            seedRecord(module: "documents", entity: "Documents", title: "Lease — Namanve warehouse", subtitle: "Legal · PDF", status: "Active"),
            seedRecord(module: "documents", entity: "Incoming Files", title: "Supplier COA pack", subtitle: "Kyagalanyi", status: "Open"),
        ]),
        ErpModule(id: "reports", label: "Reports", group: "Accounting", description: "Balance sheet, P&L, cash flow, aged ledgers, tax, and inventory value.", icon: "chart.bar.doc.horizontal", color: 0xFF0369A1, entities: ["Balance Sheet", "Profit & Loss", "Accounting Operations", "Management Analysis", "Profit & Loss by Class", "Division Exception Report", "Cash Flow", "Cash Flow Indirect", "Trial Balance", "Ledgers", "Statement of Changes in Equity", "Other Comprehensive Income", "Budget vs Actual", "Forecast P&L", "Notes to Financial Statements", "Control Account Reconciliation", "Bank Reconciliation", "Integrity Tests", "Field Audit Log", "Aged Receivables", "Aged Payables", "Customer Statements", "Supplier Statements", "Tax Summary", "Inventory Value Summary"], seed: [
            seedRecord(module: "reports", entity: "Profit & Loss", title: "P&L — August 2026", subtitle: "Net profit UGX 18.4M", status: "Draft"),
        ]),
    ]
}

public func entityCode(_ entity: String) -> String {
    let parts = entity.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { !$0.isEmpty }
    if parts.isEmpty { return "REC" }
    if parts.count == 1 { return String(parts[0].prefix(3)).uppercased() }
    return parts.prefix(4).map { String($0.prefix(1)).uppercased() }.joined()
}

public func sampleStatus(for entity: String) -> String {
    let e = entity.lowercased()
    if e.contains("request") { return "Pending" }
    if e.contains("report") || e.contains("balance") || e.contains("profit") || e.contains("cash flow") || e.contains("forecast") {
        return "Draft"
    }
    if e.contains("invoice") || e.contains("journal") { return "Posted" }
    return "Active"
}

public func sampleAmount(for entity: String) -> Double? {
    let e = entity.lowercased()
    if ["invoice", "order", "payment", "receipt", "claim", "payroll", "transfer", "fee"].contains(where: { e.contains($0) }) {
        return 1_250_000
    }
    return nil
}

public func sampleRecord(module: ErpModule, entity: String) -> ErpRecord {
    seedRecord(
        module: module.id,
        entity: entity,
        title: "\(entityCode(entity))-2026-001",
        subtitle: "\(module.label) · demo",
        status: sampleStatus(for: entity),
        amount: sampleAmount(for: entity),
        fields: ["Source": "Demo catalog"]
    )
}

public func completeCatalogSeed(_ modules: [ErpModule] = erpModules()) -> [ErpRecord] {
    modules.flatMap { module in
        if module.id == "clock-in" { return [ErpRecord]() }
        let grouped = Dictionary(grouping: module.seed, by: \.entity)
        return module.entities.flatMap { entity -> [ErpRecord] in
            if let rows = grouped[entity], !rows.isEmpty { return rows }
            return [sampleRecord(module: module, entity: entity)]
        }
    }
}

public func reportLines(for entity: String) -> [(String, String)] {
    switch entity {
    case "Balance Sheet":
        return [("Assets", "UGX 2.4B"), ("Liabilities", "UGX 890M"), ("Equity", "UGX 1.5B")]
    case "Profit & Loss", "Profit & Loss by Class", "Forecast P&L":
        return [("Revenue", "UGX 410M"), ("Cost of sales", "UGX 186M"), ("Net profit", "UGX 124M")]
    case "Cash Flow", "Cash Flow Indirect":
        return [("Operating", "UGX 92M"), ("Investing", "UGX -18M"), ("Financing", "UGX -12M")]
    case "Trial Balance":
        return [("Debits", "UGX 2.4B"), ("Credits", "UGX 2.4B")]
    case "Aged Receivables":
        return [("Current", "UGX 48M"), ("30 days", "UGX 12M"), ("60+ days", "UGX 6.2M")]
    case "Aged Payables":
        return [("Current", "UGX 31M"), ("30 days", "UGX 9M"), ("60+ days", "UGX 4.1M")]
    case "Tax Summary":
        return [("VAT output", "UGX 18.4M"), ("VAT input", "UGX 11.2M"), ("WHT", "UGX 2.1M")]
    case "Inventory Value Summary":
        return [("Green bean", "UGX 210M"), ("Roast", "UGX 64M"), ("Packaging", "UGX 8.4M")]
    default:
        return [("Period", "August 2026"), ("Prepared by", "Finance"), ("Status", "Draft")]
    }
}
