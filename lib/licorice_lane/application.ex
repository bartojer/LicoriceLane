defmodule LicoriceLane.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Cachex.Spec

  @impl true
  def start(_type, _args) do
    children = [
      LicoriceLaneWeb.Telemetry,
      LicoriceLane.Repo,
      LicoriceLane.Vault,
      {DNSCluster, query: Application.get_env(:licorice_lane, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LicoriceLane.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LicoriceLane.Finch},
      # Start Cachex for admin data caching (5 min TTL, cleanup every 30 sec)
      {Cachex,
       name: :admin_cache,
       expiration:
         Cachex.Spec.expiration(
           default: :timer.minutes(5),
           interval: :timer.seconds(30)
         )},
      # Start a worker by calling: LicoriceLane.Worker.start_link(arg)
      # {LicoriceLane.Worker, arg},
      # Start to serve requests, typically the last entry
      LicoriceLaneWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LicoriceLane.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LicoriceLaneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
