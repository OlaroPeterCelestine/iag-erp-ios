# IAG ERP iOS

Native SwiftUI Finance ERP for iPhone and iPad: every department desk, records, approvals, and custom roles — same SoD / RBAC as web **IAG ERP**.

**Version:** `1.0.0` — [changelog](./CHANGELOG.md)

**Bundle ID:** `africa.iag.erp.ios`

## Links

- **README:** [https://github.com/OlaroPeterCelestine/iag-erp-ios#readme](https://github.com/OlaroPeterCelestine/iag-erp-ios#readme)
- **Repository:** [https://github.com/OlaroPeterCelestine/iag-erp-ios](https://github.com/OlaroPeterCelestine/iag-erp-ios)
- **API:** [https://github.com/OlaroPeterCelestine/iag-erp-api#readme](https://github.com/OlaroPeterCelestine/iag-erp-api#readme)
- **Users & roles (Admin):** [https://github.com/OlaroPeterCelestine/iag-admin#readme](https://github.com/OlaroPeterCelestine/iag-admin#readme)
- **Web ERP:** [https://github.com/OlaroPeterCelestine/iag-erp#readme](https://github.com/OlaroPeterCelestine/iag-erp#readme)
- **Workspace index:** [https://github.com/OlaroPeterCelestine/iagtools#readme](https://github.com/OlaroPeterCelestine/iagtools#readme)

## What this app is

The native iOS Finance ERP. `ErpCore` is the RBAC + records host. The SwiftUI shell is Home, Departments, Clock, Approvals, Workspace, Access, and Account. Every web ERP desk and feature is on the phone, plus a Clock In module that any signed-in login can punch. Administrators create **custom roles** with a page matrix (optional `*`), then assign them on Users.

## Who it is for

Anyone who already has a Finance role: admin, accountant, clerk, viewer, HR, HOD, PM, contractor, GM, CEO, QS, stores, procurement, and custom roles you create on device.

## What you can do

- Home: balance-sheet snapshot, search across desks/features/records, then every department you can open.
- Clock: GPS clock-in / clock-out against HR Sites and Blocks. Clerk, viewer, and contractor can punch without opening the HR desk.
- Departments: Banking through Reports, grouped like the web sidebar. Open a desk to see **every feature** (customers, invoices, lots, reports, …).
- Records: open a document, create a draft, submit, approve/reject, void (where the desk allows).
- Approvals: hidden if the role has no desk.
- Workspace: Trace, analytics, accounting documents, templates, comms, guides, Q&A, release notes, activity, settings.
- Access (admin): custom roles with a page matrix and workspace users.

## Custom roles

Built-in demo roles cannot be overwritten. Custom roles get CRUD from the matrix you set. Approve, void, payroll, and geofence still follow the same allow-lists as web ERP. Specialty apps (lab, R&D, POS, fleet, …) need an explicit grant.

Demo password: `iagdemo`. Usernames include `admin`, `accountant`, `clerk`, `viewer`, `hr`, `hod`, `pm`, `contractor`, `gm`, `ceo`, `qs`, `stores`, `procurement`.

```
Sources/ErpCore/   # RBAC, catalog, store
App/               # SwiftUI shell
Tests/ErpCoreTests/ # same SoD cases as web IAG ERP
```

## Architecture

```
ERP iOS (SwiftUI)
  → ErpCore (roles, departments, records)
  → optional shared Go API (same JWT as web ERP)
```

## Identity and data

Sign in with an account from **IAG Admin** when the app is pointed at the shared API.
On-device demo data (UserDefaults) is only for local/offline trials — it is not the production directory.

Local demo password is `iagdemo`.

## Run locally

```bash
cd erp-ios
swift test
open ErpIOS.xcodeproj
```

In Xcode, select the **ERP iOS** scheme and run on an iPhone simulator.

```bash
xcodebuild -project ErpIOS.xcodeproj -scheme "ERP iOS" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

CI matches web ERP: tests, then a Debug build.

## Stack

SwiftUI · Swift 5.9 · ErpCore RBAC · UserDefaults (local) · optional shared Go API.

## Related IAG systems

| System | GitHub | README |
| --- | --- | --- |
| IAG tools workspace | [iagtools](https://github.com/OlaroPeterCelestine/iagtools) | [README](https://github.com/OlaroPeterCelestine/iagtools#readme) |
| IAG Admin | [iag-admin](https://github.com/OlaroPeterCelestine/iag-admin) | [README](https://github.com/OlaroPeterCelestine/iag-admin#readme) |
| IAG ERP API | [iag-erp-api](https://github.com/OlaroPeterCelestine/iag-erp-api) | [README](https://github.com/OlaroPeterCelestine/iag-erp-api#readme) |
| IAG ERP | [iag-erp](https://github.com/OlaroPeterCelestine/iag-erp) | [README](https://github.com/OlaroPeterCelestine/iag-erp#readme) |
| IAG ERP iOS ← this repo | [iag-erp-ios](https://github.com/OlaroPeterCelestine/iag-erp-ios) | [README](https://github.com/OlaroPeterCelestine/iag-erp-ios#readme) |
| IAG ERP Android | [iag-erp-android](https://github.com/OlaroPeterCelestine/iag-erp-android) | [README](https://github.com/OlaroPeterCelestine/iag-erp-android#readme) |
