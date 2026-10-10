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

    test "#{tab} pagination and filters survive refresh, normalize inputs and recover deleted pages",
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

      filter_empty(view, @tab)
      assert row_ids(view, @container) == []
      refute has_element?(view, "nav[aria-label=Pagination]")
      Phoenix.LiveView.send_update(view.pid, @component, id: tab_component_id(@tab))
      assert row_ids(view, @container) == []
      filter_all(view, @tab)
      assert row_ids(view, @container) == first_ids
      assert has_element?(view, "nav[aria-label=Pagination] button", "Next")
      view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
      assert row_ids(view, @container) == [last_id]

      last = Enum.find(records, &String.ends_with?(last_id, "-#{&1.id}"))
      delete_record(@tab, last)
      Phoenix.LiveView.send_update(view.pid, @component, id: tab_component_id(@tab))
      assert row_ids(view, @container) == first_ids
      refute has_element?(view, "nav[aria-label=Pagination]")
    end
  end

  test "booking event date combines with status, persists on refresh, and can be cleared", %{
    conn: conn
  } do
    customer = customer_fixture()

    active =
      rental_fixture(%{
        customer: customer,
        event_date: ~U[2026-10-09 23:59:59Z],
        rented_at: ~U[2026-10-08 12:00:00Z]
      })

    returned =
      rental_fixture(%{
        customer: customer,
        event_date: ~U[2026-10-09 00:00:00Z],
        status: :returned
      })

    other =
      rental_fixture(%{
        customer: customer,
        event_date: ~U[2026-10-10 12:00:00Z],
        rented_at: ~U[2026-10-09 12:00:00Z]
      })

    undated = rental_fixture(%{customer: customer, event_date: nil})
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=bookings]:not([phx-target])") |> render_click()

    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-10-09"})
    assert booking_ids(view) == Enum.sort([active.id, returned.id])
    assert has_element?(view, "input[name=date][value='2026-10-09'][aria-label='Event date']")
    view |> form("form[phx-change=filter_status]") |> render_change(%{"status" => "active"})
    assert booking_ids(view) == [active.id]
    Phoenix.LiveView.send_update(view.pid, Admin.BookingsComponent, id: "bookings-component")
    assert booking_ids(view) == [active.id]
    assert has_element?(view, "input[name=date][value='2026-10-09']")

    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => ""})
    assert booking_ids(view) == Enum.sort([active.id, other.id, undated.id])
    assert has_element?(view, "select[name=status] option[value=active][selected]")
  end

  test "booking date changes reset pages and pagination retains the selected date", %{conn: conn} do
    customer = customer_fixture()

    matches =
      for _ <- 1..26,
          do:
            rental_fixture(%{
              customer: customer,
              event_date: ~U[2026-10-09 12:00:00Z],
              rented_at: ~U[2026-10-08 12:00:00Z]
            })

    other = rental_fixture(%{customer: customer, event_date: ~U[2026-10-10 12:00:00Z]})
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=bookings]:not([phx-target])") |> render_click()
    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-10-09"})
    assert booking_ids(view) == matches |> Enum.take(25) |> Enum.map(& &1.id)
    assert pagination_total(view) == 26

    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
    assert booking_ids(view) == [List.last(matches).id]
    Phoenix.LiveView.send_update(view.pid, Admin.BookingsComponent, id: "bookings-component")
    assert booking_ids(view) == [List.last(matches).id]
    assert has_element?(view, "input[name=date][value='2026-10-09']")

    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-10-10"})
    assert booking_ids(view) == [other.id]
    refute has_element?(view, "nav[aria-label=Pagination]")
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-10-11"})
    assert booking_ids(view) == []
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => ""})
    assert length(booking_ids(view)) == 25
    assert pagination_total(view) == 27
  end

  test "booking date rejects malformed events safely and clears invalid date strings", %{
    conn: conn
  } do
    matching = rental_fixture(%{event_date: ~U[2026-10-09 12:00:00Z]})
    other = rental_fixture(%{event_date: nil})
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=bookings]:not([phx-target])") |> render_click()
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-10-09"})

    target =
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("form[phx-change=filter_date]")
      |> LazyHTML.attribute("phx-target")
      |> hd()
      |> String.to_integer()

    for params <- [%{}, %{"date" => nil}, %{"date" => %{}}, %{"date" => []}] do
      view |> with_target(target) |> render_click("filter_date", params)
      assert booking_ids(view) == [matching.id]
      assert has_element?(view, "input[name=date][value='2026-10-09']")
    end

    for date <- ["invalid", "2026-02-30"] do
      view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => date})
      assert booking_ids(view) == Enum.sort([matching.id, other.id])
      refute has_element?(view, "input[name=date][value='#{date}']")
    end
  end

  defp pagination_total(view) do
    view
    |> element("nav[aria-label=Pagination] p span:nth-of-type(3)")
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.text()
    |> String.to_integer()
  end

  defp booking_ids(view) do
    row_ids(view, "bookings-list")
    |> Enum.map(fn id -> id |> String.split("-") |> List.last() |> String.to_integer() end)
    |> Enum.sort()
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
