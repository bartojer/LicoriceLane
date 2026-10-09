defmodule LicoriceLaneWeb.AdminPaginationTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.CustomersFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.MessagesFixtures
  import LicoriceLane.RentalsFixtures

  alias LicoriceLane.{Customers, Inventory, Messages, Repo}
  alias LicoriceLaneWeb.Admin

  setup %{conn: conn} do
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  for {tab, container, component} <- [
        {"inventory", "inventory-items", Admin.InventoryComponent},
        {"clients", "clients-list", Admin.ClientsComponent},
        {"messages", "messages-list", Admin.MessagesComponent},
        {"bookings", "bookings-list", Admin.BookingsComponent}
      ] do
    @tab tab
    @container container
    @component component

    test "#{tab} pages survive refresh, normalize inputs and recover when the last page disappears",
         %{conn: conn} do
      customer = if @tab == "bookings", do: customer_fixture()
      records = for n <- 1..26, do: fixture(@tab, n, customer)
      {:ok, view, _} = live(conn, "/admin")
      view |> element("button[phx-value-tab='#{@tab}']:not([phx-target])") |> render_click()
      first_ids = row_ids(view, @container)
      assert length(first_ids) == 25

      target =
        render(view)
        |> LazyHTML.from_document()
        |> LazyHTML.query("nav[aria-label=Pagination] button")
        |> LazyHTML.attribute("phx-target")
        |> hd()
        |> String.to_integer()

      view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
      [last_id] = row_ids(view, @container)
      refute last_id in first_ids

      Phoenix.LiveView.send_update(view.pid, @component, id: tab_component_id(@tab))
      assert row_ids(view, @container) == [last_id]
      view |> with_target(target) |> render_click("page", %{"page" => "999"})
      assert row_ids(view, @container) == [last_id]

      for page <- ["invalid", "-1", "0"] do
        view |> with_target(target) |> render_click("page", %{"page" => page})
        assert row_ids(view, @container) == first_ids
      end

      view |> with_target(target) |> render_click("page", %{"page" => "2"})
      last = Enum.find(records, &String.ends_with?(last_id, "-#{&1.id}"))
      delete_record(@tab, last)
      Phoenix.LiveView.send_update(view.pid, @component, id: tab_component_id(@tab))
      assert row_ids(view, @container) == first_ids
      refute has_element?(view, "nav[aria-label=Pagination]")
    end

    test "#{tab} filters reset the page and persist across component updates", %{conn: conn} do
      customer = if @tab == "bookings", do: customer_fixture()
      for n <- 1..26, do: fixture(@tab, n, customer)
      {:ok, view, _} = live(conn, "/admin")
      view |> element("button[phx-value-tab='#{@tab}']:not([phx-target])") |> render_click()
      view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
      filter_empty(view, @tab)
      assert row_ids(view, @container) == []
      refute has_element?(view, "nav[aria-label=Pagination]")
      Phoenix.LiveView.send_update(view.pid, @component, id: tab_component_id(@tab))
      assert row_ids(view, @container) == []
      filter_all(view, @tab)
      assert length(row_ids(view, @container)) == 25
      assert has_element?(view, "nav[aria-label=Pagination] button", "Next")
    end
  end

  defp row_ids(view, container) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("##{container} > tr")
    |> LazyHTML.attribute("id")
  end

  defp tab_component_id("clients"), do: "clients-component"
  defp tab_component_id(tab), do: "#{tab}-component"

  defp fixture("inventory", n, _),
    do: single_item_fixture(%{name: "Fixture #{String.pad_leading(to_string(n), 2, "0")}"})

  defp fixture("clients", n, _),
    do: customer_fixture(%{name: "Fixture #{String.pad_leading(to_string(n), 2, "0")}"})

  defp fixture("messages", n, _), do: message_fixture(%{name: "Fixture #{n}"})
  defp fixture("bookings", _, customer), do: rental_fixture(%{customer: customer})

  defp delete_record("inventory", record), do: Inventory.delete_item(record)
  defp delete_record("clients", record), do: Customers.delete_customer(record)
  defp delete_record("messages", record), do: Messages.delete_message(record)
  defp delete_record("bookings", record), do: Repo.delete!(record)

  defp filter_empty(view, "inventory"),
    do:
      view |> form("form[phx-change=filter_category]") |> render_change(%{"category" => "linen"})

  defp filter_empty(view, "clients"),
    do: view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "missing"})

  defp filter_empty(view, "messages"),
    do: view |> element("button[phx-value-status=archived]") |> render_click()

  defp filter_empty(view, "bookings"),
    do:
      view |> form("form[phx-change=filter_status]") |> render_change(%{"status" => "cancelled"})

  defp filter_all(view, "inventory"),
    do: view |> form("form[phx-change=filter_category]") |> render_change(%{"category" => "all"})

  defp filter_all(view, "clients"),
    do: view |> form("form[phx-change=search]") |> render_change(%{"search_term" => ""})

  defp filter_all(view, "messages"),
    do: view |> element("button[phx-value-status=all]") |> render_click()

  defp filter_all(view, "bookings"),
    do: view |> form("form[phx-change=filter_status]") |> render_change(%{"status" => "all"})
end
