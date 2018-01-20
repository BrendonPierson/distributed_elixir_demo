defmodule DD.Supervisor do
  @moduledoc """
  This is the supervisor for the worker processes you wish to distribute
  across the cluster, Swarm is primarily designed around the use case
  where you are dynamically creating many workers in response to events. It
  works with other use cases as well, but that's the ideal use case.
  """
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Registers a new worker, and creates the worker process
  """
  def register(worker_name) do
    {:ok, _pid} = Supervisor.start_child(__MODULE__, [worker_name])
  end

  def init(_) do
    children = [
      Supervisor.child_spec(DD.Worker, start: {DD.Worker, :start_link, []})
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end
end
