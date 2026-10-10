# Customer data encryption

Reviewed against the working tree on October 9, 2026. This replaces the December 12, 2025 debugging note with current implementation details and a clearly scoped historical issue. See [architecture](docs/ARCHITECTURE.md) and [current status](docs/STATUS.md) for related workflows.

## Current implementation

| Concern | Current code |
| --- | --- |
| Vault | [vault.ex](lib/licorice_lane/vault.ex), started in the application supervision tree |
| Encrypted Ecto type | [encrypted/binary.ex](lib/licorice_lane/encrypted/binary.ex) |
| Customer schema | [customers/customer.ex](lib/licorice_lane/customers/customer.ex) |
| Search and write API | [customers.ex](lib/licorice_lane/customers.ex) |
| Production keys | [config/runtime.exs](config/runtime.exs) |
| Regression coverage | [customers_test.exs](test/licorice_lane/customers_test.exs) |

Customer phone, email, contact person, billing address, and notes are stored through `LicoriceLane.Encrypted.Binary` using the Vault's AES-GCM cipher. Name remains plaintext for case-insensitive substring search. Decryption happens when Ecto loads encrypted fields.

The customer changeset derives `email_hash` and `phone_hash` from the source field values and uses `Cloak.Ecto.SHA256` to hash them on dump. Context queries pass exact email/phone values to those typed columns. Combined customer search merges name, email, and phone results and deduplicates records. No partial email/phone matching or normalization of case/phone formatting is implemented.

Customer editing regenerates lookup hashes from the current changeset values. Explicitly clearing an optional email or phone also clears its stored hash; unchanged contact fields retain their exact lookup behavior. Context and admin regressions cover replacement/clearing of contact values, encrypted storage after edits, and form validation without persistence. Existing records whose contact field was cleared before this repair may still have an old lookup hash; no data backfill is performed by this change.

[Messages.Message](lib/licorice_lane/messages/message.ex) also encrypts email, phone, and message body and uses SHA256 lookup hashes. Message names and admin notes remain plaintext.

## SHA256 versus HMAC

[LicoriceLane.Hashed.HMAC](lib/licorice_lane/hashed/hmac.ex) exists and has environment-specific configuration, but neither the customer nor message schema uses it. The current lookup hashes are unkeyed SHA256 hashes, not HMACs and not ciphertext.

Production still requires `HMAC_SECRET` because runtime configuration explicitly reads it. Do not assume rotating that secret changes current lookup hashes. Moving schemas to HMAC would require an intentional type, query, and data migration.

## Key handling

Development and test configurations have distinct fixture encryption keys. Refer to [config/dev.exs](config/dev.exs) and [config/test.exs](config/test.exs) rather than copying those keys into documentation or production.

Production requires a base64-encoded 32-byte `CLOAK_KEY` and a separate `HMAC_SECRET`, alongside `DATABASE_URL` and `SECRET_KEY_BASE`. [README](README.md#production-configuration) documents their purposes. Preserve the encryption key for existing data; replacing it without a migration prevents decryption of that data.

There is currently one labeled AES-GCM cipher and no implemented key-rotation workflow. A rotation plan must preserve access to old ciphertext while re-encrypting it, with backups and verification appropriate to the deployment.

Encrypted fields are still visible to authorized application code and users. Do not log decrypted values, loaded customer/message structs, or full changesets. Use synthetic fixtures and assertions on behavior or field presence when diagnosing issues.

## Historical seed-hash report

The December 12, 2025 note reported missing customer hashes after seeding while manual customer updates populated them. It recorded hypotheses and suggested debugging experiments; those are not current instructions.

Current source differs from that note:

- The changeset uses `fetch_change/2` and a loaded-record fallback to select values before setting hash fields.
- [Seeds](priv/repo/seeds.exs) call `Customers.create_customer/1` for sample customers.
- Customer tests include exact email/phone search and non-nil stored-hash assertions.

These observations do not prove the old seed-specific failure is fixed. It has not been reproduced during this documentation review. If investigating it, use a disposable database or focused fixture test, check stored hashes without printing decrypted records, and record the result in [STATUS.md](docs/STATUS.md#verification-gaps). Do not run seeds against valuable data: they delete existing business records.

## Migration constraint

[20251213043818_encrypt_customer_fields.exs](priv/repo/migrations/20251213043818_encrypt_customer_fields.exs) deletes all customers before changing column types and adding lookup hashes. It was written for test data rather than as a data-preserving encryption migration.

Its rollback changes column types; it does not decrypt encrypted records back into plaintext. Review migration and rollback behavior before applying them to any existing data.

## Validation entry points

With PostgreSQL and the Elixir toolchain available, run:

```powershell
mix test test/licorice_lane/customers_test.exs test/licorice_lane/messages_test.exs
mix test test/licorice_lane_web/live/contact_live_test.exs
```

These tests use sandboxed fixtures and do not establish production key rotation or seed-specific behavior. No test pass is claimed by this source review.
