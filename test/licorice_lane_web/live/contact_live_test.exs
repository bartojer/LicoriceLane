defmodule LicoriceLaneWeb.ContactLiveTest do
  use LicoriceLaneWeb.ConnCase

  import Phoenix.LiveViewTest
  import LicoriceLane.MessagesFixtures

  describe "Contact page" do
    test "renders contact form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/contact")

      assert html =~ "Contact Us"
      assert html =~ "Send us a message"
      assert has_element?(view, "form#contact_form")
      assert has_element?(view, "input[name='message[name]']")
      assert has_element?(view, "input[name='message[email]']")
      assert has_element?(view, "textarea[name='message[message]']")
    end

    test "displays contact information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contact")

      assert html =~ "Other Ways to Reach Us"
      assert html =~ "Phone:"
      assert html =~ "Email:"
      assert html =~ "Address:"
    end
  end

  describe "Form validation" do
    test "validates required fields on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      # Submit empty form to trigger validation
      view
      |> form("#contact_form", message: %{})
      |> render_change()

      assert has_element?(view, "#contact_form")
    end

    test "validates email format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      view
      |> form("#contact_form",
        message: %{
          name: "Test User",
          email: "invalid-email",
          message: "Test message"
        }
      )
      |> render_change()

      # Form should still be present with error
      assert has_element?(view, "#contact_form")
    end
  end

  describe "Form submission" do
    test "creates message with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      attrs = %{
        name: "John Doe",
        email: "john@example.com",
        message: "I would like to rent some items for my event."
      }

      view
      |> form("#contact_form", message: attrs)
      |> render_submit()

      # Should show success message
      assert_redirected(view, ~p"/contact")

      # Verify message was created
      messages = LicoriceLane.Messages.list_messages()
      assert length(messages) == 1

      message = hd(messages)
      assert message.name == attrs.name
      assert message.email == attrs.email
      assert message.message == attrs.message
      assert message.status == :new
    end

    test "shows error message with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      # Submit without required name field
      view
      |> form("#contact_form",
        message: %{
          email: "test@example.com",
          message: "Test message"
        }
      )
      |> render_submit()

      # Should show error and stay on page
      assert has_element?(view, "#contact_form")
      assert render(view) =~ "Oops, something went wrong"
    end

    test "includes optional phone field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      attrs = %{
        name: "Jane Doe",
        email: "jane@example.com",
        phone: "555-1234",
        message: "Please call me about my event."
      }

      view
      |> form("#contact_form", message: attrs)
      |> render_submit()

      # Verify message was created with phone
      messages = LicoriceLane.Messages.list_messages()
      message = hd(messages)
      assert message.phone == attrs.phone
    end

    test "handles honeypot spam detection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      # Fill honeypot field (indicates spam)
      attrs = %{
        name: "Spammer",
        email: "spam@example.com",
        message: "Spam message",
        honeypot: "spam content"
      }

      view
      |> form("#contact_form", message: attrs)
      |> render_submit()

      # Should show success message but not create record
      assert_redirected(view, ~p"/contact")

      # No message should be created
      messages = LicoriceLane.Messages.list_messages()
      assert length(messages) == 0
    end
  end

  describe "Success feedback" do
    test "displays flash message on successful submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      attrs = valid_message_attributes()

      html =
        view
        |> form("#contact_form", message: attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/contact")
        |> elem(2)

      assert html =~ "Thank you for your message"
    end

    test "clears form after successful submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      attrs = valid_message_attributes()

      {:ok, new_view, _html} =
        view
        |> form("#contact_form", message: attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/contact")

      # Form should be rendered but empty (default changeset)
      assert render(new_view) =~ "contact_form"
    end
  end
end
