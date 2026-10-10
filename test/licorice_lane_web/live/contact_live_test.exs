defmodule LicoriceLaneWeb.ContactLiveTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.MessagesFixtures
  alias LicoriceLane.Messages

  test "renders the contact form and other contact information", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/contact")

    for text <- [
          "Contact Us",
          "Send us a message",
          "Other Ways to Reach Us",
          "Phone:",
          "Email:",
          "Address:"
        ] do
      assert html =~ text
    end

    assert has_element?(view, "form#contact_form")

    for field <- [:name, :email, :phone] do
      assert has_element?(view, "input[name='message[#{field}]']")
    end

    assert has_element?(view, "textarea[name='message[message]']")
  end

  test "change validation displays field errors without saving", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/contact")
    view |> form("#contact_form", message: %{name: "", email: "", message: ""}) |> render_change()

    for field <- [:name, :email, :message] do
      assert has_element?(view, "#message_#{field} ~ p", "can't be blank")
    end

    view
    |> form("#contact_form",
      message: %{name: "Test User", email: "invalid-email", message: "Test message"}
    )
    |> render_change()

    assert has_element?(view, "#message_email ~ p", "has invalid format")
    refute has_element?(view, "#message_name ~ p")
    refute has_element?(view, "#message_message ~ p")
    assert Messages.list_messages() == []
  end

  for phone <- [nil, "555-1234"] do
    @phone phone
    test "successful submission with phone #{inspect(phone)} persists data, flashes and clears every field",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      attrs = valid_message_attributes(%{phone: @phone})
      form_attrs = if @phone, do: attrs, else: Map.delete(attrs, :phone)

      result = view |> form("#contact_form", message: form_attrs) |> render_submit()
      assert_redirected(view, ~p"/contact")
      assert [message] = Messages.list_messages()
      assert Map.take(message, [:name, :email, :phone, :message]) == attrs
      assert message.status == :new

      {:ok, new_view, html} = follow_redirect(result, conn, ~p"/contact")
      assert html =~ "Thank you for your message"
      assert has_element?(new_view, "form#contact_form")

      for field <- [:name, :email, :phone, :honeypot] do
        assert has_element?(new_view, "input#message_#{field}")
        refute has_element?(new_view, "#message_#{field}[value]:not([value=''])")
      end

      assert new_view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#message_message")
             |> Floki.text() == ""
    end
  end

  test "invalid submission shows specific errors, retains entered values and never persists", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/contact")

    view
    |> form("#contact_form", message: %{email: "test@example.com", message: "Test message"})
    |> render_submit()

    assert has_element?(view, "#contact_form", "Oops, something went wrong")
    assert has_element?(view, "#message_name ~ p", "can't be blank")
    assert has_element?(view, "#message_email[value='test@example.com']")
    assert has_element?(view, "#message_message", "Test message")
    assert Messages.list_messages() == []
  end

  test "honeypot submissions give ordinary success feedback without persistence", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/contact")
    attrs = valid_message_attributes(%{honeypot: "Synthetic spam"})
    result = view |> form("#contact_form", message: attrs) |> render_submit()
    assert_redirected(view, ~p"/contact")
    {:ok, _new_view, html} = follow_redirect(result, conn, ~p"/contact")
    assert html =~ "Thank you for your message"
    assert Messages.list_messages() == []
  end
end
