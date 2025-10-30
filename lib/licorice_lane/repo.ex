defmodule LicoriceLane.Repo do
  use Ecto.Repo,
    otp_app: :licorice_lane,
    adapter: Ecto.Adapters.Postgres
end
