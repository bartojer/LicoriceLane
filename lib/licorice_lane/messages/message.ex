defmodule LicoriceLane.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :name, :string
    field :email, LicoriceLane.Encrypted.Binary
    field :phone, LicoriceLane.Encrypted.Binary
    field :message, LicoriceLane.Encrypted.Binary
    field :email_hash, Cloak.Ecto.SHA256
    field :phone_hash, Cloak.Ecto.SHA256
    field :status, Ecto.Enum, values: [:new, :read, :archived], default: :new
    field :admin_notes, :string
    field :honeypot, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:name, :email, :phone, :message, :honeypot])
    |> validate_required([:name, :email, :message])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "has invalid format")
    |> validate_honeypot()
    |> force_change(:status, :new)
    |> put_hashed_fields()
  end

  @doc false
  def admin_changeset(message, attrs) do
    message
    |> cast(attrs, [:status, :admin_notes])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:new, :read, :archived])
  end

  defp validate_honeypot(changeset) do
    honeypot = get_field(changeset, :honeypot)

    if honeypot && honeypot != "" do
      add_error(changeset, :honeypot, "must be empty")
    else
      changeset
    end
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:email, :email_hash)
    |> maybe_put_hash(:phone, :phone_hash)
  end

  defp maybe_put_hash(changeset, source_field, hash_field) do
    value =
      case fetch_change(changeset, source_field) do
        {:ok, val} when not is_nil(val) and val != "" ->
          val

        _ ->
          case changeset.data do
            %{__meta__: %{state: :loaded}} -> Map.get(changeset.data, source_field)
            _ -> nil
          end
      end

    if value && value != "" do
      force_change(changeset, hash_field, value)
    else
      changeset
    end
  end
end
