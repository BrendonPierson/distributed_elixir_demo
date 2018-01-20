defmodule DD.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: __MODULE__]

    children = [
      DD.Supervisor,
      DD.Registry,
      DD,
    ]

    if Application.get_env(:dist_demo, :should_connect_nodes) do
      [DD.Node | children]
    else
      children
    end
    |> Supervisor.start_link(opts)
  end
end
