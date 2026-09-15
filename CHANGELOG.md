# Changelog

All notable changes to **IAG Central iOS** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The marketing version in the Xcode target (`1.0.0`) is the source of truth.

## [Unreleased]

### Added

- Every web ERP desk and feature on the phone: Home lists all departments, each desk opens a feature list, plus Trace and the other workspace tools
- Clock In tab for every signed-in login: GPS punch against HR Sites and Blocks, with a Head Office demo pin for the simulator
- Separate full apps after sign-in: Finance, Sales, CRM, POS, Procurement, Production, Fleet, Logistics, Projects, Contract Management, HR, Security, Quality, Requests, and DMS
- Sign-in, home screen, and account screens use the product name **IAG Central**
- Sign-in uses the official Inspire Africa Group logo
- Splash screen and app icon use the official IAG color logo on black
- Home follows mobile UX: large greeting, Do now shortcuts, quiet app tiles, and no empty sections
- Sign-in is a plain white form: black logo, labeled fields, an eye to show the password, and a solid Sign in button. The workspace URL is not shown.
- After sign-in, roles come from `GET /api/auth/roles` (Postgres), not only the on-device catalog
- Item record CRUD (`POST`/`PATCH`/`DELETE /api/records/:module/:entity`) and the approval chain (`POST /api/approvals/:entity/:id/advance|reject`) so IPC and other chain desks do not PATCH `Approved`


### Changed

- Shell UI is quieter and more premium: monochrome app tiles, hairline cards, uppercase section labels, ink icon wells, and orange only for tint / hot badges
- Sign-in layout tightened for the same clean look (smaller logo mark, clearer hierarchy)
- Sign-in no longer ships a shared demo password. Secrets are hashed on device and created with Forgot password.
- Live sign-in uses the web ERP password (10+ characters). Continue on this device now saves the first local password and accepts `admin@iag.local`.
- Sign-in errors open a short pop-up instead of showing API text.

## [1.0.0] - 2026-09-14

### Added

- First native SwiftUI ERP: department desks, records, approvals, and custom roles with the same RBAC as web IAG ERP

[1.0.0]: https://github.com/OlaroPeterCelestine/iag-erp-ios/releases/tag/v1.0.0
