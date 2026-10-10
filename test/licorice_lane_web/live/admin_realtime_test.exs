defmodule LicoriceLaneWeb.AdminRealtimeTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures
  import LicoriceLane.MessagesFixtures

  alias LicoriceLane.{Inventory, Messages, Repo}

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlS8AAAAASUVORK5CYII="
       )

  setup %{conn: conn} do
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  test "dashboard refreshes low-stock rows and counts after creation, updates and deletion", %{
    conn: conn
  } do
    warehouse = warehouse_fixture()
    {:ok, view, _} = live(conn, "/admin")
    assert low_stock_count(view) == "0"

    {:ok, item} =
      Inventory.create_item_with_location(%{
        name: "Low stock linen",
        description: "Synthetic linen",
        item_type: :bulk,
        category: :linen,
        location_id: warehouse.id,
        quantity: 2,
        min_stock: 10
      })

    sync(view)
    assert has_element?(view, "#low-stock-item-#{item.id}", "2 in stock")
    assert low_stock_count(view) == "1"
    {:ok, item} = Inventory.update_item(item, %{name: "Renamed linen"})
    sync(view)
    assert has_element?(view, "#low-stock-item-#{item.id}", "Renamed linen")
    {:ok, item} = Inventory.update_item(item, %{min_stock: 1})
    sync(view)
    refute has_element?(view, "#low-stock-item-#{item.id}")
    assert low_stock_count(view) == "0"
    {:ok, item} = Inventory.update_item(item, %{min_stock: 10})
    sync(view)
    assert low_stock_count(view) == "1"
    {:ok, _} = Inventory.delete_item(item)
    sync(view)
    refute has_element?(view, "#low-stock-item-#{item.id}")
    assert low_stock_count(view) == "0"
  end

  test "inventory refresh preserves category, search and page and clamps a shrinking list", %{
    conn: conn
  } do
    items =
      for n <- 1..26,
          do: single_item_fixture(%{name: "Match #{String.pad_leading(to_string(n), 2, "0")}"})

    excluded = bulk_item_fixture(%{name: "Match excluded"})
    view = tab_view(conn, "inventory")

    view
    |> form("form[phx-change=filter_category]")
    |> render_change(%{"category" => "tableware"})

    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Match"})
    next_page(view)
    last = List.last(items)
    assert row_ids(view, "inventory-items") == ["inventory-item-#{last.id}"]

    {:ok, _} = Inventory.update_item(last, %{description: "Updated elsewhere"})
    {:ok, _} = Inventory.update_item(excluded, %{name: "Match changed elsewhere"})
    sync(view)
    assert row_ids(view, "inventory-items") == ["inventory-item-#{last.id}"]
    assert has_element?(view, "input[name=search_term][value=Match]")
    assert has_element?(view, "select[name=category] option[value=tableware][selected]")

    {:ok, _} = Inventory.delete_item(last)
    sync(view)

    assert row_ids(view, "inventory-items") ==
             Enum.map(Enum.take(items, 25), &"inventory-item-#{&1.id}")

    refute has_element?(view, "nav[aria-label=Pagination]")
  end

  test "inventory refresh retains an open deletion confirmation", %{conn: conn} do
    item = single_item_fixture()
    other = single_item_fixture()
    view = tab_view(conn, "inventory")

    view
    |> element("button[phx-click=delete_item][phx-value-item-id='#{item.id}']")
    |> render_click()

    {:ok, _} = Inventory.update_item(other, %{name: "Updated elsewhere"})
    sync(view)
    assert has_element?(view, "#delete-item-modal", item.name)
    assert has_element?(view, "#inventory-item-#{other.id}", "Updated elsewhere")
    assert Inventory.get_item(item.id)
  end

  test "message creation refreshes the searched status page without appending off-page rows", %{
    conn: conn
  } do
    messages = for n <- 1..26, do: dated_message("Match #{n}", n)
    view = tab_view(conn, "messages")
    view |> element("button[phx-value-status=new]") |> render_click()
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Match"})
    next_page(view)
    first = hd(messages)
    assert row_ids(view, "messages-list") == ["messages-#{first.id}"]

    matching = message_fixture(%{name: "Match newest"})
    message_fixture(%{name: "Unrelated newest"})
    message_fixture(%{name: "Match archived", status: :archived})
    sync(view)

    assert row_ids(view, "messages-list") == [
             "messages-#{Enum.at(messages, 1).id}",
             "messages-#{first.id}"
           ]

    refute has_element?(view, "#messages-#{matching.id}")
    assert pagination_total(view) == "27"
    assert has_element?(view, "input[name=search_term][value=Match]")
    assert has_element?(view, "button[phx-value-status=new].bg-brand")
  end

  test "status updates remove filtered messages, refill pages and clamp the last page", %{
    conn: conn
  } do
    messages = for n <- 1..26, do: dated_message("Sender #{n}", n)
    view = tab_view(conn, "messages")
    view |> element("button[phx-value-status=new]") |> render_click()
    next_page(view)
    {:ok, _} = Messages.mark_as_archived(hd(messages))
    sync(view)
    assert length(row_ids(view, "messages-list")) == 25
    refute has_element?(view, "#messages-#{hd(messages).id}")
    refute has_element?(view, "nav[aria-label=Pagination]")
    {:ok, _} = Messages.mark_as_read(Enum.at(messages, 1))
    sync(view)
    assert length(row_ids(view, "messages-list")) == 24
    refute has_element?(view, "#messages-#{Enum.at(messages, 1).id}")
  end

  test "updates bring messages into a filter without inserting unrelated rows", %{conn: conn} do
    matching = message_fixture(%{name: "Match", status: :read})
    other = message_fixture(%{name: "Unrelated", status: :read})
    view = tab_view(conn, "messages")
    view |> element("button[phx-value-status=new]") |> render_click()
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "Match"})
    assert row_ids(view, "messages-list") == []
    {:ok, _} = Messages.mark_as_new(matching)
    {:ok, _} = Messages.mark_as_new(other)
    sync(view)
    assert row_ids(view, "messages-list") == ["messages-#{matching.id}"]
  end

  test "opening a new message refreshes both admins' lists, modal and unread badges", %{
    conn: conn
  } do
    message = message_fixture()
    first = tab_view(conn, "messages")
    second = tab_view(conn, "messages")
    first |> element("button[phx-value-status=new]") |> render_click()
    first |> element("#messages-#{message.id}") |> render_click()
    sync(first)
    sync(second)
    assert Messages.get_message!(message.id).status == :read
    refute has_element?(first, "#messages-#{message.id}")
    assert has_element?(first, "#message-detail-modal span", "Read")
    assert has_element?(second, "#messages-#{message.id} span", "Read")
    refute has_element?(first, "button[phx-value-tab=messages] span")
    refute has_element?(second, "button[phx-value-tab=messages] span")
    first |> element("#message-detail-modal button[phx-value-status=archived]") |> render_click()
    sync(second)
    assert has_element?(second, "#messages-#{message.id} span", "Archived")
  end

  test "selected message reloads current notes and status even for an older queued broadcast", %{
    conn: conn
  } do
    message = message_fixture(%{status: :read})
    view = tab_view(conn, "messages")
    view |> element("#messages-#{message.id}") |> render_click()

    {:ok, _} =
      Messages.update_message_status(message, %{status: :archived, admin_notes: "Latest notes"})

    sync(view)
    assert has_element?(view, "#message-detail-modal span", "Archived")
    assert has_element?(view, "#admin-notes", "Latest notes")
    send(view.pid, {:message_updated, message})
    sync(view)
    assert has_element?(view, "#message-detail-modal span", "Archived")
    assert has_element?(view, "#admin-notes", "Latest notes")
  end

  test "unsaved notes survive matching and unrelated broadcasts and save without reverting status",
       %{
         conn: conn
       } do
    message = message_fixture(%{status: :read})
    other = message_fixture(%{status: :read})
    view = tab_view(conn, "messages")
    view |> element("#messages-#{message.id}") |> render_click()
    view |> form("#admin-notes-form", admin_notes: "Local draft") |> render_change()

    {:ok, _} =
      Messages.update_message_status(message, %{status: :archived, admin_notes: "Remote notes"})

    {:ok, _} = Messages.mark_as_new(other)
    message_fixture()
    sync(view)
    assert has_element?(view, "#message-detail-modal span", "Archived")
    assert has_element?(view, "#admin-notes", "Local draft")
    assert Messages.get_message!(message.id).admin_notes == "Remote notes"
    view |> element("#admin-notes") |> render_blur(%{"value" => "Local draft"})
    sync(view)
    saved = Messages.get_message!(message.id)
    assert saved.admin_notes == "Local draft"
    assert saved.status == :archived
    {:ok, _} = Messages.update_message_status(saved, %{admin_notes: "Later remote notes"})
    sync(view)
    assert has_element?(view, "#admin-notes", "Later remote notes")
  end

  test "closing the modal clears the previous message's draft", %{conn: conn} do
    first = message_fixture(%{status: :read})
    second = message_fixture(%{status: :read})
    {:ok, _} = Messages.update_message_status(second, %{admin_notes: "Second notes"})
    view = tab_view(conn, "messages")
    view |> element("#messages-#{first.id}") |> render_click()
    view |> form("#admin-notes-form", admin_notes: "First draft") |> render_change()

    target =
      render(view)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#admin-notes-form")
      |> LazyHTML.attribute("phx-target")
      |> hd()
      |> String.to_integer()

    view |> with_target(target) |> render_click("close_modal")
    view |> element("#messages-#{second.id}") |> render_click()
    assert has_element?(view, "#admin-notes", "Second notes")
    refute has_element?(view, "#admin-notes", "First draft")
  end

  test "events while another tab is active update the badge and data loads on navigation", %{
    conn: conn
  } do
    item = single_item_fixture()
    view = tab_view(conn, "clients")
    {:ok, _} = Inventory.update_item(item, %{name: "Changed on another tab"})
    message = message_fixture()
    sync(view)
    assert has_element?(view, "button[phx-value-tab=messages] span", "1")
    switch_tab(view, "inventory")
    assert has_element?(view, "#inventory-item-#{item.id}", "Changed on another tab")
    switch_tab(view, "messages")
    assert has_element?(view, "#messages-#{message.id}")
  end

  for {tab, form_id, upload_name} <- [
        {"add_item", "add-item-form", :new_item_image},
        {"edit_item", "edit-item-form", :edit_item_image}
      ] do
    @tab tab
    @form_id form_id
    @upload_name upload_name

    test "#{tab} preserves entered fields and pending uploads during inventory and message broadcasts",
         %{
           conn: conn
         } do
      item = single_item_fixture()
      {:ok, view, _} = live(conn, "/admin")

      if @tab == "edit_item" do
        send(view.pid, {:edit_item, item.id})
        render(view)
      else
        switch_tab(view, @tab)
      end

      selector = "##{@form_id}"
      view |> form(selector, item: %{"name" => "Unsaved name"}) |> render_change()

      upload =
        file_input(view, selector, @upload_name, [
          %{name: "photo.png", type: "image/png", content: @png}
        ])

      view |> form(selector) |> render_change(upload)
      {:ok, _} = Inventory.update_item(item, %{name: "Remote change"})
      message_fixture()
      sync(view)
      assert has_element?(view, "#{selector} input[name='item[name]'][value='Unsaved name']")
      assert has_element?(view, "#{selector} img[data-phx-hook='Phoenix.LiveImgPreview']")
      assert render_upload(upload, "photo.png") =~ "Unsaved name"
    end
  end

  defp tab_view(conn, tab) do
    {:ok, view, _} = live(conn, "/admin")
    switch_tab(view, tab)
    view
  end

  defp switch_tab(view, tab) do
    view
    |> element("button[phx-value-tab='#{tab}']:not([phx-target])", tab_label(tab))
    |> render_click()
  end

  defp tab_label("add_item"), do: "Add Item"
  defp tab_label(tab), do: String.capitalize(tab)

  defp next_page(view),
    do: view |> element("nav[aria-label=Pagination] button", "Next") |> render_click()

  # Allow the parent's queued send_update to run before inspecting the component.
  defp sync(view) do
    render(view)
    render(view)
  end

  defp row_ids(view, container) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("##{container} > tr")
    |> LazyHTML.attribute("id")
  end

  defp dated_message(name, seconds) do
    message_fixture(%{name: name})
    |> Ecto.Changeset.change(inserted_at: DateTime.add(~U[2026-01-01 00:00:00Z], seconds))
    |> Repo.update!()
  end

  defp pagination_total(view) do
    view
    |> element("nav[aria-label=Pagination] p span:nth-of-type(3)")
    |> render()
    |> plain_text()
  end

  defp low_stock_count(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("dl")
    |> Enum.find(fn dl -> dl |> Floki.find("dt") |> Floki.text() == "Low Stock Items" end)
    |> Floki.find("dd")
    |> Floki.text()
    |> String.trim()
  end

  defp plain_text(html), do: html |> Floki.parse_fragment!() |> Floki.text() |> String.trim()
end
