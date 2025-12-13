# Customer Data Encryption Implementation Status

## Date: December 12, 2025

## Goal
Implement field-level encryption for sensitive customer data using Cloak Ecto 1.3, with the ability to search by exact email/phone match using hash fields.

## What Has Been Implemented

### 1. Dependencies Added
- `{:cloak, "~> 1.1"}` and `{:cloak_ecto, "~> 1.3"}` added to `mix.exs`
- Successfully installed via `mix deps.get`

### 2. Encryption Configuration
**Files Modified:**
- `config/dev.exs` - Added `LicoriceLane.Vault` config with hardcoded key and HMAC secret
- `config/test.exs` - Added `LicoriceLane.Vault` config with different hardcoded key
- `config/runtime.exs` - Added `LicoriceLane.Vault` config reading from `CLOAK_KEY` and `HMAC_SECRET` env vars for production

**Encryption Keys Generated:**
- Dev: `dI+lLFea3W44HOKjN6XctinCCIFILv5v+8Jtu8Vd2p8=`
- Test: `KWP6Okjnv5xd+Mu9Wfpb183P+IETkrCBWt72VlTMpc0=`
- HMAC secrets: hardcoded strings for dev/test, env var for prod

### 3. Vault and Custom Types Created
**Files Created:**
- `lib/licorice_lane/vault.ex` - Basic Cloak Vault implementation
- `lib/licorice_lane/encrypted/binary.ex` - `LicoriceLane.Encrypted.Binary` type
- `lib/licorice_lane/hashed/hmac.ex` - `LicoriceLane.Hashed.HMAC` type (NOT CURRENTLY USED)

### 4. Supervision Tree Updated
- Added `LicoriceLane.Vault` to application supervision tree in `lib/licorice_lane/application.ex`
- Positioned after `LicoriceLane.Repo` and before `DNSCluster`

### 5. Customer Schema Updated
**File: `lib/licorice_lane/customers/customer.ex`**

Changed from plaintext fields to encrypted:
```elixir
field :phone, LicoriceLane.Encrypted.Binary
field :email, LicoriceLane.Encrypted.Binary
field :contact_person, LicoriceLane.Encrypted.Binary
field :billing_address, LicoriceLane.Encrypted.Binary
field :notes, LicoriceLane.Encrypted.Binary
```

Added hash fields (using `Cloak.Ecto.SHA256` instead of custom HMAC):
```elixir
field :email_hash, Cloak.Ecto.SHA256
field :phone_hash, Cloak.Ecto.SHA256
```

**Changeset Logic:**
The changeset now calls `put_hashed_fields/1` which attempts to populate hash fields:
```elixir
defp put_hashed_fields(changeset) do
  changeset
  |> maybe_put_hash(:email, :email_hash)
  |> maybe_put_hash(:phone, :phone_hash)
end

defp maybe_put_hash(changeset, source_field, hash_field) do
  value = get_change(changeset, source_field) || Map.get(changeset.data, source_field)
  
  case value do
    nil -> changeset
    val -> force_change(changeset, hash_field, val)
  end
end
```

### 6. Database Migration Created
**File: `priv/repo/migrations/20251213043818_encrypt_customer_fields.exs`**

- Deletes all existing customer data
- Changes phone, email, contact_person, billing_address, notes columns to `:binary` type
- Adds `email_hash` and `phone_hash` as `:binary` columns
- Creates indexes on both hash columns

### 7. Search Functions Updated
**File: `lib/licorice_lane/customers.ex`**

Modified `search_customers/1` to combine three search strategies:
1. Name ILIKE search (still works, name is unencrypted)
2. Exact email match via hash comparison
3. Exact phone match via hash comparison

New helper functions:
- `search_customers_by_name/1` - ILIKE on name field
- `find_customer_by_email/1` - Exact match using SHA256 hash
- `find_customer_by_phone/1` - Exact match using SHA256 hash

### 8. Documentation Added
**File: `README.md`**
- Comprehensive section on encryption implementation
- Key management instructions
- Search limitations explained
- Security considerations documented

## What Is Working

✅ **Encryption/Decryption**: 
- Customer fields are successfully encrypted as binary in database
- Decryption is transparent when loading records
- Can create new customers with encrypted data
- Can update existing customers

✅ **Name Search**: 
- Searching by name works perfectly (ILIKE on unencrypted field)

✅ **Hash Generation**:
- Creating a new customer DOES generate proper SHA256 hashes
- Verified: `{:ok, hash} = Cloak.Ecto.SHA256.dump("events@sunshine.com")` produces correct binary hash
- Manual updates to customers regenerate hashes correctly

## THE PROBLEM: Hash Fields Not Populated During Seeding

### Current Issue
When running `mix ecto.reset` (which runs seeds), customer records are created but **hash fields are NULL in the database**.

### Evidence
```elixir
# Query a customer
customer = LicoriceLane.Repo.get!(LicoriceLane.Customers.Customer, 1)
IO.inspect(customer.email)        # => "events@sunshine.com" (decrypted correctly)
IO.inspect(customer.email_hash)   # => nil (PROBLEM!)

# Manually updating fixes it
LicoriceLane.Customers.update_customer(customer, %{})
# Now email_hash and phone_hash are populated correctly
```

### Why Hash Search Fails
The search functions compute the hash of the search term and query for matching hash fields:
```elixir
{:ok, email_hash} = Cloak.Ecto.SHA256.dump("events@sunshine.com")
# Queries: WHERE c.email_hash == ^email_hash
# But email_hash in DB is NULL, so no match
```

### Root Cause Analysis
The `priv/repo/seeds.exs` file creates customers like this:
```elixir
Customers.create_customer(%{
  name: "Sunshine Events Co.",
  email: "events@sunshine.com",
  phone: "555-0123",
  # ... other fields
})
```

The `create_customer/1` function calls `Customer.changeset/2` which should trigger `put_hashed_fields/1`, but the hashes end up as nil.

### Suspected Issues
1. **Ecto Type Timing**: The `Cloak.Ecto.SHA256` type may not be dumping correctly when the value comes from a new changeset
2. **Force Change Not Working**: `force_change/3` may not be properly setting the hash field for insertion
3. **Encrypted Field Interference**: When we get the email value from changeset to hash it, it might already be encrypted binary, not plaintext
4. **Changeset Data Access**: For new records, `changeset.data` fields are all nil, so `Map.get(changeset.data, source_field)` returns nil

### Debug Output from Latest Attempt
```bash
# Creating a customer manually works:
attrs = %{name: "Test", email: "test@example.com", phone: "123", ...}
{:ok, customer} = LicoriceLane.Customers.create_customer(attrs)
customer.email_hash  # Has proper binary hash!

# But after ecto.reset (seeding):
customer = LicoriceLane.Repo.get!(Customer, 1)
customer.email_hash  # nil!
```

## Next Steps to Resolve

### Option 1: Debug the Changeset Function
Add extensive logging to understand what's happening:
```elixir
defp maybe_put_hash(changeset, source_field, hash_field) do
  value = get_change(changeset, source_field) || Map.get(changeset.data, source_field)
  
  IO.puts("=== maybe_put_hash ===")
  IO.inspect(source_field, label: "source_field")
  IO.inspect(value, label: "value")
  IO.inspect(changeset.data, label: "changeset.data")
  IO.inspect(changeset.changes, label: "changeset.changes")
  
  case value do
    nil -> 
      IO.puts("Value is nil, skipping hash")
      changeset
    val -> 
      IO.puts("Setting hash field")
      force_change(changeset, hash_field, val)
  end
end
```

### Option 2: Use Virtual Fields Pattern
Instead of storing hashes in the database immediately, use virtual fields that get computed on the fly:
```elixir
schema "customers" do
  # Regular fields
  field :email, LicoriceLane.Encrypted.Binary
  field :phone, LicoriceLane.Encrypted.Binary
  
  # Virtual hash fields (computed, not stored)
  field :email_hash, :binary, virtual: true
  field :phone_hash, :binary, virtual: true
end

# Compute hashes when searching
def search_customers(term) do
  # ... existing name search ...
  
  # Manually compute and compare hashes
  all_customers = list_customers()
  {:ok, search_hash} = Cloak.Ecto.SHA256.dump(term)
  
  matching = Enum.filter(all_customers, fn customer ->
    {:ok, email_hash} = Cloak.Ecto.SHA256.dump(customer.email)
    {:ok, phone_hash} = Cloak.Ecto.SHA256.dump(customer.phone)
    email_hash == search_hash or phone_hash == search_hash
  end)
  
  # ... combine and return ...
end
```
**Downside**: Loads all customers into memory, computes hashes for each. Not scalable.

### Option 3: Populate Hashes in Migration
Instead of relying on changeset, populate hashes in a data migration after the schema migration:
```elixir
# In migration after table changes:
def up do
  # ... existing column changes ...
  
  # Populate hashes for all existing customers
  execute """
  UPDATE customers 
  SET 
    email_hash = digest(email, 'sha256'),
    phone_hash = digest(phone, 'sha256')
  WHERE email IS NOT NULL
  """
end
```
**Problem**: This won't work because email/phone are already encrypted binary, not plaintext in the database.

### Option 4: Fix Cloak.Ecto.SHA256 Field Behavior
The issue might be that `Cloak.Ecto.SHA256` expects the source value to be set directly, not via `force_change`. Try:
```elixir
# Instead of force_change, just don't set it in changeset
# Let the field itself handle hashing on insert

schema "customers" do
  field :email, LicoriceLane.Encrypted.Binary
  field :phone, LicoriceLane.Encrypted.Binary
  # Remove these - they'll be virtual computed fields
end

# Or use on_replace and default options:
field :email_hash, Cloak.Ecto.SHA256, 
  source: :email,  # Link to email field
  virtual: false
```

### Option 5: Simplify - Remove Hash Search Feature
Accept that encrypted fields can't be searched:
- Keep name search only
- Document that users should search by name
- Remove hash fields entirely from schema and migration
- Simplify the implementation

## Files That Need Attention

1. **`lib/licorice_lane/customers/customer.ex`** - Changeset hash field logic
2. **`priv/repo/seeds.exs`** - May need to explicitly set hash fields
3. **`lib/licorice_lane/customers.ex`** - Search function logic
4. **Migration** - May need data migration step

## Testing Checklist

When problem is resolved, verify:
- [ ] `mix ecto.reset` successfully seeds customers with populated hash fields
- [ ] `search_customers("Sunshine")` finds "Sunshine Events Co." (name search)
- [ ] `search_customers("events@sunshine.com")` finds "Sunshine Events Co." (exact email)
- [ ] `search_customers("555-0123")` finds "Sunshine Events Co." (exact phone)
- [ ] Creating new customer via UI populates hash fields
- [ ] Updating customer regenerates hash fields if email/phone changed
- [ ] Direct database query shows email_hash and phone_hash as binary (not NULL)

## Useful Debug Commands

```bash
# Check customer data
mix run -e "c = LicoriceLane.Repo.get!(LicoriceLane.Customers.Customer, 1); IO.inspect(c.email); IO.inspect(c.email_hash)"

# Test hash generation
mix run -e "{:ok, h} = Cloak.Ecto.SHA256.dump(\"test@example.com\"); IO.inspect(h, limit: :infinity)"

# Test search
mix run -e "results = LicoriceLane.Customers.search_customers(\"events@sunshine.com\"); IO.inspect(length(results))"

# Manually fix hashes for all customers
mix run -e "LicoriceLane.Customers.list_customers() |> Enum.each(fn c -> LicoriceLane.Customers.update_customer(c, %{}) end)"

# Reset database
mix ecto.reset
```

## References

- [Cloak Ecto Documentation](https://hexdocs.pm/cloak_ecto/readme.html)
- [Cloak.Ecto.SHA256 Type](https://hexdocs.pm/cloak_ecto/Cloak.Ecto.SHA256.html)
- Original requirements: Encrypt phone, email, contact_person, billing_address, notes; keep name unencrypted for search

---

**Summary**: Encryption is working perfectly. The only issue is that hash fields (`email_hash`, `phone_hash`) are not being populated during initial customer creation via seeds. Manual updates work fine. Need to fix the changeset logic or seed process to ensure hashes are generated and stored on initial insert.
