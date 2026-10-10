defmodule LicoriceLaneWeb.AdminCustomersTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.CustomersFixtures
  import LicoriceLane.LocationsFixtures
  import LicoriceLane.MessagesFixtures

  alias LicoriceLane.Customers
  alias LicoriceLaneWeb.Admin.ClientsComponent

  setup %{conn: conn} do
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  test "details show the customer's full fields and locations with escaped text", %{conn: conn} do
    customer =
      customer_fixture(%{name: "Synthetic client", notes: "Line one\n<script>example</script>"})

    location = customer_location_fixture(%{customer: customer, name: "Synthetic venue"})
    view = clients_view(conn)
    open_customer(view, customer, "view_customer")
    assert has_element?(view, "#customer-detail-modal h3", "Customer Details")

    for field <- [:name, :email, :phone, :contact_person, :billing_address] do
      assert has_element?(view, "#customer-detail-modal dd", Map.fetch!(customer, field))
    end

    # LiveViewTest's text matcher normalizes whitespace; inspect escaped HTML for the newline.
    assert render(view) =~ "Line one\n&lt;script&gt;example&lt;/script&gt;"
    assert has_element?(view, "#customer-detail-modal li", location.name)
    refute has_element?(view, "#customer-detail-modal script")
    refute has_element?(view, "#customer-edit-form")
    view |> element("#customer-detail-modal button", "Close") |> render_click()
    refute has_element?(view, "#customer-detail-modal")
  end

  test "details support a customer with only a name", %{conn: conn} do
    {:ok, customer} = Customers.create_customer(%{name: "Minimal client"})
    view = clients_view(conn)
    open_customer(view, customer, "view_customer")
    assert has_element?(view, "#customer-detail-modal dd", "Not provided")
    assert has_element?(view, "#customer-detail-modal", "No locations recorded.")
  end

  test "details can switch to a prefilled edit form and save every supported field", %{conn: conn} do
    customer = customer_fixture()
    view = clients_view(conn)
    open_customer(view, customer, "view_customer")
    view |> element("#customer-detail-modal button", "Edit Customer") |> render_click()

    assert has_element?(
             view,
             "#customer-edit-form input[name='customer[name]'][value='#{customer.name}']"
           )

    assert has_element?(
             view,
             "#customer-edit-form textarea[name='customer[notes]']",
             customer.notes
           )

    params = %{
      name: "Edited client",
      email: "edited-client@example.com",
      phone: "555-1010",
      contact_person: "Edited contact",
      billing_address: "Edited address\nSecond line",
      notes: "Edited notes"
    }

    view |> form("#customer-edit-form", customer: params) |> render_submit()
    refute has_element?(view, "#customer-detail-modal")
    assert has_element?(view, "#customer-notice[role=status]", "Customer updated successfully.")
    assert has_element?(view, "#customers-#{customer.id}", "Edited client")
    updated = Customers.get_customer!(customer.id)
    assert Map.take(updated, Map.keys(params)) == params
  end

  test "validation retains entered fields, persists nothing and allows a corrected retry", %{
    conn: conn
  } do
    customer = customer_fixture()
    view = clients_view(conn)
    open_customer(view, customer, "edit_customer")
    invalid = %{name: "", email: "invalid", phone: "invalid", notes: "Unsaved notes"}
    view |> form("#customer-edit-form", customer: invalid) |> render_change()
    assert has_element?(view, "#customer-edit-form", "can't be blank")
    assert has_element?(view, "#customer-edit-form", "has invalid format")

    assert has_element?(
             view,
             "#customer-edit-form textarea[name='customer[notes]']",
             "Unsaved notes"
           )

    assert Customers.get_customer!(customer.id).name == customer.name
    view |> form("#customer-edit-form", customer: invalid) |> render_submit()
    assert has_element?(view, "#customer-edit-error", "Please correct the errors below.")
    assert Customers.get_customer!(customer.id).notes == customer.notes

    valid = %{name: "Corrected client", email: "corrected@example.com", phone: "555-2020"}
    view |> form("#customer-edit-form", customer: valid) |> render_submit()
    assert Customers.get_customer!(customer.id).name == "Corrected client"
    assert Customers.get_customer!(customer.id).notes == "Unsaved notes"
  end

  test "Cancel discards drafts and reopening loads the saved customer", %{conn: conn} do
    customer = customer_fixture()
    view = clients_view(conn)
    open_customer(view, customer, "edit_customer")

    view
    |> form("#customer-edit-form", customer: %{name: "Discard this draft"})
    |> render_change()

    view |> element("#customer-edit-form button", "Cancel") |> render_click()
    refute has_element?(view, "#customer-detail-modal")
    assert Customers.get_customer!(customer.id).name == customer.name
    open_customer(view, customer, "edit_customer")
    assert has_element?(view, "input[name='customer[name]'][value='#{customer.name}']")
  end

  test "edit refresh preserves the draft during component updates and message broadcasts", %{
    conn: conn
  } do
    customer = customer_fixture()
    view = clients_view(conn)
    open_customer(view, customer, "edit_customer")

    view
    |> form("#customer-edit-form", customer: %{name: "Active draft", notes: "Draft notes"})
    |> render_change()

    Phoenix.LiveView.send_update(view.pid, ClientsComponent, id: "clients-component")
    message_fixture()
    render(view)
    assert has_element?(view, "input[name='customer[name]'][value='Active draft']")
    assert has_element?(view, "textarea[name='customer[notes]']", "Draft notes")
    view |> form("#customer-edit-form") |> render_submit()
    assert Customers.get_customer!(customer.id).name == "Active draft"
  end

  test "editing on page two retains search and page, and leaving the filter clamps the list", %{
    conn: conn
  } do
    customers =
      for n <- 1..26,
          do: customer_fixture(%{name: "Match #{String.pad_leading(to_string(n), 2, "0")}"})

    view = clients_view(conn)
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Match"})
    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
    last = List.last(customers)
    open_customer(view, last, "edit_customer")

    view
    |> form("#customer-edit-form", customer: %{notes: "Edited on page two"})
    |> render_submit()

    assert row_ids(view) == ["customers-#{last.id}"]
    assert has_element?(view, "input[name=search_term][value=Match]")
    open_customer(view, last, "edit_customer")
    view |> form("#customer-edit-form", customer: %{name: "Outside filter"}) |> render_submit()
    assert row_ids(view) == Enum.map(Enum.take(customers, 25), &"customers-#{&1.id}")
    refute has_element?(view, "nav[aria-label=Pagination]")
    assert has_element?(view, "input[name=search_term][value=Match]")
  end

  test "clearing contact fields removes the customer from the old exact lookup", %{conn: conn} do
    customer = customer_fixture(%{email: "old-lookup@example.com", phone: "555-3030"})
    view = clients_view(conn)

    view
    |> form("form[phx-change=search]")
    |> render_change(%{"search_term" => "old-lookup@example.com"})

    open_customer(view, customer, "edit_customer")
    view |> form("#customer-edit-form", customer: %{email: "", phone: ""}) |> render_submit()
    assert row_ids(view) == []
    assert Customers.find_customer_by_email("old-lookup@example.com") == []
    assert Customers.find_customer_by_phone("555-3030") == []
    assert has_element?(view, "input[name=search_term][value='old-lookup@example.com']")
  end

  test "missing and malformed customer selections fail gracefully", %{conn: conn} do
    customer = customer_fixture()
    view = clients_view(conn)
    target = component_target(view)
    assert {:ok, _} = Customers.delete_customer(customer)

    for event <- ["view_customer", "edit_customer"],
        id <- [to_string(customer.id), "invalid", "0", "-1", "999999999999999999999999", nil, %{}] do
      view |> with_target(target) |> render_click(event, %{"customer-id" => id})

      assert has_element?(
               view,
               "#customer-notice[role=alert]",
               "Customer is no longer available."
             )

      refute has_element?(view, "#customer-detail-modal")
    end
  end

  test "a customer deleted during editing returns an error and retains the draft", %{conn: conn} do
    customer = customer_fixture()
    view = clients_view(conn)
    open_customer(view, customer, "edit_customer")
    assert {:ok, _} = Customers.delete_customer(customer)
    view |> form("#customer-edit-form", customer: %{name: "Stale draft"}) |> render_submit()
    assert has_element?(view, "#customer-edit-error", "Customer is no longer available.")
    assert has_element?(view, "input[name='customer[name]'][value='Stale draft']")
    assert Customers.get_customer(customer.id) == nil
    view |> element("#customer-edit-form button", "Cancel") |> render_click()
    refute has_element?(view, "#customer-detail-modal")
    assert row_ids(view) == []
  end

  test "save uses the server selection and ignores a supplied customer id", %{conn: conn} do
    customer = customer_fixture()
    other = customer_fixture()
    view = clients_view(conn)
    target = component_target(view)

    view
    |> with_target(target)
    |> render_click("save_customer", %{"customer" => %{"id" => other.id, "name" => "Ignored"}})

    assert Customers.get_customer!(other.id).name == other.name
    open_customer(view, customer, "edit_customer")
    target = component_target(view)

    view
    |> with_target(target)
    |> render_submit("save_customer", %{
      "customer" => %{"id" => other.id, "name" => "Selected edit"}
    })

    assert Customers.get_customer!(customer.id).name == "Selected edit"
    assert Customers.get_customer!(other.id).name == other.name
  end

  defp clients_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=clients]:not([phx-target])") |> render_click()
    view
  end

  defp open_customer(view, customer, event),
    do: view |> element("#customers-#{customer.id} button[phx-click=#{event}]") |> render_click()

  defp row_ids(view),
    do:
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#clients-list > tr")
      |> LazyHTML.attribute("id")

  defp component_target(view) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("form[phx-change=search]")
    |> LazyHTML.attribute("phx-target")
    |> hd()
    |> String.to_integer()
  end
end
