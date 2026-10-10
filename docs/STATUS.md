# Current implementation status

Updated October 10, 2026. Keep this file focused on current capabilities, open work, and the latest recorded validation. Update the affected row when a workflow changes; keep code/test mappings in [architecture](ARCHITECTURE.md), execution policy in [testing](TESTING.md), and dated audit detail in separate reports.

## Unfinished workflows

| Workflow | Current limitation | Starting point |
| --- | --- | --- |
| Legacy booking reconciliation | Historical bookings allow metadata edits but cannot perform stock actions. Active/late legacy item references block managed allocation until explicitly reconciled. | [Rental lifecycle](../lib/licorice_lane/rentals/lifecycle.ex) |
| Admin provisioning | No seeded admin account, promotion context API, or provisioning UI; local bootstrap uses IEx. | [README bootstrap](../README.md#local-admin-access) |

## Verification gaps

- **Password reset:** An already-mounted reset form does not revalidate its token on submission after another password change revokes it. Needs an application fix and regression; identified by source inspection, not runtime-validated. See [audit follow-ups](TEST_AUDIT_2026-10-10.md#remaining-gaps).
- **Admin message events:** Selection/status/notes handlers lack protections for malformed events and stale selections. Define rejection behavior and add regressions. See [audit follow-ups](TEST_AUDIT_2026-10-10.md#remaining-gaps).
- **Browser E2E runner:** Two ExUnit-launched Playwright smoke cases work. Official TypeScript runner configuration, pinned project dependencies/browser installation, and a required browser CI job remain unimplemented. Preserve sandbox isolation and existing guards; see [testing strategy](TESTING.md).
- **Realtime events:** Message deletion has no broadcast or admin UI; account/customer realtime events are not defined. Existing inventory/message create/update and managed rental lifecycle/schedule refreshes work.
- **Query caching:** Write invalidation exists, but query paths do not use cache fetch/get/put helpers. Integrate caching with dependency-aware invalidation if needed.
- **Historical seed hashes:** The December 2025 seed-specific failure has not been reproduced or declared fixed. Current tests cover stored hashes and exact search. See [encryption notes](../ENCRYPTION_IMPLEMENTATION_STATUS.md#historical-seed-hash-report).
- **Image storage:** Uploads use configurable local storage and retain replaced/shared files. Persistence across releases/hosts, backups, and automated cleanup need a deployment plan. See [upload storage](ARCHITECTURE.md#upload-storage).
- **Production operations:** Deployment, backup, and key-rotation runbooks are missing; the production mailer needs a delivery adapter. Choose the deployment environment before writing operational commands.

## Implemented in code

| Area | Current behavior |
| --- | --- |
| Public pages | Home, about, FAQ, and inventory listing/details |
| Contact messages | Validated submission, honeypot, encrypted contact/body fields, and exact lookup hashes |
| Accounts and admin access | Registration, login/logout, confirmation, password reset, settings; authenticated admin authorization and tab navigation |
| Dashboard | Database-backed booking count, low-stock list, and recent bookings |
| Inventory | Search/category filters, pagination, warehouse quantities, atomic single/bulk creation, base/single-detail editing, image uploads, and confirmed deletion of unreferenced items |
| Bookings | Status/event-date filters, details/schedule editing, managed reservations and advisory availability, multiple source warehouses, allocation edits, checkout, cancellation, and partial returns; atomic stock/history writes and stale-version rejection |
| Customers | Paginated name/exact-email/exact-phone search, full details/locations, and validated creation/editing |
| Admin messages | Paginated name/status filters, detail modal, status changes, internal notes, and automatic mark-as-read on opening |
| Write side effects | Inventory/customer/message/rental cache invalidation; inventory/message create/update and managed rental lifecycle/schedule broadcasts |

Public inventory and active admin views refresh through PubSub. Admin refreshes preserve filters/pages, clamp shrinking lists, reload selected details, and retain editing drafts/upload selections. See [architecture](ARCHITECTURE.md) for entry points and contracts.

## Test validation

Latest recorded validation: October 10, 2026, in Ubuntu WSL with Elixir 1.18.4 / OTP 28.0.2 and native Node/Playwright Chromium. `bash scripts/test-all.sh` passed both browser smoke cases and 366 non-browser tests: **368 named cases, zero failures, no skips**. A separate non-browser run with seed `20261010` also passed.

The [dated audit](TEST_AUDIT_2026-10-10.md) records coverage, consolidation, source fixes, timing, and remaining diagnostic issues. Follow [testing](TESTING.md#regression-testing-before-pushing) for required validation before pushing; skipped browser cases do not count as passes.

## Data setup constraints

- Seeds delete existing business records; `mix ecto.reset` also drops the database. The historical customer encryption migration deletes customers. Follow [existing-database setup](../README.md#returning-to-an-existing-database) and use fixtures for tests.
- Customer/message lookup hashes use SHA256; the custom HMAC type is unused although production still requires `HMAC_SECRET`. See [encryption notes](../ENCRYPTION_IMPLEMENTATION_STATUS.md).
