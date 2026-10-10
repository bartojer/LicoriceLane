defmodule LicoriceLaneWeb.AdminCustomerCreationTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.CustomersFixtures
  import LicoriceLane.MessagesFixtures

  alias LicoriceLane.{Cache, Customers, Repo}
  alias LicoriceLane.Customers.Customer
  alias LicoriceLaneWeb.Admin.ClientsComponent

  setup %{conn: conn} do
    Cache.clear()
    on_exit(fn -> Cache.clear() end)
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  test "Add New Client creates a name-only customer and ignores a replay after success", %{
    conn: conn
  } do
    view = clients_view(conn)
    target = component_target(view)
    new_customer(view)
    assert has_element?(view, "#customer-detail-modal h3", "Add New Client")
    assert blank_name_value(view) == ""
    refute has_element?(view, "#customer-edit-form")

    view
    |> form("#customer-create-form", customer: %{name: "Minimal new client"})
    |> render_submit()

    assert has_element?(view, "#customer-notice[role=status]", "Customer created successfully.")
    refute has_element?(view, "#customer-detail-modal")
    customer = Repo.one!(Customer)
    assert customer.name == "Minimal new client"
    assert customer.email == nil
    assert customer.phone == nil
    assert customer.notes == nil
    assert has_element?(view, "#customers-#{customer.id}", customer.name)

    view
    |> with_target(target)
    |> render_submit("save_customer", %{"customer" => %{"name" => "Replay"}})

    assert Repo.aggregate(Customer, :count) == 1
  end

  test "creation persists every supported field with encryption, exact lookups and invalidation",
       %{conn: conn} do
    view = clients_view(conn)
    new_customer(view)

    attrs = %{
      name: "Complete new client",
      email: "created@example.com",
      phone: "555-4040",
      contact_person: "Synthetic contact",
      billing_address: "Synthetic address\nSecond line",
      notes: "Synthetic creation notes"
    }

    Cache.put(:customers, :cached)
    Cache.put(:dashboard_stats, :cached)
    view |> form("#customer-create-form", customer: attrs) |> render_submit()
    customer = Repo.one!(Customer)
    assert Map.take(customer, Map.keys(attrs)) == attrs
    assert [found] = Customers.find_customer_by_email(attrs.email)
    assert found.id == customer.id
    assert [found] = Customers.find_customer_by_phone(attrs.phone)
    assert found.id == customer.id
    assert Cache.get(:customers) == nil
    assert Cache.get(:dashboard_stats) == nil

    %{rows: [stored]} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT email, phone, contact_person, billing_address, notes FROM customers WHERE id = $1",
        [customer.id]
      )

    values = Enum.map([:email, :phone, :contact_person, :billing_address, :notes], &attrs[&1])

    assert Enum.all?(Enum.zip(stored, values), fn {ciphertext, value} ->
             is_binary(ciphertext) and ciphertext != value
           end)
  end

  test "invalid creation retains input, writes nothing and supports a corrected retry", %{
    conn: conn
  } do
    view = clients_view(conn)
    new_customer(view)
    invalid = %{name: "", email: "invalid", phone: "invalid", notes: "Retained draft"}
    Cache.put(:customers, :cached)
    view |> form("#customer-create-form", customer: invalid) |> render_change()
    assert has_element?(view, "#customer-create-form", "can't be blank")
    assert has_element?(view, "#customer-create-form", "has invalid format")
    view |> form("#customer-create-form", customer: invalid) |> render_submit()
    assert has_element?(view, "#customer-edit-error", "Please correct the errors below.")
    assert has_element?(view, "textarea[name='customer[notes]']", "Retained draft")
    assert Repo.aggregate(Customer, :count) == 0
    assert Cache.get(:customers) == :cached

    view
    |> form("#customer-create-form",
      customer: %{
        name: "Corrected new client",
        email: "corrected-new@example.com",
        phone: "555-5050"
      }
    )
    |> render_submit()

    assert Repo.one!(Customer).notes == "Retained draft"
    assert Cache.get(:customers) == nil
  end

  test "Cancel discards creation and reopening does not reuse the abandoned draft", %{conn: conn} do
    view = clients_view(conn)
    new_customer(view)
    view |> form("#customer-create-form", customer: %{name: "Discarded name"}) |> render_change()
    view |> element("#customer-create-form button", "Cancel") |> render_click()
    assert Repo.aggregate(Customer, :count) == 0
    refute has_element?(view, "#customer-detail-modal")
    new_customer(view)
    assert blank_name_value(view) == ""
  end

  test "creation drafts survive component and badge refreshes", %{conn: conn} do
    view = clients_view(conn)
    new_customer(view)

    view
    |> form("#customer-create-form",
      customer: %{name: "Active creation draft", notes: "Still editing"}
    )
    |> render_change()

    Phoenix.LiveView.send_update(view.pid, ClientsComponent, id: "clients-component")
    message_fixture()
    render(view)
    assert has_element?(view, "input[name='customer[name]'][value='Active creation draft']")
    assert has_element?(view, "textarea[name='customer[notes]']", "Still editing")
    view |> form("#customer-create-form") |> render_submit()
    assert Repo.one!(Customer).name == "Active creation draft"
  end

  test "creation preserves search/page whether the new customer matches the filter or not", %{
    conn: conn
  } do
    for n <- 1..26,
        do: customer_fixture(%{name: "Match #{String.pad_leading(to_string(n), 2, "0")}"})

    view = clients_view(conn)
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Match"})
    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
    original = row_ids(view)
    new_customer(view)
    view |> form("#customer-create-form", customer: %{name: "Outside filter"}) |> render_submit()
    assert row_ids(view) == original
    assert has_element?(view, "input[name=search_term][value=Match]")
    assert has_element?(view, "nav[aria-label=Pagination] button.bg-brand", "2")
    new_customer(view)
    view |> form("#customer-create-form", customer: %{name: "Match 99"}) |> render_submit()
    assert length(row_ids(view)) == 2
    assert has_element?(view, "input[name=search_term][value=Match]")
    assert has_element?(view, "nav[aria-label=Pagination] button.bg-brand", "2")
  end

  test "creation starts clean after editing and a forged ID cannot update an existing customer",
       %{conn: conn} do
    existing = customer_fixture()
    view = clients_view(conn)
    view |> element("#customers-#{existing.id} button[phx-click=edit_customer]") |> render_click()
    view |> form("#customer-edit-form", customer: %{name: "Abandoned edit"}) |> render_change()
    view |> element("#customer-edit-form button", "Cancel") |> render_click()
    new_customer(view)
    assert blank_name_value(view) == ""
    target = component_target(view)

    view
    |> with_target(target)
    |> render_submit("save_customer", %{
      "customer" => %{"id" => existing.id, "name" => "Separate new client"}
    })

    assert Repo.aggregate(Customer, :count) == 2
    assert Customers.get_customer!(existing.id).name == existing.name
    assert [created] = Customers.search_customers_by_name("Separate new client")
    refute created.id == existing.id
  end

  for {mode, form_id} <- [{:new, "customer-create-form"}, {:edit, "customer-edit-form"}] do
    @mode mode
    @form_id form_id

    test "malformed nested payloads preserve the #{@mode} draft and allow a valid save", %{
      conn: conn
    } do
      existing = customer_fixture()
      view = clients_view(conn)
      target = component_target(view)

      if @mode == :new do
        new_customer(view)
      else
        view
        |> element("#customers-#{existing.id} button[phx-click=edit_customer]")
        |> render_click()
      end

      selector = "##{@form_id}"
      view |> form(selector, customer: %{name: "Protected draft"}) |> render_change()

      for event <- ["validate_customer", "save_customer"], params <- [nil, "bad", [], 42] do
        view |> with_target(target) |> render_click(event, %{"customer" => params})

        assert has_element?(
                 view,
                 "#{selector} input[name='customer[name]'][value='Protected draft']"
               )

        assert Repo.aggregate(Customer, :count) == 1
        assert Customers.get_customer!(existing.id).name == existing.name
      end

      view |> form(selector) |> render_submit()
      assert has_element?(view, "#customer-notice[role=status]")
      assert [saved] = Customers.search_customers_by_name("Protected draft")

      if @mode == :new,
        do: refute(saved.id == existing.id),
        else: assert(saved.id == existing.id)
    end
  end

  # An omitted value attribute and value="" both produce an empty browser input.
  defp blank_name_value(view) do
    view
    |> element("#customer-create-form input[name='customer[name]']")
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.attribute("value")
    |> List.first()
    |> then(&(&1 || ""))
  end

  defp clients_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=clients]:not([phx-target])") |> render_click()
    view
  end

  defp new_customer(view),
    do: view |> element("button[phx-click=new_customer]", "Add New Client") |> render_click()

  defp row_ids(view),
    do:
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#clients-list > tr")
      |> LazyHTML.attribute("id")

  defp component_target(view),
    do:
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("form[phx-change=search]")
      |> LazyHTML.attribute("phx-target")
      |> hd()
      |> String.to_integer()
end
