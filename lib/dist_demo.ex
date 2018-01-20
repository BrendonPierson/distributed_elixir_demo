defmodule DD do
  @moduledoc """
  This module contains the main public api for starting child processes that
  should be distributed using `Swarm`
  """
  use GenServer
  require Logger
  alias DD.{Child}

  def start_link([]) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Same as `start_child/1` except it is performed asyncronously by casting a
  message to the module's server to start the process.
  """
  def start_child_async(%Child{} = child) do
    GenServer.cast(__MODULE__, {:start_child, child})
  end

  @doc """
  Starts worker and registers name in the cluster, then joins the process
  to group a group if one is provided
  """
  def start_child(%Child{name: name, group: group} = child) do
    case Swarm.register_name(name, Child, :register, [child]) do
      {:ok, pid} -> join(group, pid)
      {:error, {:already_registered, pid}} -> join(group, pid)

      err -> Logger.error("Failed to start child.")
        IO.inspect(err)
        {:error, "Failed to start child"}
    end
  end

  @doc """
  Joins a child process to a swarm group if there is a group specified in the spec
  """
  def join(nil, pid), do: {:ok, pid}
  def join(group, pid), do: {Swarm.join(group, pid), pid}

  @doc """
  Gets the pid of the worker with the given name
  """
  def get_worker(name), do: Swarm.whereis_name(name)

  @doc """
  Gets a list of all {name, pids} registered
  """
  def get_all, do: Swarm.registered()

  @doc """
  Gets all of the pids that are members of a group
  """
  def get_members(group), do: Swarm.members(group)

  @doc """
  Call some worker by name
  """
  def call_child(name, msg), do: GenServer.call({:via, :swarm, name}, msg)

  @doc """
  Cast to some worker by name
  """
  def cast_child(name, msg), do: GenServer.cast({:via, :swarm, name}, msg)

  @doc """
  Publish a message to all members of a group
  """
  def publish_group(group, msg), do: Swarm.publish(group, msg)

  @doc """
  Call all members of a group and collect the results,
  any failures or nil values are filtered out of the result list
  """
  def call_group(group, msg), do: Swarm.multi_call(group, msg)

  # callbacks
  def init, do: {:ok, []}

  def handle_cast({:start_child, %Child{} = child}, _) do
    start_child(child)
    {:noreply, []}
  end
end
