# Agent notes

Native iOS ERP. Keep RBAC in `Sources/ErpCore` aligned with `erp/src/lib/access-control.ts`.

- UI: `App/` (SwiftUI)
- Core: `Sources/ErpCore` (roles, catalog, store, IAG Frontend API)
- Default frontend origin: `https://iag-frontend-five.vercel.app`
- Records: item REST + approval chain (`ErpAPI` in `Endpoints.swift`)
- Tests: `swift test` (must stay green in CI before `xcodebuild`)
