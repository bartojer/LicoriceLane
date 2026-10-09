defmodule LicoriceLaneWeb.InventoryLiveTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.ItemsFixtures
  alias LicoriceLane.Inventory

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
