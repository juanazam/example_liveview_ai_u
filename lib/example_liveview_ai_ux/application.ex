defmodule ExampleLiveviewAiUx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExampleLiveviewAiUxWeb.Telemetry,
      ExampleLiveviewAiUx.Repo,
      {DNSCluster, query: Application.get_env(:example_liveview_ai_ux, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExampleLiveviewAiUx.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ExampleLiveviewAiUx.Finch},
      # Start a worker by calling: ExampleLiveviewAiUx.Worker.start_link(arg)
      # {ExampleLiveviewAiUx.Worker, arg},
      # Start to serve requests, typically the last entry
      ExampleLiveviewAiUxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExampleLiveviewAiUx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExampleLiveviewAiUxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
