defmodule LicoriceLaneWeb.InventoryLiveTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures
  alias LicoriceLane.Inventory
  alias LicoriceLane.Locations.ItemsLocation
  alias LicoriceLane.Repo

  test "single availability agrees between cards and details for each tracking status", %{
    conn: conn
  } do
    items =
      for status <- [:available, :rented, :damaged], do: single_item_fixture(%{status: status})

    {:ok, view, _} = live(conn, "/inventory")

    for item <- items do
      available? = item.single_item.status == :available
      card = "#items-#{item.id}"
      button = if available?, do: "button:not([disabled])", else: "button[disabled]"
      card_label = if available?, do: "Add to Cart", else: "Sold Out"
      detail_label = if available?, do: "Add to Cart", else: "Currently Unavailable"
      absent_label = if available?, do: "Out of Stock", else: "Add to Cart"
      assert has_element?(view, "#{card} #{button}", card_label)
      view |> element(card) |> render_click()
      assert_patch(view, "/inventory/#{item.id}")
      assert has_element?(view, "#item-detail-modal h2", item.name)
      assert has_element?(view, "#item-detail-modal", item.description)
      assert has_element?(view, "#item-detail-modal img[src='#{item.image_path}']")
      assert has_element?(view, "#item-detail-modal", "$10.00")
      assert has_element?(view, "#item-detail-modal #{button}", detail_label)
      refute has_element?(view, "#item-detail-modal", absent_label)
      render_patch(view, "/inventory")
      refute has_element?(view, "#item-detail-modal")
    end
  end

  test "bulk cards and details use only warehouse stock, summed across warehouses", %{conn: conn} do
    customer_location = customer_location_fixture()
    unavailable = bulk_item_fixture(%{location: customer_location, quantity: 100})
    available = bulk_item_fixture(%{quantity: 2})

    Repo.insert!(%ItemsLocation{
      item_id: available.id,
      location_id: warehouse_fixture().id,
      quantity: 3
    })

    Repo.insert!(%ItemsLocation{
      item_id: available.id,
      location_id: customer_location.id,
      quantity: 100
    })

    {:ok, view, _} = live(conn, "/inventory")
    assert has_element?(view, "#items-#{available.id}", "In Stock: 5")
    assert has_element?(view, "#items-#{unavailable.id} button[disabled]", "Sold Out")

    for {item, button, label} <- [
          {available, "button:not([disabled])", "Add to Cart"},
          {unavailable, "button[disabled]", "Currently Unavailable"}
        ] do
      view |> element("#items-#{item.id}") |> render_click()
      assert_patch(view, "/inventory/#{item.id}")
      assert has_element?(view, "#item-detail-modal h2", item.name)
      assert has_element?(view, "#item-detail-modal #{button}", label)
      render_patch(view, "/inventory")
    end
  end

  test "stream cards have direct-child IDs and category buttons follow the active filter", %{
    conn: conn
  } do
    candle = single_item_fixture(%{category: :candle, name: "Matching candle"})
    electric = single_item_fixture(%{category: :electric_light, name: "Other light"})
    linen = bulk_item_fixture(%{category: :linen, name: "Matching linen"})
    {:ok, view, _} = live(conn, "/inventory")

    for item <- [candle, electric, linen] do
      assert has_element?(view, "#items > a#items-#{item.id}", item.name)
    end

    assert has_element?(view, "button[phx-click=show_all].bg-brand")
    view |> element("button[phx-click=show_lighting]") |> render_click()
    assert has_element?(view, "button[phx-click=show_lighting].bg-brand")
    refute has_element?(view, "button[phx-click=show_all].bg-brand")
    refute has_element?(view, "#items-#{linen.id}")
    assert has_element?(view, "#items-#{electric.id}")

    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Matching"})
    assert has_element?(view, "#items-#{candle.id}")
    refute has_element?(view, "#items-#{electric.id}")
    view |> element("button[phx-click=show_linen]") |> render_click()
    assert has_element?(view, "button[phx-click=show_linen].bg-brand")
    assert has_element?(view, "#items-#{linen.id}")
    refute has_element?(view, "#items-#{candle.id}")
  end

  test "PubSub updates replace a card without duplicates and preserve search/category filters", %{
    conn: conn
  } do
    candle = single_item_fixture(%{category: :candle, name: "Matching candle"})
    linen = bulk_item_fixture(%{category: :linen, name: "Matching linen"})
    {:ok, view, _} = live(conn, "/inventory")
    view |> element("button[phx-click=show_lighting]") |> render_click()
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Matching"})
    assert {:ok, _} = Inventory.update_item(candle, %{name: "Matching updated candle"})
    assert has_element?(view, "#items > a#items-#{candle.id}", "Matching updated candle")

    assert ["items-#{candle.id}"] ==
             render(view)
             |> LazyHTML.from_document()
             |> LazyHTML.query("#items > a")
             |> LazyHTML.attribute("id")

    refute has_element?(view, "#items-#{linen.id}")
    assert has_element?(view, "button[phx-click=show_lighting].bg-brand")
    view |> element("#items-#{candle.id}") |> render_click()
    assert_patch(view, "/inventory/#{candle.id}")
    assert has_element?(view, "#item-detail-modal h2", "Matching updated candle")
  end
end
