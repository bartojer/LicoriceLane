defmodule LicoriceLane.MessagesTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.Messages
  alias LicoriceLane.Messages.Message

  import LicoriceLane.MessagesFixtures

  describe "list_messages/0" do
    test "returns all messages ordered by most recent first" do
      # Deliberately assign times out of insertion order to exercise the query's ordering.
      [msg2, msg1, msg3] =
        for timestamp <- [
              ~U[2026-01-02 00:00:00Z],
              ~U[2026-01-01 00:00:00Z],
              ~U[2026-01-03 00:00:00Z]
            ] do
          message_fixture()
          |> Ecto.Changeset.change(inserted_at: timestamp)
          |> Repo.update!()
        end

      messages = Messages.list_messages()

      assert length(messages) == 3
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

      assert [found] = Messages.list_messages_by_status(:new)
      assert found.id == new_msg.id
      assert [found] = Messages.list_messages_by_status(:read)
      assert found.id == read_msg.id
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

  describe "get_message/1 and get_message!/1" do
    test "return the message with given id" do
      message = message_fixture()

      for fetched <- [Messages.get_message(message.id), Messages.get_message!(message.id)] do
        assert fetched.id == message.id
        assert fetched.name == message.name
      end
    end

    test "return nil or raise Ecto.NoResultsError when message does not exist" do
      assert Messages.get_message(999_999) == nil

      assert_raise Ecto.NoResultsError, fn ->
        Messages.get_message!(999_999)
      end
    end
  end

  describe "create_message/1" do
    test "validates required fields" do
      assert {:error, %Ecto.Changeset{} = changeset} = Messages.create_message(%{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).message
      assert Messages.list_messages() == []
    end

    test "validates email format" do
      invalid_attrs = valid_message_attributes(%{email: "not-an-email"})

      assert {:error, changeset} = Messages.create_message(invalid_attrs)
      assert "has invalid format" in errors_on(changeset).email
      assert Messages.list_messages() == []
    end

    test "rejects honeypot submissions without persistence" do
      attrs = valid_message_attributes(%{honeypot: "Synthetic spam"})
      assert {:error, changeset} = Messages.create_message(attrs)
      assert "must be empty" in errors_on(changeset).honeypot
      assert Messages.list_messages() == []
    end

    test "creates valid messages with default new status, encrypted fields and SHA256 hashes" do
      attrs = valid_message_attributes(%{phone: "555-1234"})
      assert {:ok, %Message{} = message} = Messages.create_message(attrs)
      assert Map.take(message, [:name, :email, :phone, :message]) == attrs
      assert message.status == :new
      reloaded = Messages.get_message!(message.id)
      assert Map.take(reloaded, [:name, :email, :phone, :message]) == attrs

      %{rows: [[name, email, phone, body, email_hash, phone_hash]]} =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT name, email, phone, message, email_hash, phone_hash FROM messages WHERE id = $1",
          [message.id]
        )

      assert name == attrs.name

      assert Enum.all?(
               Enum.zip([email, phone, body], [attrs.email, attrs.phone, attrs.message]),
               fn
                 {stored, plain} -> is_binary(stored) and stored != plain
               end
             )

      assert email_hash == :crypto.hash(:sha256, attrs.email)
      assert phone_hash == :crypto.hash(:sha256, attrs.phone)
    end
  end

  describe "update_message_status/2" do
    test "persists status, notes, or both while preserving other fields" do
      for attrs <- [
            %{status: :read},
            %{admin_notes: "Contacted customer"},
            %{status: :archived, admin_notes: "Issue resolved"}
          ] do
        message = message_fixture()
        assert {:ok, updated} = Messages.update_message_status(message, attrs)
        expected = Map.merge(Map.take(message, [:status, :admin_notes]), attrs)
        assert Map.take(updated, [:status, :admin_notes]) == expected
        assert Map.take(Messages.get_message!(message.id), [:status, :admin_notes]) == expected
        assert updated.email == message.email
        assert updated.phone == message.phone
        assert updated.message == message.message
      end
    end

    test "rejects invalid status and ignores public fields in admin updates" do
      message = message_fixture()
      assert {:error, changeset} = Messages.update_message_status(message, %{status: :unknown})
      assert "is invalid" in errors_on(changeset).status
      assert Messages.get_message!(message.id).status == :new

      assert {:ok, updated} =
               Messages.update_message_status(message, %{
                 status: :read,
                 email: "changed@example.com"
               })

      assert updated.email == message.email
      assert updated.status == :read
    end
  end

  describe "mark_as_read/1, mark_as_archived/1 and mark_as_new/1" do
    test "persist each status transition and restore archived messages to the unread count" do
      message = message_fixture()
      assert {:ok, read} = Messages.mark_as_read(message)
      assert read.status == :read
      assert Messages.get_message!(message.id).status == :read
      assert {:ok, archived} = Messages.mark_as_archived(message)
      assert archived.status == :archived
      assert Messages.get_message!(message.id).status == :archived
      assert Messages.count_new_messages() == 0
      assert {:ok, unread} = Messages.mark_as_new(archived)
      assert unread.status == :new
      assert Messages.get_message!(message.id).status == :new
      assert Messages.count_new_messages() == 1
    end
  end

  describe "search_messages_by_name/1" do
    test "matches partial names case-insensitively without searching encrypted fields" do
      matching = message_fixture(%{name: "Synthetic Sender"})
      message_fixture(%{name: "Other", email: "synthetic@example.com", message: "synthetic"})
      assert [found] = Messages.search_messages_by_name("tHeTiC")
      assert found.id == matching.id
      assert Messages.search_messages_by_name("no match") == []
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
      message = %Message{status: :new}

      attrs = %{status: :archived, admin_notes: "Admin note"}
      changeset = Message.admin_changeset(message, attrs)

      assert changeset.changes.status == :archived
      assert changeset.changes.admin_notes == "Admin note"
    end
  end
end
