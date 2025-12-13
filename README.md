# LicoriceLane

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

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

**Development/Test:** Encryption keys are stored in `config/dev.exs` and `config/test.exs`.

**Production:** The encryption key MUST be set via the `CLOAK_KEY` environment variable. Generate a secure key:

```bash
openssl rand -base64 32
```

Set the environment variable before starting the application:

```bash
export CLOAK_KEY="your-generated-key-here"
```

### Search Limitations

Due to encryption, search functionality has the following behavior:

- **Name search**: Supports partial/fuzzy search (case-insensitive ILIKE)
- **Email search**: Exact match only (using hash comparison)
- **Phone search**: Exact match only (using hash comparison)

Partial searches on encrypted fields (email, phone) are not supported to maintain encryption security. Hash fields (`email_hash`, `phone_hash`) enable exact-match lookups without decrypting stored data.

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

Cloak supports key rotation, but this feature is not currently implemented to reduce initial complexity.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
