defmodule LicoriceLane.MessagesTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.Messages
  alias LicoriceLane.Messages.Message

  import LicoriceLane.MessagesFixtures

  describe "list_messages/0" do
    test "returns all messages ordered by most recent first" do
      # Create messages at different times using inserted_at
      msg1 = message_fixture()
      # Sleep > 1 second to ensure different timestamps
      :timer.sleep(1100)
      msg2 = message_fixture()
      :timer.sleep(1100)
      msg3 = message_fixture()

      messages = Messages.list_messages()

      assert length(messages) == 3
      # Should be in reverse chronological order (newest first)
      ids = Enum.map(messages, & &1.id)
      assert ids == [msg3.id, msg2.id, msg1.id]
    end

    test "returns empty list when no messages exist" do
      assert Messages.list_messages() == []
    end
  end

  describe "list_messages_by_status/1" do
    test "returns only messages with specified status" do
      new_msg = message_fixture(%{status: :new})
      read_msg = message_fixture(%{status: :read})
      _archived = message_fixture(%{status: :archived})

      new_results = Messages.list_messages_by_status(:new)
      assert length(new_results) == 1
      assert hd(new_results).id == new_msg.id

      read_results = Messages.list_messages_by_status(:read)
      assert length(read_results) == 1
      assert hd(read_results).id == read_msg.id
    end

    test "returns empty list when no messages have the status" do
      message_fixture(%{status: :new})

      assert Messages.list_messages_by_status(:archived) == []
    end
  end

  describe "count_new_messages/0" do
    test "returns count of messages with new status" do
      message_fixture(%{status: :new})
      message_fixture(%{status: :new})
      message_fixture(%{status: :read})
      message_fixture(%{status: :archived})

      assert Messages.count_new_messages() == 2
    end

    test "returns 0 when no new messages exist" do
      message_fixture(%{status: :read})

      assert Messages.count_new_messages() == 0
    end
  end

  describe "get_message/1" do
    test "returns the message with given id" do
      message = message_fixture()

      assert fetched = Messages.get_message(message.id)
      assert fetched.id == message.id
      assert fetched.name == message.name
    end

    test "returns nil when message does not exist" do
      assert Messages.get_message(999_999) == nil
    end
  end

  describe "get_message!/1" do
    test "returns the message with given id" do
      message = message_fixture()

      assert fetched = Messages.get_message!(message.id)
      assert fetched.id == message.id
    end

    test "raises Ecto.NoResultsError when message does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Messages.get_message!(999_999)
      end
    end
  end

  describe "create_message/1" do
    test "creates a message with valid attributes" do
      valid_attrs = valid_message_attributes()

      assert {:ok, %Message{} = message} = Messages.create_message(valid_attrs)
      assert message.name == valid_attrs.name
      assert message.email == valid_attrs.email
      assert message.message == valid_attrs.message
      assert message.status == :new
    end

    test "creates message with default status of :new" do
      attrs = valid_message_attributes()

      assert {:ok, message} = Messages.create_message(attrs)
      assert message.status == :new
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_message(%{})
    end

    test "validates required fields" do
      assert {:error, changeset} = Messages.create_message(%{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).message
    end

    test "validates email format" do
      invalid_attrs = valid_message_attributes(%{email: "not-an-email"})

      assert {:error, changeset} = Messages.create_message(invalid_attrs)
      assert "has invalid format" in errors_on(changeset).email
    end
  end

  describe "update_message_status/2" do
    test "updates message status" do
      message = message_fixture(%{status: :new})

      assert {:ok, updated} = Messages.update_message_status(message, %{status: :read})
      assert updated.status == :read
    end

    test "updates admin notes" do
      message = message_fixture()

      assert {:ok, updated} =
               Messages.update_message_status(message, %{admin_notes: "Contacted customer"})

      assert updated.admin_notes == "Contacted customer"
    end

    test "can update both status and admin notes" do
      message = message_fixture(%{status: :new})

      attrs = %{status: :archived, admin_notes: "Issue resolved"}
      assert {:ok, updated} = Messages.update_message_status(message, attrs)

      assert updated.status == :archived
      assert updated.admin_notes == "Issue resolved"
    end
  end

  describe "mark_as_read/1" do
    test "changes message status to read" do
      message = message_fixture(%{status: :new})

      assert {:ok, updated} = Messages.mark_as_read(message)
      assert updated.status == :read
    end
  end

  describe "mark_as_archived/1" do
    test "changes message status to archived" do
      message = message_fixture(%{status: :new})

      assert {:ok, updated} = Messages.mark_as_archived(message)
      assert updated.status == :archived
    end
  end

  describe "delete_message/1" do
    test "deletes the message" do
      message = message_fixture()

      assert {:ok, %Message{}} = Messages.delete_message(message)
      assert Messages.get_message(message.id) == nil
    end
  end

  describe "message changesets" do
    test "public changeset only allows name, email, and message fields" do
      message = %Message{}

      # Try to set admin_notes and status through public changeset
      attrs = %{
        name: "Test",
        email: "test@example.com",
        message: "Hello",
        status: :archived,
        admin_notes: "Should not be set"
      }

      changeset = Message.changeset(message, attrs)

      # Status should be set to :new by the changeset, admin_notes should be ignored
      assert changeset.changes.status == :new
      refute Map.has_key?(changeset.changes, :admin_notes)

      # Verify email_hash is set correctly
      assert changeset.changes.email_hash == "test@example.com"
    end

    test "admin changeset allows status and admin_notes" do
      message = message_fixture()

      attrs = %{status: :archived, admin_notes: "Admin note"}
      changeset = Message.admin_changeset(message, attrs)

      assert changeset.changes.status == :archived
      assert changeset.changes.admin_notes == "Admin note"
    end
  end
end
