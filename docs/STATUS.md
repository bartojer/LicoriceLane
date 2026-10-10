# Current implementation status

Reviewed on October 9, 2026 against the current source. Feature descriptions come from source inspection; test results are recorded below. Update this file when completing or changing a workflow. Use [architecture](ARCHITECTURE.md) for code and test entry points.

## Test validation

October 10 [full-suite audit](TEST_AUDIT_2026-10-10.md) retained the two browser smoke cases, strengthened meaningful assertions and consolidated repeated setup without removing unique guards. The required `bash scripts/test-all.sh` command passed both browser cases followed by 365 non-browser tests, with no skips (367 named cases total). Comparable seed-0 diagnostic ExUnit time changed from 11.8 to 9.4 seconds; total test source grew 3.9% to fill coverage gaps. New tests exposed and fixed public single-item detail availability and the missing customer rental-count association. The audit report records guard mappings, measured tradeoffs and remaining gaps.

Validated on October 7, 2026 in Ubuntu WSL with Elixir 1.18.4, Erlang/OTP 28.0.2, and the configured local PostgreSQL test database:

| Run | Result |
| --- | --- |
| Preserved original suite, seed 0 | 237 tests, 0 failures |
| Focused inventory lifecycle, accounts, admin hooks, and admin routes, seed 0 | 98 tests, 0 failures |
| October 7 full suite: `mix test --seed 0` | 261 tests, 0 failures |
| October 9 upload snapshot, including browser upload: `mix test --seed 0` | 278 tests, 0 failures |
| October 9 accepted refactor, pagination/cache/public inventory regressions and browser upload: `mix test --seed 0` | 298 tests, 0 failures |
| October 9 admin inventory deletion: focused lifecycle/deletion/pagination tests, seed 0 | 37 tests, 0 failures |
| October 9 admin inventory deletion: `mix test --seed 0` | 312 tests, 0 failures, 1 optional browser case skipped |
| October 9 preserved upload browser regression: `mix test test/licorice_lane_web/live/inventory_upload_test.exs --only browser --seed 0` with browser runtime configured | 1 selected browser case passed, 13 excluded |
| October 9 admin deletion with Playwright/headless Edge: `mix test test/licorice_lane_web/live/admin_inventory_delete_test.exs --seed 0` with browser runtime configured | 10 tests, 0 failures, no skips |
| October 9 booking event-date filter: rental context, shared pagination, and admin pagination tests, seed 0 | 40 tests, 0 failures |
| October 9 booking event-date filter: `mix test --seed 0` | 320 tests, 0 failures, 2 optional browser cases skipped |
| October 9 admin realtime refresh: focused realtime/pagination/admin tests, seed 0 | 28 tests, 0 failures |
| October 9 admin realtime refresh: `mix test --exclude browser --seed 0` | 333 total cases, 331 passed, 2 browser cases excluded and run separately below |
| October 9 admin realtime refresh: upload browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 13 excluded |
| October 9 admin realtime refresh: deletion browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 9 excluded |
| October 9 customer details/editing: focused customer context/cache/admin/pagination tests, seed 0 | 59 tests, 0 failures |
| October 9 customer details/editing: `mix test --exclude browser --seed 0` | 351 total cases, 349 passed, 2 browser cases excluded and run separately below |
| October 9 customer details/editing: upload browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 13 excluded |
| October 9 customer details/editing: deletion browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 9 excluded |
| October 9 booking details/schedule editing: focused rental context/admin/pagination tests, seed 0 | 56 tests, 0 failures |
| October 9 booking details/schedule editing: `mix test --exclude browser --seed 0` | 373 total cases, 371 passed, 2 browser cases excluded and run separately below |
| October 9 booking details/schedule editing: upload browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 13 excluded |
| October 9 booking details/schedule editing: deletion browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 9 excluded |
| October 9 customer creation: focused customer forms/context/cache/pagination tests, seed 0 | 68 tests, 0 failures |
| October 9 customer creation: `mix test --exclude browser --seed 0` | 382 total cases, 380 passed, 2 browser cases excluded and run separately below |
| October 9 customer creation: upload browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 13 excluded |
| October 9 customer creation: deletion browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 9 excluded |
| October 9 managed rental lifecycle: `mix test --exclude browser --seed 0` | 409 total cases, 407 passed, 2 browser cases excluded and run separately below |
| October 9 managed rental lifecycle: upload browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 13 excluded |
| October 9 managed rental lifecycle: deletion browser regression with native WSL Node/Playwright Chromium, seed 0 | 1 selected browser case passed, 9 excluded |

The October 7 suite had 20 test files and 24 additional cases. The [inventory lifecycle tests](../test/licorice_lane/inventory_lifecycle_test.exs) cover writes and side effects; [admin route tests](../test/licorice_lane_web/live/admin_live_test.exs), [authorization hook/plug tests](../test/licorice_lane_web/user_auth_test.exs), and the registration regression test cover admin access. Existing query assertions were strengthened and unused test bindings cleaned up.

October 9 upload repairs add 13 server/component regressions, one optional real-browser regression, and three atomic-edit context tests. The browser check uses installed headless Edge and Playwright against a loopback test server and verifies decoded preview, actual transfer, rejected-save retention, successful retry, database persistence, and HTTP serving. Set the README's browser runtime variables to include it; otherwise that one case is skipped.

Admin inventory deletion adds five context regressions, nine LiveView regressions, and one optional [Playwright browser regression](../test/browser/inventory_delete.cjs). They cover atomic bulk stock removal, single tracking removal, rollback for booking/movement references, stale records, confirmation/cancellation, filter/page preservation, and public listing updates. The browser case verifies Cancel, Escape, and confirmed single/bulk deletion, with database cleanup checked by ExUnit. Items used in any booking (including returned/cancelled bookings) or movement history are retained. Image files remain on disk because their paths can be shared.

Booking event-date filtering adds four rental context regressions and three admin LiveView regressions. They cover UTC day boundaries, event date independently of pickup date, all existing status combinations, filtered totals and stable pagination, page reset, clearing, missing event dates, invalid inputs, and filter/page preservation during component refresh.

Admin realtime refresh adds thirteen [LiveView regressions](../test/licorice_lane_web/live/admin_realtime_test.exs) covering context broadcasts, two admin sessions, filters/page preservation, page clamping, queued stale events, notes drafts, deletion confirmations, inactive tabs, and add/edit upload preservation. All 333 cases passed across the full server suite and separate upload/deletion browser runs, with no skips. Changed-file formatting and asset builds also passed. An initial Windows Edge run passed both browser cases, but a later upload run hit the documented `ERR_CONNECTION_REFUSED` forwarding problem; final validation runs the browser natively in WSL, as described in [testing](TESTING.md).

Customer details/editing adds eleven [admin LiveView regressions](../test/licorice_lane_web/live/admin_customers_test.exs) and seven customer context/cache cases. They cover full details/locations, escaped multiline notes, optional fields, validation/retry/cancellation, draft preservation during refresh, search/page retention and clamping, malformed or deleted records, server-held selection, encrypted storage after edits, lookup hash replacement/clearing, and cache behavior. All 351 cases passed across the full server suite and separate upload/deletion browser runs, with no skips; changed-file formatting and asset builds passed. The `Add New Client` button remains a separate unfinished workflow.

Booking details/schedule editing adds eleven [context regressions](../test/licorice_lane/rental_details_test.exs) and eleven [admin LiveView regressions](../test/licorice_lane_web/live/admin_bookings_test.exs). They cover nested item/location preloads, UTC inputs and preserved seconds, optional events, required dates/chronology, validation/retry/cancellation, stale/deleted records, current lifecycle data, protected customer/status/allocations, stock/history preservation, cache invalidation/broadcasts, filtered pages, and two-admin dashboard/details refresh with retained edit drafts. All 373 cases passed across the full server suite and separate upload/deletion browser runs, with no skips; changed-file formatting and asset builds passed. Scheduling edits do not reserve stock or check overlaps; rental lifecycle operations remain unfinished below.

Customer creation adds nine [LiveView regressions](../test/licorice_lane_web/live/admin_customer_creation_test.exs) for name-only/full creation, encrypted storage and exact lookups, cache invalidation, validation/retry, cancellation, draft refresh, search/page retention, forged IDs, save replay and malformed nested payloads in both create/edit modes. Two independent subagent reviews validated design and implementation; a malformed-payload crash found during review was fixed and re-reviewed. All 382 cases passed across the server suite and separate upload/deletion browser runs, with no skips; formatting and asset builds passed.

Managed rental lifecycle adds 27 cases across [context](../test/licorice_lane/rental_lifecycle_test.exs), [independent-connection concurrency](../test/licorice_lane/rental_concurrency_test.exs) and [admin forms](../test/licorice_lane_web/live/admin_rental_lifecycle_test.exs). They cover advisory availability, peak overlap/adjacent windows, multi-source summaries, single/bulk checkout, physical rollback after earlier movements, partial returns and completion, stock conservation/history, overdue stock, schedule constraints, cancellation, stale/replayed/foreign actions, legacy refusal, inventory edit/deletion protections, malformed inputs, integer bounds and retained/numeric-order drafts. Two independent reviews validated design and implementation; their findings were fixed, tested and re-reviewed. All 409 cases passed across the server suite and separate required browser runs, with no skips; formatting and asset builds passed. The additive migration preserves existing bookings. Legacy reconciliation remains deliberately separate below.

The locked LiveView/lazy_html dependencies require Elixir 1.15 or newer. `.tool-versions` pins the validated runtime, and [README](../README.md#running-tests-from-windows-through-wsl) documents the project-local WSL tool/build setup. No seeds or database resets were used for these runs.

## Implemented in code

The feature table describes the current source, including the reviewed admin refactor and pagination changes.

| Area | Current behavior | Entry point |
| --- | --- | --- |
| Public pages | Home, about, FAQ, and inventory listing/details routes | [Router](../lib/licorice_lane_web/router.ex), [InventoryLive](../lib/licorice_lane_web/live/inventory_live.ex) |
| Contact messages | Validated submission, honeypot, encrypted email/phone/body, SHA256 lookup hashes | [ContactLive](../lib/licorice_lane_web/live/contact_live.ex), [Messages](../lib/licorice_lane/messages.ex) |
| Accounts | Registration, login/logout, confirmation, password reset, and settings | `lib/licorice_lane_web/live/user_*`, [Accounts](../lib/licorice_lane/accounts.ex) |
| Admin access | Authentication and admin checks in router and LiveView session; tab navigation | [AdminLive](../lib/licorice_lane_web/live/admin/admin_live.ex), [UserAuth](../lib/licorice_lane_web/user_auth.ex) |
| Dashboard | Database-backed booking count, low-stock list, and recent bookings | [DashboardComponent](../lib/licorice_lane_web/live/admin/dashboard_component.ex) |
| Inventory | Search/category filters, pagination, per-warehouse quantity queries, atomic single/bulk creation, base item editing, image uploads, confirmed deletion of unreferenced single/bulk items | [Inventory](../lib/licorice_lane/inventory.ex), admin inventory/add/edit components |
| Bookings | Managed booking creation and advisory availability, timed reservations, multiple source warehouses, allocation edits, checkout, cancellation and partial returns with atomic stock/history writes and stale-version rejection; legacy metadata editing retained | [BookingsComponent](../lib/licorice_lane_web/live/admin/bookings_component.ex), [Rentals](../lib/licorice_lane/rentals.ex), [Lifecycle](../lib/licorice_lane/rentals/lifecycle.ex) |
| Customers | Paginated listing and name/exact-email/exact-phone search; full details/location modal and validated creation/editing with cancellation, error retention and filtered-page refresh; context CRUD | [ClientsComponent](../lib/licorice_lane_web/live/admin/clients_component.ex), [Customers](../lib/licorice_lane/customers.ex) |
| Admin messages | Paginated name search/status filters, detail modal, status changes, internal notes, opening-new-message mark-as-read operation | [MessagesComponent](../lib/licorice_lane_web/live/admin/messages_component.ex) |
| Write side effects | Inventory/customer/message/rental cache invalidation; inventory/message create/update and managed rental lifecycle/schedule broadcasts | Contexts and [Cache](../lib/licorice_lane/cache.ex) |

Public inventory receives inventory PubSub events and has a listing refresh handler. AdminLive subscribes to inventory, message and rental events and explicitly refreshes the affected active component. Message events also refresh the new-message badge; rental schedule edits refresh bookings/dashboard views. List refreshes preserve filters/page and clamp shrinking results. Selected message/booking details reload current data while editing drafts remain intact; add/edit fields and upload selections survive broadcasts.

## Unfinished workflows

| Workflow | Current limitation | Starting point |
| --- | --- | --- |
| Legacy booking reconciliation | Historical bookings retain metadata editing, but stock actions and managed allocation of items referenced by active/late legacy rentals require a separate explicit reconciliation workflow | [Lifecycle](../lib/licorice_lane/rentals/lifecycle.ex) |
| Admin provisioning | No seeded admin account, promotion context API, or provisioning UI | [README bootstrap](../README.md#local-admin-access) |

Visible buttons and schemas do not imply these workflows are complete. Keep business operations in contexts when implementing them.

## Verification gaps

- **Browser E2E runner:** Keep a compact smoke suite and detailed scenarios in ExUnit/LiveView tests. Upload/deletion remain two ExUnit-launched Playwright cases with a shared harness, JSON results and failure screenshots/traces; `scripts/test-all.sh` rejects missing browser prerequisites and runs the complete required suite. Official TypeScript runner configuration, pinned project dependencies and a required browser CI job remain unimplemented. Preserve existing sandbox isolation/guards during migration; see [testing strategy](TESTING.md).
- **Remaining realtime events:** Message deletion has no broadcast or admin UI; account/customer realtime events are not currently defined. Inventory/message create/update and managed rental lifecycle/schedule refresh behavior is implemented.
- **Cache integration:** Cachex starts with a five-minute TTL and write invalidation is present. Query paths currently do not call the cache fetch/get/put helpers, so caching benefits are not established. Add caching and dependency-aware invalidation together if needed.
- **Test coverage:** Inventory lifecycle tests cover atomic single/bulk creation and single-detail edits, rollback, stock defaults, single-item updates, single/bulk deletion and reference protection, warehouse totals, cache invalidation, and broadcasts. Admin tests cover registration privilege protection, admin plugs/mount hooks, route access, dashboard mounting, revoked privileges, inventory upload workflows, and server-side deletion confirmation/cancellation. Dedicated pagination/context/cache tests and admin/public inventory web tests now cover filtered totals, stable page boundaries, invalid/out-of-range inputs, list shrinkage, component refresh/filter preservation, and public stream updates. Deletion dialog JavaScript now has focused browser coverage; other detailed admin workflows still need coverage. Do not use seeds as test setup.
- **Historical seed-hash issue:** The December 2025 encryption note reported missing hashes during seeding. Current changeset logic differs, seeds call `Customers.create_customer/1`, and customer tests include stored-hash and exact-search assertions. The old seed-specific failure has not been reproduced or declared fixed in this review. See [encryption notes](../ENCRYPTION_IMPLEMENTATION_STATUS.md).
- **Image storage:** Add/edit now share UUID-based local storage and serving, configurable with `INVENTORY_UPLOAD_DIR`. Failed saves preserve the temporary upload and remove their copied images; component updates preserve active selections, and upload errors appear in the forms. Successful replacements retain old files because paths can be shared. Persistent storage across releases/hosts, backups, and automated old-image cleanup still need a deployment plan. See [architecture](ARCHITECTURE.md#upload-storage) and the historical [investigation](IMAGE_UPLOAD_INVESTIGATION.md).
- **Production operations:** Runtime secret configuration and production asset tasks exist, but there is no project-specific deployment/backup/key-rotation runbook. The production mailer still needs a delivery adapter. Choose the deployment environment before documenting exact operational commands.

## Data setup constraints

- `mix setup` and `mix ecto.setup` run seeds that delete existing business records. `mix ecto.reset` drops the configured database as well. Use these only with disposable data.
- The historical encryption migration deletes customer records instead of migrating their plaintext contents into encrypted data. Review it before applying pending migrations to valuable data.
- Customer and message lookup hashes currently use SHA256. The custom HMAC type is unused even though production runtime configuration requires `HMAC_SECRET`.
- New managed bookings use `:reserved` until checkout; Upcoming includes these reservations and excludes their terminal statuses. Legacy rows retain the historical future-pickup rule. Active and overdue queries describe checked-out managed bookings by stored status/due date.

## Commit scope

The upload repairs and testing policy were committed first as `f8c1998`, including their required runtime dependencies and tests. That selected commit was validated from an isolated export of the Git index: **270 tests, 0 failures**, including the real-browser upload regression, seed 0. The original broader local tree passed 278 tests and included eight earlier account/authorization tests.

The earlier local admin pagination/refactor, customer/message invalidation, public inventory adjustments, historical documentation, and test improvements were subsequently reviewed and accepted. This review adds shared pagination bounds, deterministic ordering, malformed-event handling, booking filter forms, and 20 regression cases. The latest validation row covers the complete source rather than only the original upload commit.

## Historical documents

[admin_ref_plan.md](../admin_ref_plan.md) summarizes the original refactor goals. [ENCRYPTION_IMPLEMENTATION_STATUS.md](../ENCRYPTION_IMPLEMENTATION_STATUS.md) now separates current code from the historical hashing report. Neither is an instruction to reimplement completed work.
