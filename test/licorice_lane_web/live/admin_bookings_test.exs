defmodule LicoriceLaneWeb.AdminBookingsTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.RentalsFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.MessagesFixtures

  alias LicoriceLane.{Rentals, Repo}
  alias LicoriceLane.Rentals.RentalBulkItem
  alias LicoriceLaneWeb.Admin.BookingsComponent

  setup %{conn: conn}, do: %{conn: log_in_user(conn, admin_user_fixture())}

  defp booking(attrs \\ %{}) do
    rental_fixture(
      Map.merge(
        %{
          rented_at: ~U[2026-11-01 10:00:13Z],
          return_by: ~U[2026-11-03 18:00:27Z],
          event_date: ~U[2026-11-02 12:00:41Z]
        },
        attrs
      )
    )
  end

  test "details show customer, status, dates, single items and bulk quantities", %{conn: conn} do
    single = single_item_fixture(%{name: "Single chair"})
    bulk = bulk_item_fixture(%{name: "Bulk napkins"})
    rental = rental_with_single_items_fixture(%{single_item: single})
    Repo.insert!(%RentalBulkItem{rental_id: rental.id, item_id: bulk.id, quantity: 7})
    view = bookings_view(conn)
    open_booking(view, rental, "view_rental")
    assert has_element?(view, "#booking-detail-modal h3", "Booking Details ##{rental.id}")
    assert has_element?(view, "#booking-detail-modal dd", rental.customer.name)
    assert has_element?(view, "#booking-detail-modal", "All dates and times are in UTC.")
    assert has_element?(view, "#booking-single-items li", "Single chair")
    assert has_element?(view, "#booking-single-items li", "Current location:")
    assert has_element?(view, "#booking-bulk-items li", "Bulk napkins — Quantity: 7")
    refute has_element?(view, "#booking-edit-form")
    view |> element("#booking-detail-modal button", "Close") |> render_click()
    refute has_element?(view, "#booking-detail-modal")
  end

  test "empty optional event details and item allocations render cleanly", %{conn: conn} do
    rental = booking(%{event_type: nil, event_date: nil})
    view = bookings_view(conn)
    open_booking(view, rental, "view_rental")
    assert has_element?(view, "#booking-detail-modal", "No items assigned.")
    assert has_element?(view, "#booking-detail-modal dd", "—")
  end

  test "details switch to editing and unchanged saves preserve timestamp seconds", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    open_booking(view, rental, "view_rental")
    view |> element("#booking-detail-modal button", "Update Booking") |> render_click()
    assert has_element?(view, "input[name='rental[rented_at]'][value='2026-11-01T10:00:13']")
    assert has_element?(view, "input[name='rental[event_date]'][value='2026-11-02T12:00:41']")
    assert has_element?(view, "input[name='rental[return_by]'][value='2026-11-03T18:00:27']")
    view |> form("#booking-edit-form") |> render_submit()
    assert has_element?(view, "#booking-notice[role=status]", "Booking updated successfully.")
    refute has_element?(view, "#booking-detail-modal")
    updated = Rentals.get_rental(rental.id)
    assert updated.rented_at == rental.rented_at
    assert updated.return_by == rental.return_by
    assert updated.event_date == rental.event_date
  end

  test "event and schedule edits persist while lifecycle controls remain protected", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    open_booking(view, rental, "update_rental")

    view
    |> form("#booking-edit-form",
      rental: %{
        event_type: "birthday",
        event_date: "2026-11-05T12:00:41",
        rented_at: "2026-11-04T10:00:13",
        return_by: "2026-11-06T18:00:27"
      }
    )
    |> render_submit()

    updated = Rentals.get_rental(rental.id)
    assert updated.event_type == :birthday
    assert updated.event_date == ~U[2026-11-05 12:00:41Z]
    assert updated.rented_at == ~U[2026-11-04 10:00:13Z]
    assert updated.return_by == ~U[2026-11-06 18:00:27Z]
    assert updated.status == rental.status
    assert updated.returned_at == nil
    assert has_element?(view, "#rentals-#{rental.id}", "Birthday Party")
  end

  test "invalid schedules retain input and can be corrected without reopening", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    open_booking(view, rental, "update_rental")
    bad = %{event_type: "corporate", return_by: "2026-10-31T12:00:00"}
    view |> form("#booking-edit-form", rental: bad) |> render_change()
    assert has_element?(view, "#booking-edit-form", "must be on or after pickup")
    view |> form("#booking-edit-form", rental: bad) |> render_submit()
    assert has_element?(view, "#booking-edit-error", "Please correct the errors below.")
    assert has_element?(view, "input[name='rental[return_by]'][value='2026-10-31T12:00:00']")
    assert Rentals.get_rental(rental.id).event_type == :wedding

    view
    |> form("#booking-edit-form", rental: %{return_by: "2026-11-04T12:00:00"})
    |> render_submit()

    assert Rentals.get_rental(rental.id).event_type == :corporate
  end

  test "Cancel discards changes and refresh preserves an active draft", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    open_booking(view, rental, "update_rental")
    view |> form("#booking-edit-form", rental: %{event_type: "corporate"}) |> render_change()
    Phoenix.LiveView.send_update(view.pid, BookingsComponent, id: "bookings-component")
    message_fixture()
    render(view)

    assert has_element?(
             view,
             "select[name='rental[event_type]'] option[value=corporate][selected]"
           )

    view |> element("#booking-edit-form button", "Cancel") |> render_click()
    assert Rentals.get_rental(rental.id).event_type == :wedding
    open_booking(view, rental, "update_rental")
    assert has_element?(view, "select[name='rental[event_type]'] option[value=wedding][selected]")
  end

  test "date/status filters and page survive a save and clamp after a booking leaves the date", %{
    conn: conn
  } do
    rentals = for _ <- 1..26, do: booking()
    view = bookings_view(conn)
    view |> form("form[phx-change=filter_status]") |> render_change(%{"status" => "active"})
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-11-02"})
    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()
    last = List.last(rentals)
    open_booking(view, last, "update_rental")
    view |> form("#booking-edit-form", rental: %{event_type: "corporate"}) |> render_submit()
    sync(view)
    assert row_ids(view) == ["rentals-#{last.id}"]
    open_booking(view, last, "update_rental")

    view
    |> form("#booking-edit-form", rental: %{event_date: "2026-11-03T12:00:41"})
    |> render_submit()

    sync(view)
    assert row_ids(view) == Enum.map(Enum.take(rentals, 25), &"rentals-#{&1.id}")
    refute has_element?(view, "nav[aria-label=Pagination]")
    assert has_element?(view, "input[name=date][value='2026-11-02']")
    assert has_element?(view, "select[name=status] option[value=active][selected]")
  end

  test "clearing optional event fields removes a row from the selected date", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    view |> form("form[phx-change=filter_date]") |> render_change(%{"date" => "2026-11-02"})
    open_booking(view, rental, "update_rental")

    view
    |> form("#booking-edit-form", rental: %{event_type: "", event_date: ""})
    |> render_submit()

    sync(view)
    assert row_ids(view) == []
    assert Rentals.get_rental(rental.id).event_date == nil
    assert Rentals.get_rental(rental.id).event_type == nil
  end

  test "missing and malformed selections and deleted saves do not crash", %{conn: conn} do
    rental = booking()
    view = bookings_view(conn)
    open_booking(view, rental, "update_rental")
    Repo.delete!(rental)
    view |> form("#booking-edit-form", rental: %{event_type: "birthday"}) |> render_submit()
    assert has_element?(view, "#booking-edit-error", "Booking is no longer available.")

    assert has_element?(
             view,
             "select[name='rental[event_type]'] option[value=birthday][selected]"
           )

    view |> element("#booking-edit-form button", "Cancel") |> render_click()
    assert row_ids(view) == []
    target = component_target(view)

    for event <- ["view_rental", "update_rental"],
        id <- [to_string(rental.id), "invalid", "0", "-1", "999999999999999999999999", nil, %{}] do
      view |> with_target(target) |> render_click(event, %{"rental-id" => id})
      assert has_element?(view, "#booking-notice[role=alert]", "Booking is no longer available.")
      refute has_element?(view, "#booking-detail-modal")
    end
  end

  test "rental broadcasts refresh another admin's details and dashboard while preserving drafts",
       %{conn: conn} do
    rental = booking()
    viewer = bookings_view(conn)
    editor = bookings_view(conn)
    {:ok, dashboard, _} = live(conn, "/admin")
    open_booking(viewer, rental, "view_rental")
    open_booking(editor, rental, "update_rental")
    editor |> form("#booking-edit-form", rental: %{event_type: "birthday"}) |> render_change()
    assert {:ok, _} = Rentals.update_rental_details(rental, %{event_type: :corporate})
    sync(viewer)
    sync(editor)
    sync(dashboard)
    assert has_element?(viewer, "#booking-detail-modal dd", "Corporate Event")
    assert has_element?(dashboard, "#recent-bookings", "Corporate Event")

    assert has_element?(
             editor,
             "select[name='rental[event_type]'] option[value=birthday][selected]"
           )

    editor |> form("#booking-edit-form") |> render_submit()

    assert has_element?(
             editor,
             "#booking-edit-error",
             "has changed; close and reopen this booking"
           )

    assert Rentals.get_rental(rental.id).event_type == :corporate
  end

  test "forged lifecycle and record IDs cannot alter stock or another booking", %{conn: conn} do
    rental = booking()
    other = booking()
    view = bookings_view(conn)
    target = component_target(view)

    params = %{
      "rental" => %{
        "id" => other.id,
        "status" => "returned",
        "customer_id" => other.customer_id,
        "event_type" => "birthday"
      }
    }

    view |> with_target(target) |> render_submit("save_rental", params)
    assert Rentals.get_rental(other.id).event_type == :wedding
    open_booking(view, rental, "update_rental")
    view |> with_target(target) |> render_submit("save_rental", params)
    updated = Rentals.get_rental(rental.id)
    assert updated.status == rental.status
    assert updated.customer_id == rental.customer_id
    assert updated.event_type == :birthday
    assert Rentals.get_rental(other.id).event_type == :wedding
  end

  defp bookings_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=bookings]:not([phx-target])") |> render_click()
    view
  end

  defp open_booking(view, rental, event),
    do: view |> element("#rentals-#{rental.id} button[phx-click=#{event}]") |> render_click()

  defp sync(view) do
    render(view)
    render(view)
  end

  defp row_ids(view),
    do:
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#bookings-list > tr")
      |> LazyHTML.attribute("id")

  defp component_target(view) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("form[phx-change=filter_status]")
    |> LazyHTML.attribute("phx-target")
    |> hd()
    |> String.to_integer()
  end
end
