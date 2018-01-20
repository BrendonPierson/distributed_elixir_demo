defmodule DD.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      DD.Supervisor
    ]

    opts = [strategy: :one_for_one, name: DD.AppSupervisor]
    Supervisor.start_link(children, opts)
  end
end
