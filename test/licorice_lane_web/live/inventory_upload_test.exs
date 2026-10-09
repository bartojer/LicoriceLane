defmodule LicoriceLaneWeb.InventoryUploadTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.LocationsFixtures
  import LicoriceLane.ItemsFixtures
  import ExUnit.CaptureLog

  alias LicoriceLane.{Inventory, Repo}
  alias LicoriceLane.Items.Item

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlS8AAAAASUVORK5CYII="
       )

  setup %{conn: conn} do
    directory = Path.join(System.tmp_dir!(), "licorice-lane-upload-test-#{Ecto.UUID.generate()}")
    File.mkdir_p!(directory)
    previous = Application.get_env(:licorice_lane, :inventory_upload_directory)
    Application.put_env(:licorice_lane, :inventory_upload_directory, directory)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:licorice_lane, :inventory_upload_directory, previous),
        else: Application.delete_env(:licorice_lane, :inventory_upload_directory)

      # Only remove this test's generated directory under the system temporary root.
      assert Path.dirname(directory) == System.tmp_dir!()
      File.rm_rf!(directory)
    end)

    %{
      conn: log_in_user(conn, admin_user_fixture()),
      warehouse: warehouse_fixture(),
      directory: directory
    }
  end

  defp add_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=add_item]", "Add Item") |> render_click()
    view
  end

  defp select_image(view, selector \\ "#add-item-form", name \\ :new_item_image) do
    upload =
      file_input(view, selector, name, [%{name: "photo.png", type: "image/png", content: @png}])

    view |> form(selector) |> render_change(upload)
    upload
  end

  defp params(warehouse, overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "Upload test",
        "description" => "Synthetic item",
        "item_type" => "single",
        "category" => "candle",
        "location_id" => to_string(warehouse.id),
        "condition" => "New",
        "status" => "available"
      },
      overrides
    )
  end

  defp assert_stored(conn, item, directory) do
    assert item.image_path =~ ~r|^/uploads/[0-9a-f-]{36}\.png$|
    assert File.read!(Path.join(directory, Path.basename(item.image_path))) == @png
    response = get(conn, item.image_path)
    assert response.status == 200
    assert response.resp_body == @png
  end

  test "selection keeps the input mounted; successful creation persists and serves its thumbnail",
       context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    upload = select_image(view)
    assert has_element?(view, "#add-item-form input[type=file]")
    assert has_element?(view, "#add-item-form img[data-phx-hook='Phoenix.LiveImgPreview']")
    render_upload(upload, "photo.png")
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    item = Repo.one!(Item)
    assert_stored(conn, item, directory)
    assert has_element?(view, "img[src='#{item.image_path}']")
  end

  test "validation failures retain the upload and clean copied images before a corrected retry",
       context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    upload = select_image(view)
    render_upload(upload, "photo.png")

    html =
      view |> form("#add-item-form", item: params(warehouse, %{"name" => ""})) |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert Repo.aggregate(Item, :count) == 0
    assert File.ls!(directory) == []
    assert has_element?(view, "#add-item-form img[data-phx-hook='Phoenix.LiveImgPreview']")
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert_stored(conn, Repo.one!(Item), directory)
    assert length(File.ls!(directory)) == 1
  end

  test "invalid single-item details retain the upload without creating an item", context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    upload = select_image(view)
    render_upload(upload, "photo.png")

    view
    |> form("#add-item-form", item: params(warehouse, %{"condition" => ""}))
    |> render_submit()

    assert Repo.aggregate(Item, :count) == 0
    assert File.ls!(directory) == []
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert_stored(conn, Repo.one!(Item), directory)
  end

  test "bulk quantity error can be corrected without reselecting the image", context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    view |> element("input[value=bulk][name=item_type_selector]") |> render_click()
    upload = select_image(view)
    render_upload(upload, "photo.png")
    bulk = params(warehouse, %{"item_type" => "bulk", "quantity" => "0", "min_stock" => "10"})

    view
    |> form("#add-item-form", item: Map.drop(bulk, ["condition", "status"]))
    |> render_submit()

    assert Repo.aggregate(Item, :count) == 0
    assert File.ls!(directory) == []
    bulk = bulk |> Map.put("quantity", "3") |> Map.drop(["condition", "status"])
    view |> form("#add-item-form", item: bulk) |> render_submit()
    assert_stored(conn, Repo.one!(Item), directory)
  end

  test "component refresh preserves in-progress uploads and entered fields", %{
    conn: conn,
    warehouse: warehouse
  } do
    view = add_view(conn)
    view |> form("#add-item-form", item: params(warehouse)) |> render_change()
    upload = select_image(view)

    Phoenix.LiveView.send_update(view.pid, LicoriceLaneWeb.Admin.AddItemComponent,
      id: "add-item-component"
    )

    render(view)
    assert has_element?(view, "#add-item-form input[name='item[name]'][value='Upload test']")
    assert has_element?(view, "#add-item-form img[data-phx-hook='Phoenix.LiveImgPreview']")
    render_upload(upload, "photo.png")
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert Repo.one!(Item).image_path =~ "/uploads/"
  end

  test "a pending upload never creates an item or file", %{
    conn: conn,
    warehouse: warehouse,
    directory: directory
  } do
    view = add_view(conn)
    select_image(view)
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert Repo.aggregate(Item, :count) == 0
    assert File.ls!(directory) == []
  end

  test "cancel after rejected save leaves no image and a later save uses the placeholder",
       context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    upload = select_image(view)
    render_upload(upload, "photo.png")
    view |> form("#add-item-form", item: params(warehouse, %{"name" => ""})) |> render_submit()
    view |> element("button[phx-click=cancel-upload]") |> render_click()
    refute has_element?(view, "#add-item-form img[data-phx-hook='Phoenix.LiveImgPreview']")
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert Repo.one!(Item).image_path == "/images/placeholder.png"
    assert File.ls!(directory) == []
  end

  test "storage failure is recoverable and directory creation uses the configured path",
       context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    blocked = Path.join(directory, "blocked")
    File.write!(blocked, "not a directory")
    Application.put_env(:licorice_lane, :inventory_upload_directory, blocked)
    view = add_view(conn)
    upload = select_image(view)
    render_upload(upload, "photo.png")

    assert capture_log(fn ->
             view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
           end) =~ "Inventory image storage failed"

    assert has_element?(view, "#add-item-error", "Could not save the image. Please try again.")

    assert Repo.aggregate(Item, :count) == 0
    refute Enum.any?(File.ls!(directory), &String.ends_with?(&1, ".png"))
    target = Path.join(directory, "nested/uploads")
    Application.put_env(:licorice_lane, :inventory_upload_directory, target)
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    assert_stored(conn, Repo.one!(Item), target)
  end

  test "add and edit in one session use independent upload configurations", context do
    %{conn: conn, warehouse: warehouse, directory: directory} = context
    view = add_view(conn)
    upload = select_image(view)
    render_upload(upload, "photo.png")
    view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
    item = Repo.one!(Item)
    send(view.pid, {:edit_item, item.id})
    render(view)
    upload = select_image(view, "#edit-item-form", :edit_item_image)
    assert has_element?(view, "#edit-item-form input[type=file]")
    render_upload(upload, "photo.png")

    view
    |> form("#edit-item-form", item: %{"name" => "Edited", "condition" => "Excellent"})
    |> render_submit()

    updated = Inventory.get_item!(item.id)
    assert updated.name == "Edited"
    assert updated.single_item.condition == "Excellent"
    assert updated.image_path != item.image_path
    assert_stored(conn, updated, directory)
  end

  test "failed edit of single details rolls back its image and allows retry", context do
    %{conn: conn, directory: directory} = context
    item = single_item_fixture()
    {:ok, view, _} = live(conn, "/admin")
    send(view.pid, {:edit_item, item.id})
    render(view)
    upload = select_image(view, "#edit-item-form", :edit_item_image)
    render_upload(upload, "photo.png")

    view
    |> form("#edit-item-form", item: %{"name" => "Edited", "condition" => ""})
    |> render_submit()

    unchanged = Inventory.get_item!(item.id)
    assert unchanged.name == item.name
    assert unchanged.image_path == item.image_path
    assert File.ls!(directory) == []

    Phoenix.LiveView.send_update(view.pid, LicoriceLaneWeb.Admin.EditItemComponent,
      id: "edit-item-component",
      item_id: item.id
    )

    render(view)

    view
    |> form("#edit-item-form", item: %{"name" => "Edited", "condition" => "Excellent"})
    |> render_submit()

    assert_stored(conn, Inventory.get_item!(item.id), directory)
  end

  test "editing without an upload preserves the existing image", %{conn: conn} do
    item = bulk_item_fixture()
    {:ok, view, _} = live(conn, "/admin")
    send(view.pid, {:edit_item, item.id})
    render(view)
    view |> form("#edit-item-form", item: %{"name" => "Edited bulk"}) |> render_submit()
    assert Repo.get!(Item, item.id).image_path == item.image_path
  end

  test "switching the edited item clears an unfinished image selection", %{conn: conn} do
    first = single_item_fixture()
    second = single_item_fixture()
    {:ok, view, _} = live(conn, "/admin")
    send(view.pid, {:edit_item, first.id})
    render(view)
    select_image(view, "#edit-item-form", :edit_item_image)
    send(view.pid, {:edit_item, second.id})
    render(view)
    assert has_element?(view, "#edit-item-form input[name='item[name]'][value='#{second.name}']")
    refute has_element?(view, "#edit-item-form img[data-phx-hook='Phoenix.LiveImgPreview']")
  end

  test "unsupported files and oversized files do not create items", %{
    conn: conn,
    warehouse: warehouse,
    directory: directory
  } do
    for entry <- [
          %{name: "photo.heic", type: "image/heic", content: @png},
          %{name: "large.png", type: "image/png", content: :binary.copy(<<0>>, 10_000_001)}
        ] do
      view = add_view(conn)
      upload = file_input(view, "#add-item-form", :new_item_image, [entry])
      assert {:error, _} = render_upload(upload, entry.name)
      view |> form("#add-item-form", item: params(warehouse)) |> render_submit()
      assert Repo.aggregate(Item, :count) == 0
      assert File.ls!(directory) == []
      GenServer.stop(view.pid)
    end
  end

  @tag skip: is_nil(System.get_env("UPLOAD_BROWSER_NODE"))
  @tag :browser
  @tag timeout: 120_000
  test "browser selection, preview, transfer, failed save, and retry", %{
    conn: conn,
    directory: directory
  } do
    start_supervised!({Bandit, plug: LicoriceLaneWeb.Endpoint, ip: {127, 0, 0, 1}, port: 4002})
    user = admin_user_fixture()

    script =
      System.get_env("UPLOAD_BROWSER_SCRIPT") || Path.expand("test/browser/inventory_upload.cjs")

    {output, status} =
      System.cmd(
        System.fetch_env!("UPLOAD_BROWSER_NODE"),
        [
          script,
          user.email,
          valid_user_password(),
          System.get_env("UPLOAD_PLAYWRIGHT_MODULE") || "playwright",
          System.get_env("UPLOAD_BROWSER_EXECUTABLE") || ""
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "passed"
    assert_stored(conn, Repo.one!(Item), directory)
  end
end
