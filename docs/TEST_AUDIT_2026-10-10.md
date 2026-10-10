# Test-suite audit — October 10, 2026

The browser suite was audited and validated first, then every ExUnit test file was reviewed against its associated source and fixtures. The baseline was clean at commit `c59fd9d`. Six bounded subagent reviews covered browser, accounts/auth, inventory, messages/contact, customers/admin and rentals; database execution was serialized by the main agent. No seeds, database resets, commits or pushes were used.

## Coverage and consolidation

| Area | Meaningful protections retained or strengthened |
| --- | --- |
| Browser smoke | Still two cases. Preview decoding, transfer/rejection/retry and served-image persistence remain; exact image identity/dimensions/bytes now checked. Cancel, Escape and both tracking-type deletions remain; selected dialog title and a second connected public page's stream insert/removal are checked. Public detail navigation/Escape shares the upload journey. Shared setup replaces duplicate launch/login/error code. |
| Inventory context | Every original normalization/category/search/coordinator input remains in tables with exact IDs rather than count-only assertions. Nested preloads/warehouse quantities, stale update APIs, every protected booking status, cache/PubSub and rollback remain. Query-only tests can safely run asynchronously. |
| Inventory UI/uploads | All existing upload/deletion guards remain. Retry checks persisted fields and shared old-image retention. New card/detail availability tests cover every single status and warehouse-only bulk stock. |
| Accounts/auth | Generated validation/navigation/authorization guards remain. Duplicate password-write/revocation journeys were merged; all token contexts, other-user isolation, actual expiry windows, old-password rejection, token-context separation, email-change invalidation, tampered/revoked cookies and reset replay now have stronger guards. Pure renderers no longer need DB sandboxes; isolated context tests run asynchronously. |
| Messages/contact | Removed two 1.1-second sleeps in favor of shuffled fixed timestamps. Duplicate creation/getter/status/success journeys were merged. Validation must show actual errors and avoid writes; successful forms must persist exact fields, show feedback and clear inputs/textarea. Optional phone and honeypot cases remain. Raw encrypted storage/SHA256, protected fields, invalid status, persisted transitions and name-only search are checked. |
| Customers/admin | Deduplication fixture now truly matches name plus exact email; partial encrypted-field search negatives and raw storage of all five sensitive fields added. Location preloads and zero/multiple rental counts checked. Customer creation/edit/replay/draft/realtime guards retained. |
| Admin messages | Two cheaper LiveView journeys fill previously missing full escaped detail rendering, preview truncation, phone omission, automatic read, all statuses, notes draft/blur/clearing, selection isolation and combined filters. |
| Pagination/cache | Paired pagination/filter journeys merged while retaining every tab's refresh, normalization, filter reset, next-page navigation and deletion/clamping assertions. Avoids 104 domain fixtures and four mounts. Pure component tests cover hidden navigation, bounded page links, active page, targets and final result ranges. Failed writes check cache preservation individually. |
| Rentals | Redundant read tests merged with exact identities/order/limits and stronger preloads. Distinct schedule/lifecycle/UI scenarios retained. Foreign allocation, malformed return, precise original-warehouse movement history, terminal schedules, stock/side effects and forged/stale actions strengthened. Eleven lifecycle cases avoid unnecessary single-item fixture writes. |
| Real concurrency | Starting tasks together was insufficient proof. The test now holds the Item/Rental row, confirms both distinct backend PIDs have ungranted PostgreSQL locks, then releases them and verifies one winner, one rejection and conserved stock/history. |

No browser guard was moved to a cheaper layer or removed: the original browser suite was already compact. Consolidation reduced repeated fixture/mount work and named cases, not the covered input combinations. Assertions were maintained or strengthened. Contact's final empty-field assertion accepts omitted `value` or `value=""`, which are both empty HTML input values, while rejecting any nonempty value; its original form-presence check was substantially weaker.

## Application defects exposed by new tests

A focused run of 35 tests produced two genuine failures before source fixes:

- The public detail modal treated every existing single-item tracking record as available. It now checks `status == :available`, matching the card; rented/damaged details disable the action.
- `Customers.list_customers_with_rental_count/0` joined an undeclared `:rentals` association. The Customer schema now declares the inverse of Rental's existing customer association; zero and multiple booking counts pass. No migration is needed.

## Validation and measured tradeoffs

Runtime: Ubuntu WSL, Elixir 1.18.4/OTP 28.0.2, Node 22.19.0 and installed Playwright-managed Chromium. Browser fixtures/files remain owned by the existing synchronous ExUnit sandbox wrappers.

| Measure | Baseline | Final |
| --- | --- | --- |
| Browser cases | 2 passed | 2 passed |
| Non-browser named cases | 407 passed | 365 passed |
| Total named cases | 409 | 367 |
| Test/support/browser source lines (`.ex`, `.exs`, `.cjs`) | 7,411 | 7,697 |
| Upload browser test time | 4.6 s | 5.8 s |
| Deletion browser test time | 8.1 s | 8.8 s |
| ExUnit test time, seed 0 and `--slowest 10` on both runs | 11.8 s | 9.4 s |

The complete required command `bash scripts/test-all.sh` passed both browser cases followed by all 365 non-browser cases, with no skipped tests; its ordinary ExUnit run took 9.2 seconds. Selective exclusions partition coverage across commands rather than waive any test. Logs are in `_build/test-suite-results/`; JSON browser results and failure artifacts are in `_build/browser-results/`.

Changed-file formatting, shell syntax and `git diff --check` passed. Another full non-browser run with seed `20261010` passed, exercising the new async execution and consolidated journeys under a different order. A read-only independent final review checked assertion preservation, isolation, the browser harness and source fixes; it found a same-case search fixture that was corrected to mixed case. Negative prerequisite checks deliberately returned nonzero for an unset Node runtime and a nonexistent browser executable; the latter wrote a JSON `failed` result without touching application data.

The cheaper suite's comparable single-run time improved about 20%; summed reported test times across all three processes changed only from 24.5 to 24.0 seconds. These measurements exclude Mix startup/compilation and are not a statistical benchmark. Browser time grew modestly because the same two journeys now check a connected public page and retain diagnostic trace data. Total test source grew 286 lines (3.9%): new reliability guards outweighed removed boilerplate, honoring the user's first priority. Named-case reduction is not a coverage metric.

## Remaining gaps

- Official TypeScript Playwright Test configuration, a pinned project dependency/browser install and a required browser CI job remain unimplemented. The two real browser smoke cases and required local command work; this audit did not replace their established sandbox isolation with a larger runner.
- Source inspection identified an already-mounted password-reset form that does not revalidate its token on submission after another password change revokes it. Fresh-mount token replay is covered; the stale mounted-form behavior needs a separate application fix and regression. This observation was not runtime-validated during the audit.
- Admin message selection/status/notes handlers lack the malformed/stale-selection protections present in customer workflows. Current normal-flow protections were strengthened; rejecting those malformed/stale events requires a defined application behavior and follow-up regressions.
- Baseline and final full runs emitted the same Postgrex `client exited` connection warning without a failing test. A focused upload/concurrency run passed 14 selected non-browser cases without the warning. This pre-existing cleanup warning remains visible in logs; it was not suppressed or presented as a test failure.
- No exhaustive mutation-testing campaign or coverage-percentage target was introduced. The two captured pre-fix failures directly demonstrate useful new regression protection; review and assertions, rather than case counts alone, establish the remaining evidence.
