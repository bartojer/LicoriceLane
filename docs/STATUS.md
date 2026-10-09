# Current implementation status

Reviewed on October 9, 2026 against the working tree, including local uncommitted code. Feature descriptions come from source inspection; test results are recorded below. Update this file when completing or changing a workflow. Use [architecture](ARCHITECTURE.md) for code and test entry points.

## Test validation

Validated on October 7, 2026 in Ubuntu WSL with Elixir 1.18.4, Erlang/OTP 28.0.2, and the configured local PostgreSQL test database:

| Run | Result |
| --- | --- |
| Preserved original suite, seed 0 | 237 tests, 0 failures |
| Focused inventory lifecycle, accounts, admin hooks, and admin routes, seed 0 | 98 tests, 0 failures |
| October 7 full suite: `mix test --seed 0` | 261 tests, 0 failures |
| October 9 full suite, including browser upload: `mix test --seed 0` | 278 tests, 0 failures |

The October 7 suite had 20 test files and 24 additional cases. The [inventory lifecycle tests](../test/licorice_lane/inventory_lifecycle_test.exs) cover writes and side effects; [admin route tests](../test/licorice_lane_web/live/admin_live_test.exs), [authorization hook/plug tests](../test/licorice_lane_web/user_auth_test.exs), and the registration regression test cover admin access. Existing query assertions were strengthened and unused test bindings cleaned up.

October 9 upload repairs add 13 server/component regressions, one optional real-browser regression, and three atomic-edit context tests. The browser check uses installed headless Edge and Playwright against a loopback test server and verifies decoded preview, actual transfer, rejected-save retention, successful retry, database persistence, and HTTP serving. Set the README's browser runtime variables to include it; otherwise that one case is skipped.

The locked LiveView/lazy_html dependencies require Elixir 1.15 or newer. `.tool-versions` pins the validated runtime, and [README](../README.md#running-tests-from-windows-through-wsl) documents the project-local WSL tool/build setup. No seeds or database resets were used for these runs.

## Implemented in code

The feature table describes the reviewed local working tree, including the earlier uncommitted admin refactor. See the commit scope below before assuming every listed local change is included in the upload commit.

| Area | Current behavior | Entry point |
| --- | --- | --- |
| Public pages | Home, about, FAQ, and inventory listing/details routes | [Router](../lib/licorice_lane_web/router.ex), [InventoryLive](../lib/licorice_lane_web/live/inventory_live.ex) |
| Contact messages | Validated submission, honeypot, encrypted email/phone/body, SHA256 lookup hashes | [ContactLive](../lib/licorice_lane_web/live/contact_live.ex), [Messages](../lib/licorice_lane/messages.ex) |
| Accounts | Registration, login/logout, confirmation, password reset, and settings | `lib/licorice_lane_web/live/user_*`, [Accounts](../lib/licorice_lane/accounts.ex) |
| Admin access | Authentication and admin checks in router and LiveView session; tab navigation | [AdminLive](../lib/licorice_lane_web/live/admin/admin_live.ex), [UserAuth](../lib/licorice_lane_web/user_auth.ex) |
| Dashboard | Database-backed booking count, low-stock list, and recent bookings | [DashboardComponent](../lib/licorice_lane_web/live/admin/dashboard_component.ex) |
| Inventory | Search/category filters, pagination, per-warehouse quantity queries, atomic single/bulk creation, base item editing, image uploads | [Inventory](../lib/licorice_lane/inventory.ex), admin inventory/add/edit components |
| Bookings | Paginated listing and status filters | [BookingsComponent](../lib/licorice_lane_web/live/admin/bookings_component.ex), [Rentals](../lib/licorice_lane/rentals.ex) |
| Customers | Paginated listing and name/exact-email/exact-phone search; context CRUD | [ClientsComponent](../lib/licorice_lane_web/live/admin/clients_component.ex), [Customers](../lib/licorice_lane/customers.ex) |
| Admin messages | Paginated name search/status filters, detail modal, status changes, internal notes, opening-new-message mark-as-read operation | [MessagesComponent](../lib/licorice_lane_web/live/admin/messages_component.ex) |
| Write side effects | Inventory/customer/message cache invalidation; inventory and message create/update broadcasts | Contexts and [Cache](../lib/licorice_lane/cache.ex) |

Public inventory receives inventory PubSub events and has a listing refresh handler. AdminLive receives message events and refreshes the new-message badge. Child component refresh has separate limitations below.

## Unfinished workflows

| Workflow | Current limitation | Starting point |
| --- | --- | --- |
| Inventory deletion in admin | `delete_item` event handler is a TODO/no-op; context deletion already exists | [InventoryComponent](../lib/licorice_lane_web/live/admin/inventory_component.ex) |
| Booking date filter | Handler assigns the selected date but does not filter query results | [BookingsComponent](../lib/licorice_lane_web/live/admin/bookings_component.ex) |
| Booking details and updates | `view_rental` and `update_rental` handlers are TODO/no-ops | [BookingsComponent](../lib/licorice_lane_web/live/admin/bookings_component.ex) |
| Rental lifecycle writes | Rentals context has read queries only; creating/updating/returning rentals needs a context API and inventory effects | [Rentals](../lib/licorice_lane/rentals.ex) |
| Customer details and editing | `view_customer` and `edit_customer` handlers are TODO/no-ops | [ClientsComponent](../lib/licorice_lane_web/live/admin/clients_component.ex) |
| Admin provisioning | No seeded admin account, promotion context API, or provisioning UI | [README bootstrap](../README.md#local-admin-access) |

Visible buttons and schemas do not imply these workflows are complete. Keep business operations in contexts when implementing them.

## Verification gaps

- **Browser E2E runner:** The agreed default for expanded E2E coverage is official Playwright Test in TypeScript, with reproducible headless commands, isolated fixtures, JSON reports, and failure artifacts for agents. The working upload regression currently uses the Playwright library through an optional ExUnit-launched script. A full runner configuration, pinned project dependencies, reports/traces, and a required browser CI job have not been established. Preserve the existing regression during migration; see [testing strategy](TESTING.md).
- **Admin realtime refresh:** DashboardComponent and MessagesComponent define `handle_info` callbacks, but PubSub messages go to the parent LiveView process. AdminLive currently ignores inventory refresh and updates only its message badge. Explicit forwarding/component updates and web tests are needed to establish list/modal/dashboard refresh behavior.
- **Cache integration:** Cachex starts with a five-minute TTL and write invalidation is present. Query paths currently do not call the cache fetch/get/put helpers, so caching benefits are not established. Add caching and dependency-aware invalidation together if needed.
- **Test coverage:** Inventory lifecycle tests cover atomic single/bulk creation and single-detail edits, rollback, stock defaults, single-item updates/deletion, warehouse totals, cache invalidation, and broadcasts. Admin tests cover registration privilege protection, admin plugs/mount hooks, route access, dashboard mounting, revoked privileges, and inventory upload workflows. Pagination, other detailed admin workflows, bulk-item deletion, and public InventoryLive still need dedicated coverage. Do not use seeds as test setup.
- **Historical seed-hash issue:** The December 2025 encryption note reported missing hashes during seeding. Current changeset logic differs, seeds call `Customers.create_customer/1`, and customer tests include stored-hash and exact-search assertions. The old seed-specific failure has not been reproduced or declared fixed in this review. See [encryption notes](../ENCRYPTION_IMPLEMENTATION_STATUS.md).
- **Image storage:** Add/edit now share UUID-based local storage and serving, configurable with `INVENTORY_UPLOAD_DIR`. Failed saves preserve the temporary upload and remove their copied images; component updates preserve active selections, and upload errors appear in the forms. Successful replacements retain old files because paths can be shared. Persistent storage across releases/hosts, backups, and automated old-image cleanup still need a deployment plan. See [architecture](ARCHITECTURE.md#upload-storage) and the historical [investigation](IMAGE_UPLOAD_INVESTIGATION.md).
- **Production operations:** Runtime secret configuration and production asset tasks exist, but there is no project-specific deployment/backup/key-rotation runbook. The production mailer still needs a delivery adapter. Choose the deployment environment before documenting exact operational commands.

## Data setup constraints

- `mix setup` and `mix ecto.setup` run seeds that delete existing business records. `mix ecto.reset` drops the configured database as well. Use these only with disposable data.
- The historical encryption migration deletes customer records instead of migrating their plaintext contents into encrypted data. Review it before applying pending migrations to valuable data.
- Customer and message lookup hashes currently use SHA256. The custom HMAC type is unused even though production runtime configuration requires `HMAC_SECRET`.
- Upcoming bookings use future `rented_at`; active queries check stored status without excluding future rentals. These are current rules to review when extending booking workflows.

## Commit scope

The inventory upload fixes and testing policy are being committed with their required runtime dependencies, helpers, and fixture-backed tests. Earlier admin pagination/refactor changes, customer/message context changes, public inventory UI adjustments, and unrelated test cleanups remain local. The architecture guide and earlier validation rows describe the broader local snapshot, not only the selected commit. Inspect source in the checkout when following those references.

The selected commit was additionally tested from an isolated export of the Git index so that it does not depend on unstaged application changes: **270 tests, 0 failures**, including the real-browser upload regression, seed 0. The larger local working tree's 278-test result above includes eight earlier account/authorization tests that remain unstaged.

## Historical documents

[admin_ref_plan.md](../admin_ref_plan.md) summarizes the original refactor goals. [ENCRYPTION_IMPLEMENTATION_STATUS.md](../ENCRYPTION_IMPLEMENTATION_STATUS.md) now separates current code from the historical hashing report. Neither is an instruction to reimplement completed work.
