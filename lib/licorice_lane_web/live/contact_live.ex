defmodule LicoriceLaneWeb.ContactLive do
  use LicoriceLaneWeb, :live_view

  alias LicoriceLane.Messages
  alias LicoriceLane.Messages.Message

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <.header class="text-center mb-8">
        Contact Us
        <:subtitle>
          Have a question or want to discuss your event? Send us a message and we'll get back to you soon.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="contact_form"
        phx-submit="save"
        phx-change="validate"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:phone]} type="text" label="Phone (optional)" />
        <.input field={@form[:message]} type="textarea" label="Message" required rows="6" />

        <!-- Honeypot field - hidden from users, should remain empty -->
        <div class="hidden">
          <.input field={@form[:honeypot]} type="text" label="Leave this field blank" />
        </div>

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">Send Message</.button>
        </:actions>
      </.simple_form>

      <div class="mt-8 p-6 bg-gray-50 rounded-lg">
        <h3 class="text-lg font-semibold mb-4">Other Ways to Reach Us</h3>
        <div class="space-y-2 text-gray-600">
          <p><strong>Phone:</strong> (555) 123-4567</p>
          <p><strong>Email:</strong> info@licorice-lane.com</p>
          <p><strong>Address:</strong> 123 Sweet Street, Candy Town, CT 12345</p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Messages.change_message(%Message{})

    socket =
      socket
      |> assign(check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"message" => message_params}, socket) do
    case Messages.create_message(message_params) do
      {:ok, _message} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thank you for your message! We'll get back to you soon.")
         |> push_navigate(to: ~p"/contact")}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Check if honeypot was filled (spam detection)
        if Keyword.has_key?(changeset.errors, :honeypot) do
          # Silent failure for spam - don't give feedback
          {:noreply,
           socket
           |> put_flash(:info, "Thank you for your message! We'll get back to you soon.")
           |> push_navigate(to: ~p"/contact")}
        else
          {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
        end
    end
  end

  def handle_event("validate", %{"message" => message_params}, socket) do
    changeset =
      %Message{}
      |> Messages.change_message(message_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "message")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
