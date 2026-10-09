defmodule LicoriceLaneWeb.AdminInventoryDeleteTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.RentalsFixtures

  alias LicoriceLane.{Inventory, Repo}
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.ItemsLocation
  alias LicoriceLaneWeb.Admin.InventoryComponent

  setup %{conn: conn} do
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  for type <- [:single, :bulk] do
    @item_type type

    test "confirms #{@item_type} deletion, removes tracking/stock and refreshes admin and public lists",
         %{
           conn: conn
         } do
      item = item_fixture(@item_type)
      {:ok, public_view, _} = live(conn, "/inventory")
      view = inventory_view(conn)

      request_delete(view, item)
      assert has_element?(view, "#delete-item-modal-title", "Delete #{item.name}?")
      assert Repo.get!(Item, item.id)

      view |> element("#delete-item-modal button[phx-click=confirm_delete]") |> render_click()

      assert Repo.get(Item, item.id) == nil
      assert Repo.get(SingleItem, item.id) == nil
      refute Repo.get_by(ItemsLocation, item_id: item.id)
      refute has_element?(view, "#inventory-item-#{item.id}")
      refute has_element?(view, "#delete-item-modal")

      assert has_element?(
               view,
               "#inventory-delete-notice[role=status]",
               "Item deleted successfully."
             )

      refute has_element?(public_view, "#items-#{item.id}")
    end

    test "rejects deletion of a booked #{@item_type} item without crashing or losing its row", %{
      conn: conn
    } do
      item = item_fixture(@item_type)
      book_item(@item_type, item)
      view = inventory_view(conn)
      request_delete(view, item)
      view |> element("button[phx-click=confirm_delete]") |> render_click()

      assert has_element?(view, "#inventory-delete-notice[role=alert]", "Items used in bookings")
      assert has_element?(view, "#inventory-item-#{item.id}")
      assert Repo.get!(Item, item.id)

      if @item_type == :single do
        assert Repo.get!(SingleItem, item.id)
      else
        assert Repo.get_by!(ItemsLocation, item_id: item.id).quantity == 50
      end
    end
  end

  test "cancel and unrequested confirmation leave inventory unchanged", %{conn: conn} do
    item = single_item_fixture()
    view = inventory_view(conn)
    request_delete(view, item)
    target = component_target(view)
    view |> element("#delete-item-modal button[phx-click=cancel_delete]") |> render_click()
    refute has_element?(view, "#delete-item-modal")

    view |> with_target(target) |> render_click("confirm_delete", %{"item-id" => "#{item.id}"})
    assert Repo.get!(Item, item.id)
    assert has_element?(view, "#inventory-item-#{item.id}")
    refute has_element?(view, "#inventory-delete-notice")
  end

  test "confirmation uses the selected item and survives component updates", %{conn: conn} do
    item = single_item_fixture()
    other = single_item_fixture()
    view = inventory_view(conn)
    request_delete(view, item)
    Phoenix.LiveView.send_update(view.pid, InventoryComponent, id: "inventory-component")
    assert has_element?(view, "#delete-item-modal-title", item.name)

    view
    |> with_target(component_target(view))
    |> render_click("confirm_delete", %{"item-id" => "#{other.id}"})

    assert Repo.get(Item, item.id) == nil
    assert Repo.get!(Item, other.id)
    assert has_element?(view, "#inventory-item-#{other.id}")
  end

  test "deletion preserves filters and page, then clamps when the last page disappears", %{
    conn: conn
  } do
    items =
      for n <- 1..27 do
        bulk_item_fixture(%{name: "Matching #{String.pad_leading(to_string(n), 2, "0")}"})
      end

    single_item_fixture(%{name: "Matching excluded category"})
    bulk_item_fixture(%{name: "Excluded search"})
    view = inventory_view(conn)
    view |> form("form[phx-change=filter_category]") |> render_change(%{"category" => "linen"})
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Matching"})
    view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()

    [first, second] = Enum.drop(items, 25)
    request_delete(view, first)
    view |> element("button[phx-click=confirm_delete]") |> render_click()
    assert row_ids(view) == ["inventory-item-#{second.id}"]

    request_delete(view, second)
    view |> element("button[phx-click=confirm_delete]") |> render_click()
    assert row_ids(view) == Enum.map(Enum.take(items, 25), &"inventory-item-#{&1.id}")
    refute has_element?(view, "nav[aria-label=Pagination]")
    assert has_element?(view, "input[name=search_term][value=Matching]")
    assert has_element?(view, "select[name=category] option[value=linen][selected]")
  end

  test "an item deleted while its confirmation is open reports an error and refreshes", %{
    conn: conn
  } do
    item = bulk_item_fixture()
    view = inventory_view(conn)
    request_delete(view, item)
    assert {:ok, _} = Inventory.delete_item(item)
    view |> element("button[phx-click=confirm_delete]") |> render_click()

    assert has_element?(
             view,
             "#inventory-delete-notice[role=alert]",
             "Item is no longer available."
           )

    refute has_element?(view, "#inventory-item-#{item.id}")
    refute has_element?(view, "#delete-item-modal")
  end

  test "malformed and missing item IDs cannot delete inventory or crash the admin", %{conn: conn} do
    item = single_item_fixture()
    missing = single_item_fixture()
    assert {:ok, _} = Inventory.delete_item(missing)
    view = inventory_view(conn)
    target = component_target(view)

    for id <- [
          nil,
          "invalid",
          "#{item.id}extra",
          "0",
          "-1",
          "9223372036854775808",
          "#{missing.id}"
        ] do
      request_delete(view, item)
      view |> with_target(target) |> render_click("delete_item", %{"item-id" => id})
      refute has_element?(view, "#delete-item-modal")

      assert has_element?(
               view,
               "#inventory-delete-notice[role=alert]",
               "Item is no longer available."
             )

      view |> with_target(target) |> render_click("confirm_delete", %{})
      assert Repo.get!(Item, item.id)
    end
  end

  @tag skip: is_nil(System.get_env("UPLOAD_BROWSER_NODE"))
  @tag :browser
  @tag timeout: 120_000
  test "browser cancels the dialog and confirms single and bulk deletion" do
    start_supervised!({Bandit, plug: LicoriceLaneWeb.Endpoint, ip: {127, 0, 0, 1}, port: 4002})
    user = admin_user_fixture()
    single = single_item_fixture()
    bulk = bulk_item_fixture()

    # Keep Windows Node's script paths beside the existing upload script override.
    script_directory =
      case System.get_env("UPLOAD_BROWSER_SCRIPT") do
        nil -> Path.expand("test/browser")
        script -> Path.dirname(script)
      end

    {output, status} =
      System.cmd(
        System.fetch_env!("UPLOAD_BROWSER_NODE"),
        [
          Path.join(script_directory, "inventory_delete.cjs"),
          user.email,
          valid_user_password(),
          System.get_env("UPLOAD_PLAYWRIGHT_MODULE") || "playwright",
          System.get_env("UPLOAD_BROWSER_EXECUTABLE") || "",
          to_string(single.id),
          to_string(bulk.id)
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "passed"
    assert Repo.get(Item, single.id) == nil
    assert Repo.get(SingleItem, single.id) == nil
    assert Repo.get(Item, bulk.id) == nil
    refute Repo.get_by(ItemsLocation, item_id: bulk.id)
  end

  defp inventory_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=inventory]:not([phx-target])") |> render_click()
    view
  end

  defp request_delete(view, item) do
    view |> element("#inventory-item-#{item.id} button[phx-click=delete_item]") |> render_click()
  end

  defp component_target(view) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("button[phx-click=delete_item]")
    |> LazyHTML.attribute("phx-target")
    |> hd()
    |> String.to_integer()
  end

  defp row_ids(view) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("#inventory-items > tr")
    |> LazyHTML.attribute("id")
  end

  defp item_fixture(:single), do: single_item_fixture()
  defp item_fixture(:bulk), do: bulk_item_fixture()
  defp book_item(:single, item), do: rental_with_single_items_fixture(%{single_item: item})
  defp book_item(:bulk, item), do: rental_with_bulk_items_fixture(%{bulk_item: item})
end
