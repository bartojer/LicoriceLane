defmodule LicoriceLaneWeb.AdminMessagesTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures
  import LicoriceLane.MessagesFixtures

  alias LicoriceLane.Messages

  setup %{conn: conn} do
    %{conn: log_in_user(conn, admin_user_fixture())}
  end

  test "details show the complete escaped message and status/notes actions persist only the selection",
       %{conn: conn} do
    body =
      "<script>synthetic()</script>\n" <> String.duplicate("Long message. ", 12) <> "Full ending"

    message =
      message_fixture(%{
        name: "Synthetic <b>sender</b>",
        email: "synthetic@example.com",
        phone: "555-1234",
        message: body
      })

    other = message_fixture(%{status: :archived})
    view = messages_view(conn)
    refute has_element?(view, "#messages-#{message.id}", "Full ending")
    view |> element("#messages-#{message.id}") |> render_click()
    sync(view)
    assert Messages.get_message!(message.id).status == :read

    for value <- [message.name, message.email, message.phone, "Full ending"] do
      assert has_element?(view, "#message-detail-modal", value)
    end

    refute has_element?(view, "#message-detail-modal script, #message-detail-modal b")
    assert has_element?(view, "#message-detail-modal p.whitespace-pre-wrap", "Full ending")
    assert render(view) =~ body |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    view |> form("#admin-notes-form", admin_notes: "Synthetic internal notes") |> render_change()
    assert Messages.get_message!(message.id).admin_notes == nil
    view |> element("#admin-notes") |> render_blur(%{"value" => "Synthetic internal notes"})

    for {status, label} <- [{:new, "New"}, {:read, "Read"}, {:archived, "Archived"}] do
      view
      |> element("#message-detail-modal button[phx-value-status=#{status}]")
      |> render_click()

      sync(view)
      saved = Messages.get_message!(message.id)
      assert saved.status == status
      assert saved.admin_notes == "Synthetic internal notes"
      assert saved.message == body
      assert has_element?(view, "#message-detail-modal span", label)
      assert has_element?(view, "#messages-#{message.id} span", label)
    end

    view |> element("#admin-notes") |> render_blur(%{"value" => ""})
    sync(view)
    assert Messages.get_message!(message.id).admin_notes == nil
    assert Messages.get_message!(other.id).status == :archived
    assert Messages.get_message!(other.id).admin_notes == nil

    view |> element("#messages-#{other.id}") |> render_click()
    assert has_element?(view, "#message-detail-modal span", "Archived")
    refute has_element?(view, "#message-detail-modal label", "Phone")
  end

  test "name search combines with status while changing status clears the search", %{conn: conn} do
    matching = message_fixture(%{name: "Match sender", status: :read})
    excluded = message_fixture(%{name: "Match archived", status: :archived})
    other = message_fixture(%{name: "Other sender", status: :read})
    view = messages_view(conn)
    view |> element("button[phx-click=filter_status][phx-value-status=read]") |> render_click()
    view |> form("form[phx-change=search]") |> render_change(%{"search_term" => "mAtCh"})
    assert row_ids(view) == ["messages-#{matching.id}"]
    assert has_element?(view, "button[phx-click=filter_status].bg-brand", "Read")

    view
    |> element("button[phx-click=filter_status][phx-value-status=archived]")
    |> render_click()

    assert row_ids(view) == ["messages-#{excluded.id}"]
    refute has_element?(view, "input[name=search_term][value=mAtCh]")

    view |> element("button[phx-click=filter_status][phx-value-status=all]") |> render_click()

    assert Enum.sort(row_ids(view)) ==
             Enum.sort(Enum.map([matching, excluded, other], &"messages-#{&1.id}"))
  end

  defp messages_view(conn) do
    {:ok, view, _} = live(conn, "/admin")
    view |> element("button[phx-value-tab=messages]:not([phx-target])") |> render_click()
    view
  end

  # The parent queues a component refresh in response to each broadcast.
  defp sync(view) do
    render(view)
    render(view)
  end

  defp row_ids(view) do
    render(view)
    |> LazyHTML.from_document()
    |> LazyHTML.query("#messages-list > tr")
    |> LazyHTML.attribute("id")
  end
end
