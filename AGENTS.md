# Licorice Lane Agent Guide

## Purpose
- `LicoriceLane` is a Phoenix 1.7 / LiveView application for an event decor rental business.
- The app manages public marketing pages plus authenticated admin workflows for inventory, bookings, customers, and incoming messages.
- Core business areas live in Elixir contexts under `lib/licorice_lane`, with UI code under `lib/licorice_lane_web`.

## Start Here
- Read [README.md](README.md) for local setup, admin bootstrap, and production configuration.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for context/schema/UI/test mappings and cache/PubSub contracts.
- Check [docs/STATUS.md](docs/STATUS.md) before feature work; visible admin actions may still be placeholders.
- Follow [docs/TESTING.md](docs/TESTING.md) for the agreed testing strategy and agent execution/debugging workflow.
- Use [ITEM_CREATION_GUIDE.md](ITEM_CREATION_GUIDE.md) for item creation contracts and [ENCRYPTION_IMPLEMENTATION_STATUS.md](ENCRYPTION_IMPLEMENTATION_STATUS.md) for current encryption behavior.
- [admin_ref_plan.md](admin_ref_plan.md) is historical context, not a current implementation checklist.
- Update the relevant documentation when changing a documented workflow or completing a status item.

## Stack
- Elixir `~> 1.15`; `.tool-versions` pins Elixir 1.18.4 / Erlang OTP 28.0.2 for local development.
- Phoenix `~> 1.7.21`
- Phoenix LiveView `~> 1.0`
- Ecto + PostgreSQL
- Tailwind + esbuild for frontend assets
- Cachex for admin/data caching
- Cloak / Cloak Ecto for customer data encryption

## Repository Shape
- `lib/licorice_lane` contains business contexts and schemas:
  - `Accounts`
  - `Customers`
  - `Inventory`
  - `Rentals`
  - `Messages`
  - `Cache`
- `lib/licorice_lane_web` contains router, auth, controllers, LiveViews, and reusable components.
- `lib/licorice_lane_web/live/admin` contains the admin dashboard shell plus tab-specific LiveComponents.
- `priv/repo/migrations` contains schema history.
- `test/support/fixtures` contains reusable fixtures for contexts and LiveView/controller tests.
- `assets` contains Tailwind and JS entrypoints used by Phoenix assets tasks.
- `lib/licorice_lane_web/helpers/admin_helpers.ex` holds shared admin labels, formatting, and pagination metadata.
- `lib/licorice_lane_web/components/pagination.ex` renders shared pagination controls.
- `Inventory` operates on `Items` and `Locations` schemas; there are no separate `Items` or `Locations` contexts.

## Important Domain Rules

### Customers and Encryption
- Sensitive customer fields are encrypted at rest with Cloak:
  - `phone`
  - `email`
  - `contact_person`
  - `billing_address`
  - `notes`
- `name` remains plaintext to support partial search.
- Email and phone lookups are exact-match only and rely on hash columns, not partial matching.
- Hash columns currently use `Cloak.Ecto.SHA256`. The custom HMAC type is unused, although production runtime configuration still requires `HMAC_SECRET`.
- Be careful not to introduce logs, debug output, or test assertions that expose decrypted customer data unnecessarily.
- Message email, phone, and body are encrypted too; message names and admin notes remain plaintext.

### Inventory Model
- Inventory supports two item types:
  - `:single` items tracked by a `SingleItem` record and a single location
  - `:bulk` items tracked by `ItemsLocation` quantity rows
- `SingleItem` uses the same primary key as `Item`. When creating a single item, the `SingleItem.id` must match the parent `Item.id`.
- `min_stock` matters for bulk items; single items are normalized to `0`.
- `create_item_with_location/1` supplies a bulk `min_stock` default of `10`; the base Item schema default is `0`. Direct Repo inserts do not apply context defaults or side effects.
- Category values are defined as `Ecto.Enum` values on `LicoriceLane.Items.Item`.

### Admin UX
- `/admin` is a single authenticated LiveView shell (`AdminLive`) that swaps tab-specific LiveComponents.
- Admin access requires both authentication and admin authorization through `LicoriceLaneWeb.UserAuth`.
- Public inventory browsing is available separately via `InventoryLive`.

### Caching and Realtime Updates
- `LicoriceLane.Cache` centralizes Cachex usage for admin/dashboard data.
- If you add or change inventory, customers, rentals, or messages write paths, make sure the appropriate cache invalidation function is called.
- Inventory changes also broadcast PubSub updates via `LicoriceLane.Inventory.broadcast_inventory_update/1`.
- Message-related UI updates rely on subscription/broadcast flow as well.
- Cache invalidation is wired into current inventory/customer/message writes, but query caching is not currently integrated. Do not assume a query is cached without checking its callers.
- LiveComponent subscriptions receive PubSub messages in the parent LiveView process. Explicitly refresh components from the parent; child `handle_info` functions alone do not establish realtime updates. Current admin refresh gaps are listed in `docs/STATUS.md`.
- `Rentals` currently exposes read queries only. New rental writes must account for inventory effects and appropriate cache invalidation.

## Coding Patterns
- Keep business logic in contexts, not in LiveViews or controllers.
- Favor Ecto queries in the context modules and preload associations needed by the UI there.
- Follow the existing split between public `LicoriceLane.*` contexts and `LicoriceLaneWeb.*` presentation modules.
- The codebase uses descriptive `@doc` blocks heavily in context modules. Preserve that style when adding non-trivial public functions.
- Use existing fixtures in `test/support/fixtures` before inventing ad hoc test setup.
- When changing schemas or business behavior, update both the relevant context tests and any affected LiveView/controller tests.

## Commands
- Initial setup: `mix setup`
- Start server: `mix phx.server`
- Run tests: `mix test`
- Format code: `mix format`
- Reset database: `mix ecto.reset`
- Build assets: `mix assets.build`
- Prepare production assets: `mix assets.deploy`
- `mix setup` and `mix ecto.setup` run seeds that delete existing business records. Use fixtures for tests and the README's returning-to-an-existing-database instructions for valuable data.
- The historical customer encryption migration deletes customer records; inspect pending migrations before applying them to an existing database.

## Configuration and Secrets
- Production requires:
  - `DATABASE_URL`
  - `SECRET_KEY_BASE`
  - `CLOAK_KEY`
  - `HMAC_SECRET`
- `CLOAK_KEY` is required for encrypted customer fields.
- Never commit production secrets or replace runtime env-based configuration with checked-in secrets.

## Testing Notes
- Use ExUnit/context tests and Phoenix.LiveViewTest for broad application coverage; use the official Playwright Test runner in TypeScript for expanded browser E2E coverage.
- Tests will mostly be run and debugged by agents. Prioritize reproducible headless commands, isolated fixtures, structured failure reports, and saved debugging artifacts.
- Preserve regression expectations when debugging. Do not weaken assertions or skip failing tests merely to obtain a passing run; explain evidence for any legitimate expectation change.
- The current upload browser regression is a Playwright library script launched by ExUnit. The full Playwright Test runner and its reporting/artifact configuration are not installed yet; see [current status](docs/STATUS.md#verification-gaps). Keep the working regression while establishing the broader runner.
- Context tests live under `test/licorice_lane`.
- Web tests live under `test/licorice_lane_web`.
- `ConnCase` and `DataCase` are already set up in `test/support`.
- Inventory/customer/rental behavior already has fixture-backed tests; extend those tests when changing related flows.
- `test/licorice_lane/inventory_lifecycle_test.exs` covers inventory writes, rollback, warehouse stock, and update side effects.
- Admin authorization is covered in `user_auth_test.exs` and `live/admin_live_test.exs`; inventory uploads are covered in `live/inventory_upload_test.exs`. Other admin component workflows and public InventoryLive still need dedicated web coverage.
- Prefer formatting only changed Elixir files when the working tree contains unrelated edits.

## Agent Tips
- Read the relevant context module before editing a feature; many business rules are encoded there already.
- For inventory work, inspect both `Item` and its related `SingleItem` or `ItemsLocation` code paths.
- For customer search or data handling changes, preserve the encrypted-field limitations unless the schema and security model are intentionally being redesigned.
- For admin work, check whether a change belongs in `AdminLive`, a tab component, a context, or a shared component before editing.
