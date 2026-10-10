# Licorice Lane

Licorice Lane is a Phoenix / LiveView application for an event decor rental business. Public pages cover marketing, inventory browsing, and contact messages. An authenticated admin dashboard provides inventory, bookings, customers, and message workflows. Some admin actions are still placeholders; see [current status](docs/STATUS.md) before starting feature work.

## Documentation

- [Agent guide](AGENTS.md): coding conventions and business rules.
- [Architecture](docs/ARCHITECTURE.md): contexts, schemas, routes, events, and test entry points.
- [Current status](docs/STATUS.md): implemented code, unfinished workflows, and verification gaps.
- [Testing strategy](docs/TESTING.md): selected test tools, current browser harness, and agent execution/debugging policy.
- [Rental lifecycle](docs/ARCHITECTURE.md#rentals-and-booking-terminology): reservations, multi-warehouse checkout/partial returns and legacy reconciliation policy. Apply the additive `20261010010000` migration with `mix ecto.migrate` when updating an existing database; do not run seeds or reset it.
- [Item creation guide](ITEM_CREATION_GUIDE.md): atomic single and bulk item creation.
- [Customer encryption](ENCRYPTION_IMPLEMENTATION_STATUS.md): current encryption/search behavior and historical issue notes.
- [Historical admin refactor](admin_ref_plan.md): original goals and pointers to current code.

## Local development

### Prerequisites

- Elixir matching `~> 1.15` in [mix.exs](mix.exs), with a compatible Erlang/OTP installation. The locked LiveView and lazy_html dependencies require at least Elixir 1.15. [.tool-versions](.tool-versions) pins Elixir 1.18.4 / Erlang OTP 28.0.2 for asdf users.
- A running PostgreSQL server.
- Network access for Mix dependencies and the Tailwind/esbuild binaries installed by asset setup.

Check that `elixir --version` and `mix --version` work in your terminal. Asset tasks use Mix-managed binaries; the repository has no npm setup step.

Database settings are in [config/dev.exs](config/dev.exs) and [config/test.exs](config/test.exs). Both currently use a local PostgreSQL server and the `postgres` user. Match the configured credentials to your local installation. Development uses `licorice_lane_dev`; tests use `licorice_lane_test` with an optional `MIX_TEST_PARTITION` suffix.

### First setup with disposable sample data

```powershell
mix setup
mix phx.server
```

Open [localhost:4000](http://localhost:4000). You can also start an interactive server with `iex -S mix phx.server`.

**`mix setup` runs seeds.** [priv/repo/seeds.exs](priv/repo/seeds.exs) transactionally replaces business records with [managed rental samples](docs/SEED_DATA.md), including reservations, multi-warehouse checkout, partial returns and overdue/returned/cancelled examples. Login accounts and tokens remain available. Use this setup path only for a disposable development database. `mix ecto.setup` also runs seeds, and `mix ecto.reset` drops and recreates the entire database, including accounts.

### Returning to an existing database

Install dependencies and rebuild assets without running seeds:

```powershell
mix deps.get
mix assets.setup
mix assets.build
```

Review pending migrations before running `mix ecto.migrate`, then start `mix phx.server`. The historical [customer encryption migration](priv/repo/migrations/20251213043818_encrypt_customer_fields.exs) contains `DELETE FROM customers`; it is not a data-preserving migration for an existing customer database. Back up valuable data and review the migration before applying it.

### Local admin access

Seeds do not create a login or an admin user. Register your local account at `/users/register`; registration creates a user with `admin: false`.

For local development, promote that account in `iex -S mix` (substitute the email you registered):

```elixir
alias LicoriceLane.{Accounts, Repo}

Accounts.get_user_by_email("your-local-account@example.com")
|> Ecto.Changeset.change(admin: true)
|> Repo.update!()

:ok
```

Log in at `/users/log_in`, then visit `/admin`. Registration does not accept an admin flag, and there is currently no admin-promotion context function or UI. The IEx example is a local bootstrap step. Authentication and admin authorization are enforced in both the router pipeline and the LiveView session.

### Useful routes

| Route | Purpose |
| --- | --- |
| `/`, `/about`, `/faq` | Public marketing pages |
| `/inventory`, `/inventory/:id` | Public inventory listing and item details |
| `/contact` | Contact form |
| `/admin` | Admin dashboard; requires an authenticated admin |
| `/users/register`, `/users/log_in`, `/users/settings` | Account workflows |
| `/dev/dashboard`, `/dev/mailbox` | Development dashboard and local email preview |

## Commands and validation

| Command | Effect |
| --- | --- |
| `mix test` | Creates/migrates the configured test database and runs the suite |
| `mix test test/licorice_lane/inventory_test.exs` | Runs a focused context test file |
| `mix format --check-formatted path/to/file.ex` | Checks formatting of a specific Elixir file |
| `mix format path/to/file.ex` | Formats a specific Elixir file |
| `mix assets.build` | Builds development CSS and JavaScript |
| `mix assets.deploy` | Minifies assets and generates the production digest |
| `mix ecto.reset` | Drops the configured database, recreates it, migrates, and seeds |

Use [existing fixtures](test/support/fixtures) for test data rather than running seeds. Tests use Ecto SQL Sandbox. Context tests are under `test/licorice_lane`; web tests are under `test/licorice_lane_web`. See [architecture](docs/ARCHITECTURE.md#tests) for feature-to-test mappings and [status](docs/STATUS.md#verification-gaps) for coverage gaps.

### Running tests from Windows through WSL

For required full-suite validation, configure the Mix and browser runtime below and run `bash scripts/test-all.sh` from WSL. It checks browser prerequisites, runs the two browser smoke regressions in separate processes, then runs every non-browser ExUnit test. See [testing](docs/TESTING.md) for logs, artifacts and seed overrides.

If the Windows terminal has no Elixir tools, use an Ubuntu WSL shell with PostgreSQL running. With the pinned asdf runtimes installed, change to this repository in WSL and select the compatible tools. The following keeps Mix tools and build outputs in ignored project directories, avoiding an older global Hex archive:

```bash
export PATH="$HOME/.asdf/installs/elixir/1.18.4-otp-28/bin:$HOME/.asdf/installs/erlang/28.0.2/bin:$PATH"
export MIX_HOME="$PWD/_build/wsl_mix_home"
export MIX_BUILD_PATH="$PWD/_build/wsl_test"

# First-time project-local tool and dependency setup:
mix local.hex --force
mix local.rebar --force
mix deps.get

mix test
```

Retain those environment settings for later test runs. Use `mix test test/licorice_lane/inventory_lifecycle_test.exs test/licorice_lane_web/user_auth_test.exs test/licorice_lane_web/live/admin_live_test.exs` for the inventory lifecycle and admin authorization checks. Native dependency compilation also requires a C compiler and make in the WSL environment.

## Customer Data Encryption

LicoriceLane uses [Cloak Ecto](https://github.com/danielberkompas/cloak_ecto) to encrypt sensitive customer data at rest in the database. This protects customer information in case of database exposure or unauthorized access.

### Encrypted Fields

The following customer fields are encrypted using AES-GCM encryption:
- `phone`
- `email`
- `contact_person`
- `billing_address`
- `notes`

The `name` field remains unencrypted to support efficient search functionality.

### Key Management

**Development/Test:** Distinct fixture encryption keys are configured in `config/dev.exs` and `config/test.exs`. Do not use these keys for production.

**Production:** The encryption key MUST be set via the `CLOAK_KEY` environment variable. Generate a secure key:

```bash
openssl rand -base64 32
```

Supply the environment variable through your deployment environment. For a local PowerShell session:

```powershell
$env:CLOAK_KEY = "your-generated-key-here"
```

### Search Limitations

Due to encryption, search functionality has the following behavior:

- **Name search**: Supports case-insensitive substring search (ILIKE)
- **Email search**: Exact match only (using hash comparison)
- **Phone search**: Exact match only (using hash comparison)

Partial searches on encrypted fields (email, phone) are not supported to maintain encryption security. Hash fields (`email_hash`, `phone_hash`) enable exact-match lookups without decrypting stored data.

These columns use `Cloak.Ecto.SHA256`, not the configured custom HMAC type. Production runtime configuration still requires `HMAC_SECRET` even though the current schemas do not use that type. Message email, phone, and body are also encrypted; message names and admin notes are plaintext. See [encryption details](ENCRYPTION_IMPLEMENTATION_STATUS.md).

### Security Considerations

**What encryption protects:**
- Data at rest in the database (protects against database dumps, backups, unauthorized database access)
- Prevents plaintext exposure if database is compromised

**What encryption does NOT protect:**
- Application-level access (decrypted data is visible to application code and authorized users)
- In-memory data (data is decrypted when loaded into the application)
- Logs or error messages that might include customer data
- Network transmission (use HTTPS/TLS for data in transit)

**Best practices:**
- Keep `CLOAK_KEY` secret and never commit it to version control
- Use different encryption keys for each environment (dev/test/prod)
- Rotate encryption keys periodically (requires re-encrypting all data)
- Monitor application logs to prevent leaking decrypted data
- Use HTTPS in production to protect data in transit

### Key Rotation

The current implementation uses a single encryption key. To implement key rotation:

1. Configure multiple labeled keys in the vault cipher configuration
2. Re-encrypt existing data with the new key
3. Maintain old keys temporarily to decrypt existing data during migration

There is no implemented key-rotation workflow in this application. Plan backups, re-encryption, and verification before replacing a key used by existing data.

## Production configuration

[config/runtime.exs](config/runtime.exs) requires these production environment variables:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | PostgreSQL connection URL |
| `SECRET_KEY_BASE` | Endpoint signing/encryption secret |
| `CLOAK_KEY` | Base64-encoded 32-byte AES key |
| `HMAC_SECRET` | Required by runtime configuration for the currently unused custom HMAC type |

Generate an endpoint secret with `mix phx.gen.secret`. Where OpenSSL is available, `openssl rand -base64 32` generates a value suitable for `CLOAK_KEY`; generate a separate value for `HMAC_SECRET`. Supply secrets through the deployment environment, never checked-in files.

Other runtime settings include `PHX_HOST` (default `example.com`), `PORT` (default `4000`), `POOL_SIZE` (default `10`), `ECTO_IPV6`, and `DNS_CLUSTER_QUERY`. Set `PHX_SERVER=true` when starting a release that should serve HTTP. Production mail delivery still needs an adapter configured in place of the default local adapter.

Inventory images use local storage. Add and edit share the application's `priv/static/uploads` directory by default, and PostgreSQL stores their `/uploads/...` paths. Set `INVENTORY_UPLOAD_DIR` to use another local directory; the application creates it when needed and serves images from that same directory. For example, set `$env:INVENTORY_UPLOAD_DIR = "C:\LicoriceLaneData\uploads"` before starting the server. Changing the directory does not move existing images; copy them before switching if their URLs must remain available.

When running Elixir in WSL, set `INVENTORY_UPLOAD_DIR` in the WSL shell using a Linux path, such as `/mnt/c/LicoriceLaneData/uploads`.

Uploads are consumed only after a successful inventory save. Failed validation keeps the temporary image available for a corrected retry or cancellation, and removes any failed-save copy. Successful replacement retains the previous image file because existing item paths can be shared; automated deletion and archival cleanup are not implemented. Runtime images are excluded from Git.

The optional real-browser upload regression in `test/licorice_lane_web/live/inventory_upload_test.exs` uses `test/browser/inventory_upload.cjs`. Set `UPLOAD_BROWSER_NODE` to an installed Node executable to enable it, `UPLOAD_PLAYWRIGHT_MODULE` to an installed Playwright module (defaults to `playwright`), and optionally `UPLOAD_BROWSER_EXECUTABLE` to an installed Chromium/Chrome/Edge executable. `UPLOAD_BROWSER_SCRIPT` can override the script path, which is needed when invoking Windows Node from WSL. It starts a loopback test server on port 4002 and uses sandboxed fixtures. Run `mix test test/licorice_lane_web/live/inventory_upload_test.exs --only browser` with the README's WSL tool settings. Without `UPLOAD_BROWSER_NODE`, only this optional browser case is skipped; the server upload regressions still run.

The optional deletion browser regression uses the same runtime variables. Run `mix test test/licorice_lane_web/live/admin_inventory_delete_test.exs --only browser` to check Cancel, Escape, and confirmed single/bulk deletion. When `UPLOAD_BROWSER_SCRIPT` is set, `inventory_delete.cjs` is resolved beside that upload script. Without `UPLOAD_BROWSER_NODE`, this browser case is skipped; server-side deletion tests still run.

Persistent storage across releases/hosts and backups still need review before deployment; see [status](docs/STATUS.md#verification-gaps). There is no repository-specific production deployment runbook yet.
