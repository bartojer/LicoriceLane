defmodule LicoriceLane.CustomersTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.Customers
  alias LicoriceLane.Customers.Customer

  import LicoriceLane.CustomersFixtures

  describe "list_customers/0" do
    test "returns all customers ordered by name" do
      customer_b = customer_fixture(%{name: "Beta Company"})
      customer_a = customer_fixture(%{name: "Alpha Company"})
      customer_c = customer_fixture(%{name: "Charlie Company"})

      customers = Customers.list_customers()

      assert length(customers) == 3
      assert [customer_a.id, customer_b.id, customer_c.id] == Enum.map(customers, & &1.id)
    end

    test "returns empty list when no customers exist" do
      assert Customers.list_customers() == []
    end
  end

  describe "get_customer/1" do
    test "returns the customer with given id" do
      customer = customer_fixture()

      assert fetched = Customers.get_customer(customer.id)
      assert fetched.id == customer.id
      assert fetched.name == customer.name
    end

    test "returns nil when customer does not exist" do
      assert Customers.get_customer(999_999) == nil
    end
  end

  describe "get_customer!/1" do
    test "returns the customer with given id" do
      customer = customer_fixture()

      assert fetched = Customers.get_customer!(customer.id)
      assert fetched.id == customer.id
    end

    test "raises Ecto.NoResultsError when customer does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(999_999)
      end
    end
  end

  describe "search_customers/1" do
    setup do
      customer1 =
        customer_fixture(%{
          name: "Sunshine Events Co.",
          email: "contact@sunshine.com",
          phone: "555-0123"
        })

      customer2 =
        customer_fixture(%{
          name: "Happy Party Planners",
          email: "info@happyparty.com",
          phone: "555-0456"
        })

      customer3 =
        customer_fixture(%{
          name: "Elite Weddings LLC",
          email: "elite@weddings.com",
          phone: "555-0789"
        })

      %{customer1: customer1, customer2: customer2, customer3: customer3}
    end

    test "finds customers by partial name match", %{customer1: customer1} do
      results = Customers.search_customers("Sunshine")

      assert length(results) == 1
      assert hd(results).id == customer1.id
    end

    test "finds customers by case-insensitive name match", %{customer2: customer2} do
      results = Customers.search_customers("happy")

      assert length(results) == 1
      assert hd(results).id == customer2.id
    end

    test "finds customers by exact email match", %{customer1: customer1} do
      results = Customers.search_customers("contact@sunshine.com")

      assert length(results) == 1
      assert hd(results).id == customer1.id
    end

    test "finds customers by exact phone match", %{customer3: customer3} do
      results = Customers.search_customers("555-0789")

      assert length(results) == 1
      assert hd(results).id == customer3.id
    end

    test "returns empty list when no matches found" do
      assert Customers.search_customers("nonexistent") == []
    end

    test "returns unique customers when multiple search types match" do
      customer = customer_fixture(%{name: "Test Corp", email: "test@corp.com"})

      # Search by name that also happens to contain part of domain
      results = Customers.search_customers("Test")

      # Should only return the customer once
      assert length(results) == 1
      assert hd(results).id == customer.id
    end
  end

  describe "search_customers_by_name/1" do
    test "finds customers with partial name match" do
      company = customer_fixture(%{name: "ABC Company"})
      customer_fixture(%{name: "XYZ Corporation"})
      abc_customer = customer_fixture(%{name: "Another ABC Business"})

      results = Customers.search_customers_by_name("ABC")

      assert length(results) == 2
      assert Enum.sort(Enum.map(results, & &1.id)) == Enum.sort([company.id, abc_customer.id])
    end
  end

  describe "find_customer_by_email/1" do
    test "finds customer with exact email match" do
      customer = customer_fixture(%{email: "exact@email.com"})

      results = Customers.find_customer_by_email("exact@email.com")

      assert length(results) == 1
      assert hd(results).id == customer.id
    end

    test "returns empty list when email not found" do
      assert Customers.find_customer_by_email("notfound@email.com") == []
    end
  end

  describe "find_customer_by_phone/1" do
    test "finds customer with exact phone match" do
      customer = customer_fixture(%{phone: "555-1234"})

      results = Customers.find_customer_by_phone("555-1234")

      assert length(results) == 1
      assert hd(results).id == customer.id
    end

    test "returns empty list when phone not found" do
      assert Customers.find_customer_by_phone("999-9999") == []
    end
  end

  describe "create_customer/1" do
    test "creates a customer with valid data" do
      valid_attrs = valid_customer_attributes()

      assert {:ok, %Customer{} = customer} = Customers.create_customer(valid_attrs)
      assert customer.name == valid_attrs.name
      assert customer.phone == valid_attrs.phone
      assert customer.email == valid_attrs.email
    end

    test "creates a customer with minimal required data" do
      minimal_attrs = %{name: "Minimal Customer"}

      assert {:ok, %Customer{} = customer} = Customers.create_customer(minimal_attrs)
      assert customer.name == "Minimal Customer"
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Customers.create_customer(%{name: nil})
    end

    test "validates email format" do
      invalid_attrs = valid_customer_attributes(%{email: "not-an-email"})

      assert {:error, changeset} = Customers.create_customer(invalid_attrs)
      assert "has invalid format" in errors_on(changeset).email
    end

    test "validates phone format" do
      invalid_attrs = valid_customer_attributes(%{phone: "invalid"})

      assert {:error, changeset} = Customers.create_customer(invalid_attrs)
      assert "has invalid format" in errors_on(changeset).phone
    end
  end

  describe "update_customer/2" do
    test "replaces email and phone lookup hashes after editing" do
      customer = customer_fixture(%{email: "before@example.com", phone: "555-1111"})

      assert {:ok, updated} =
               Customers.update_customer(customer, %{
                 email: "after@example.com",
                 phone: "555-2222"
               })

      assert Customers.find_customer_by_email("before@example.com") == []
      assert Customers.find_customer_by_phone("555-1111") == []
      assert [found] = Customers.find_customer_by_email("after@example.com")
      assert found.id == updated.id
      assert [found] = Customers.find_customer_by_phone("555-2222")
      assert found.id == updated.id
    end

    test "clearing optional contact fields clears their stored values and lookup hashes" do
      customer = customer_fixture(%{email: "clear@example.com", phone: "555-3333"})
      assert {:ok, _} = Customers.update_customer(customer, %{email: "", phone: ""})
      assert Customers.find_customer_by_email("clear@example.com") == []
      assert Customers.find_customer_by_phone("555-3333") == []

      assert %{rows: [[nil, nil, nil, nil]]} =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 "SELECT email, phone, email_hash, phone_hash FROM customers WHERE id = $1",
                 [customer.id]
               )
    end

    test "clearing one contact field preserves the other lookup and unrelated encrypted fields" do
      customer = customer_fixture(%{email: "keep@example.com", phone: "555-4444"})
      assert {:ok, _} = Customers.update_customer(customer, %{phone: nil, name: "Renamed"})
      assert [found] = Customers.find_customer_by_email("keep@example.com")
      assert found.id == customer.id
      assert found.phone == nil
      assert found.contact_person == customer.contact_person
      assert found.billing_address == customer.billing_address
      assert found.notes == customer.notes
      assert Customers.find_customer_by_phone("555-4444") == []
    end

    test "edited sensitive fields remain encrypted in raw database storage" do
      customer = customer_fixture()

      attrs = %{
        email: "encrypted-edit@example.com",
        phone: "555-5555",
        contact_person: "Synthetic contact",
        billing_address: "Synthetic address",
        notes: "Synthetic internal notes"
      }

      assert {:ok, _} = Customers.update_customer(customer, attrs)

      %{rows: [stored]} =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT email, phone, contact_person, billing_address, notes FROM customers WHERE id = $1",
          [customer.id]
        )

      plaintext =
        Enum.map([:email, :phone, :contact_person, :billing_address, :notes], &attrs[&1])

      assert Enum.all?(Enum.zip(stored, plaintext), fn {ciphertext, value} ->
               is_binary(ciphertext) and ciphertext != value
             end)
    end

    test "returns an error changeset when an edited customer was deleted" do
      customer = customer_fixture()
      Customers.delete_customer(customer)
      assert {:error, changeset} = Customers.update_customer(customer, %{name: "Stale edit"})
      assert "is no longer available" in errors_on(changeset).id
      assert Customers.get_customer(customer.id) == nil
    end

    test "updates customer with valid data" do
      customer = customer_fixture()
      update_attrs = %{name: "Updated Name", notes: "Updated notes"}

      assert {:ok, %Customer{} = updated} = Customers.update_customer(customer, update_attrs)
      assert updated.name == "Updated Name"
      assert updated.notes == "Updated notes"
    end

    test "returns error changeset with invalid data" do
      customer = customer_fixture()

      assert {:error, %Ecto.Changeset{}} = Customers.update_customer(customer, %{name: nil})

      # Customer should remain unchanged - reload and compare critical fields
      reloaded = Customers.get_customer!(customer.id)
      assert customer.id == reloaded.id
      assert customer.name == reloaded.name
      assert customer.email == reloaded.email
    end
  end

  describe "change_customer/2" do
    test "validates edits without writing to the database" do
      customer = customer_fixture()
      changeset = Customers.change_customer(customer, %{name: "Draft name"})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Draft name"
      assert Customers.get_customer!(customer.id).name == customer.name
      refute Customers.change_customer(customer, %{name: ""}).valid?
    end
  end

  describe "delete_customer/1" do
    test "deletes the customer" do
      customer = customer_fixture()

      assert {:ok, %Customer{}} = Customers.delete_customer(customer)
      assert Customers.get_customer(customer.id) == nil
    end
  end

  describe "Customer encryption" do
    test "encrypts sensitive fields" do
      attrs = valid_customer_attributes()
      {:ok, customer} = Customers.create_customer(attrs)

      # Reload from database to see stored values
      stored_customer = Repo.get!(Customer, customer.id)

      # Email and phone should be decrypted when read
      assert stored_customer.email == attrs.email
      assert stored_customer.phone == attrs.phone

      # Email and phone hashes should be set
      assert stored_customer.email_hash != nil
      assert stored_customer.phone_hash != nil
    end
  end
end
