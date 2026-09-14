# Agent notes

Native iOS ERP. Keep RBAC in `Sources/ErpCore` aligned with `erp/src/lib/access-control.ts`.

- UI: `App/` (SwiftUI)
- Core: `Sources/ErpCore` (roles, catalog, store)
- Tests: `swift test` (must stay green in CI before `xcodebuild`)
