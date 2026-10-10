defmodule LicoriceLaneWeb.AdminRentalLifecycleTest do
  use LicoriceLaneWeb.ConnCase
  import Phoenix.LiveViewTest

  import LicoriceLane.{
    AccountsFixtures,
    CustomersFixtures,
    ItemsFixtures,
    LocationsFixtures,
    RentalsFixtures
  }

  alias LicoriceLane.{Rentals, Repo}
  alias LicoriceLane.Rentals.Rental
  alias LicoriceLane.Locations.ItemsLocation

  test "checking availability keeps the form open and creates no booking", c do
    view = bookings_view(c.conn)
    view |> element("button[phx-click=new_rental]") |> render_click()
    view |> element("button[phx-click=add_allocation]") |> render_click()
    request = Map.put(params(c), "operation", "availability")
    view |> with_target(target(view)) |> render_submit("save_booking", %{"rental" => request})
    assert has_element?(view, "#booking-reservation-form")
    assert has_element?(view, "#booking-notice", "Requested stock is available")
    Phoenix.PubSub.broadcast(LicoriceLane.PubSub, "rentals:updates", {:rental_updated, 0})
    render(view)
    assert has_element?(view, "input[name='rental[destination_name]'][value='Lifecycle venue']")
    assert Repo.aggregate(Rental, :count) == 0
  end

  setup %{conn: conn} do
    customer = customer_fixture()
    source = warehouse_fixture()
    other = warehouse_fixture()
    item = bulk_item_fixture(%{location: source, quantity: 10})
    Repo.insert!(%ItemsLocation{item_id: item.id, location_id: other.id, quantity: 5})

    %{
      conn: log_in_user(conn, admin_user_fixture()),
      customer: customer,
      source: source,
      other: other,
      item: item
    }
  end

  test "new reservation supports multiple warehouses and ignores a save replay", c do
    view = bookings_view(c.conn)
    view |> element("button[phx-click=new_rental]") |> render_click()
    view |> element("button[phx-click=add_allocation]") |> render_click()
    view |> form("#booking-reservation-form", rental: params(c)) |> render_submit()
    assert has_element?(view, "#booking-notice", "Reservation saved.")
    refute has_element?(view, "#booking-detail-modal")
    r = Repo.one!(Rental) |> then(&Rentals.get_rental(&1.id))
    assert r.status == :reserved and length(r.allocations) == 2
    assert hd(r.rental_bulk_items).quantity == 7
    view |> with_target(target(view)) |> render_submit("save_booking", %{"rental" => params(c)})
    assert Repo.aggregate(Rental, :count) == 1
    assert has_element?(view, "#rentals-#{r.id}", "Reserved")
  end

  test "validation retains reservations and refresh drafts; allocation editing releases old sources",
       c do
    view = bookings_view(c.conn)
    view |> element("button[phx-click=new_rental]") |> render_click()
    view |> element("button[phx-click=add_allocation]") |> render_click()
    bad = put_in(params(c), ["allocations", "0", "quantity"], "11")
    view |> form("#booking-reservation-form", rental: bad) |> render_submit()
    assert has_element?(view, "#booking-reservation-error", "insufficient stock")
    assert has_element?(view, "#allocation-quantity-0[value='11']")
    Phoenix.PubSub.broadcast(LicoriceLane.PubSub, "rentals:updates", {:rental_updated, 0})
    render(view)
    assert has_element?(view, "input[name='rental[destination_name]'][value='Lifecycle venue']")
    view |> form("#booking-reservation-form", rental: params(c)) |> render_submit()
    r = Repo.one!(Rental)
    open(view, r)
    view |> element("button[phx-click=edit_allocations]") |> render_click()
    view |> element("button[phx-click=remove_allocation][phx-value-index='0']") |> render_click()
    view |> form("#booking-reservation-form") |> render_submit()
    changed = Rentals.get_rental(r.id)
    assert hd(changed.allocations).source_location_id == c.other.id
    assert hd(changed.rental_bulk_items).quantity == 2
  end

  test "checkout, retained failed partial return, completion and replay protection", c do
    r = booking(c)
    view = bookings_view(c.conn)
    open(view, r)
    view |> element("button[phx-click=checkout_rental]") |> render_click()
    assert has_element?(view, "#booking-notice", "Booking checked out.")
    out = Rentals.get_rental(r.id)
    open(view, out)
    view |> element("button[phx-click=start_return]") |> render_click()
    a = Enum.find(out.allocations, &(&1.source_location_id == c.source.id))
    b = Enum.find(out.allocations, &(&1.source_location_id == c.other.id))

    invalid = %{
      "returns" => %{
        to_string(a.id) => %{"allocation_id" => a.id, "quantity" => "6"},
        to_string(b.id) => %{"allocation_id" => b.id, "quantity" => "1"}
      }
    }

    view |> with_target(target(view)) |> render_submit("return_items", %{"rental" => invalid})
    assert has_element?(view, "#booking-return-error", "outstanding units")
    assert has_element?(view, "#return-quantity-#{a.id}[value='6']")
    assert has_element?(view, "#return-quantity-#{b.id}[value='1']")
    Phoenix.PubSub.broadcast(LicoriceLane.PubSub, "rentals:updates", {:rental_updated, r.id})
    render(view)
    assert has_element?(view, "#return-quantity-#{b.id}[value='1']")
    good = put_in(invalid, ["returns", to_string(a.id), "quantity"], "2")
    view |> form("#booking-return-form", rental: good) |> render_submit()
    assert has_element?(view, "#booking-notice", "Return recorded.")
    view |> with_target(target(view)) |> render_submit("return_items", %{"rental" => good})
    partial = Rentals.get_rental(r.id)
    assert Enum.sum(Enum.map(partial.allocations, & &1.returned_quantity)) == 3
    open(view, partial)
    view |> element("button[phx-click=start_return]") |> render_click()

    finish =
      Map.new(partial.allocations, fn a ->
        {to_string(a.id),
         %{"allocation_id" => a.id, "quantity" => a.quantity - a.returned_quantity}}
      end)

    view |> form("#booking-return-form", rental: %{"returns" => finish}) |> render_submit()
    assert Rentals.get_rental(r.id).status == :returned
  end

  test "cancellation and legacy stock-action refusal", c do
    r = booking(c)
    legacy = rental_fixture()
    view = bookings_view(c.conn)
    open(view, legacy)
    assert has_element?(view, "#legacy-booking-notice", "reconciliation")
    refute has_element?(view, "button[phx-click=checkout_rental]")
    view |> with_target(target(view)) |> render_click("checkout_rental")
    assert Rentals.get_rental(legacy.id).status == :active
    view |> element("button[phx-click=close_rental]", "Close") |> render_click()
    open(view, r)
    view |> element("button[phx-click=cancel_booking]") |> render_click()
    assert Rentals.get_rental(r.id).status == :cancelled
    assert has_element?(view, "#booking-notice", "Reservation cancelled.")
  end

  test "another admin checkout makes allocation and schedule drafts stale", c do
    r = booking(c)
    editor = bookings_view(c.conn)
    open(editor, r)
    editor |> element("button[phx-click=edit_allocations]") |> render_click()
    assert {:ok, _} = Rentals.checkout_rental(r)
    render(editor)
    editor |> form("#booking-reservation-form") |> render_submit()
    assert has_element?(editor, "#booking-reservation-error", "has changed")
    assert Rentals.get_rental(r.id).status == :active
  end

  test "malformed scalar and nested payloads are rejected without crashing", c do
    view = bookings_view(c.conn)
    view |> element("button[phx-click=new_rental]") |> render_click()
    t = target(view)

    for index <- [nil, %{}, [], 0] do
      view |> with_target(t) |> render_click("remove_allocation", %{"index" => index})
      assert has_element?(view, "#allocation-item-0")
    end

    for event <- ["validate_booking", "save_booking"],
        field <- ["customer_id", "destination_name", "event_type"] do
      bad = Map.put(params(c), field, %{"bad" => "value"})
      view |> with_target(t) |> render_submit(event, %{"rental" => bad})
      assert has_element?(view, "#booking-reservation-form")
    end

    for event <- ["validate_booking", "save_booking"],
        field <- ["item_id", "source_location_id", "quantity"] do
      bad = put_in(params(c), ["allocations", "0", field], %{"bad" => "value"})
      view |> with_target(t) |> render_submit(event, %{"rental" => bad})
      assert has_element?(view, "#booking-reservation-form")
    end

    for event <- ["save_booking", "validate_booking"], nested <- [nil, [], "bad"] do
      view |> with_target(t) |> render_submit(event, %{"rental" => nested})
    end

    assert Repo.aggregate(Rental, :count) == 0
  end

  test "eleven allocation rows preserve numeric row order during validation", c do
    view = bookings_view(c.conn)
    view |> element("button[phx-click=new_rental]") |> render_click()

    rows =
      Map.new(0..10, fn n ->
        {to_string(n),
         %{
           "item_id" => c.item.id,
           "source_location_id" => c.source.id,
           "quantity" => to_string(n + 1)
         }}
      end)

    view
    |> with_target(target(view))
    |> render_change("validate_booking", %{"rental" => Map.put(params(c), "allocations", rows)})

    for n <- 0..10, do: assert(has_element?(view, "#allocation-quantity-#{n}[value='#{n + 1}']"))
  end

  defp params(c) do
    %{
      "customer_id" => c.customer.id,
      "destination_name" => "Lifecycle venue",
      "rented_at" => stamp(-60),
      "return_by" => stamp(3600),
      "allocations" => %{
        "0" => %{"item_id" => c.item.id, "source_location_id" => c.source.id, "quantity" => "5"},
        "1" => %{"item_id" => c.item.id, "source_location_id" => c.other.id, "quantity" => "2"}
      }
    }
  end

  defp booking(c) do
    {:ok, r} = Rentals.create_rental(params(c))
    r
  end

  defp stamp(seconds),
    do:
      DateTime.utc_now()
      |> DateTime.add(seconds)
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

  defp bookings_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=bookings]:not([phx-target])") |> render_click()
    view
  end

  defp open(view, r),
    do: view |> element("#rentals-#{r.id} button[phx-click=view_rental]") |> render_click()

  defp target(view),
    do:
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("form[phx-change=filter_status]")
      |> LazyHTML.attribute("phx-target")
      |> hd()
      |> String.to_integer()
end
