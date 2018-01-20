
defmodule DD.Supervisor do
  @moduledoc """
  This module implements a supervisor designed to monitor processes started
  with using Swarm. Under the hood it is a Genserver that manually monitors the
  processes started by Swarm, storing the monitored pids in a :ets table
  using the `Aspire.Distributed.Registry` interface.
  """
  use GenServer
  require Logger
  alias DD
  alias DD.{Child, Registry}

  def start_link([]), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  Adds the child pid to the local Registry and monitors the child so that if it
  goes down for non Swarm reasons it can be restarted.
  """
  def monitor(pid, child), do: GenServer.call(__MODULE__, {:monitor, pid, child})

  @doc """
  Removes a pid from the local Registry
  """
  def unmonitor(pid), do: Registry.delete(pid)

  @doc """
  Restarts a child. This should be used when the process dies unexpectedly on
  the current node, not because Swarm is moving it.
  """
  def restart(%Child{} = child) do
    {:ok, _new_pid} = Task.start_link(fn -> DD.start_child(child) end)
  end
  def restart(_), do: Logger.warn("Restart requires a %Child{} struct.")

  @doc """
  Determines if a process should be restarted based on the restart option in the
  in the child spec and the termination reason.
  """
  def should_restart?(_, :permanent), do: true
  def should_restart?(reason, :transient) when reason in [:normal, :shutdown], do: false
  def should_restart?(_, :transient), do: true
  def should_restart?(_, :temporary), do: false

  # Callbacks
  def init([]), do: {:ok, [], 0}

  def handle_call({:monitor, pid, child}, _from, state) do
    Process.monitor(pid)
    Process.unlink(pid)
    Registry.put(pid, child)
    {:reply, {:ok, pid}, state}
  end

  @doc """
  This is called immediately at startup. In the event that this process went
  down unexpectedly the processes it was monitoring will be stored in the local
  Registry. It will iterate over all of those processes, monitoring them, and
  making sure that they are started (just in case they went down while this
  process went down).
  """
  def handle_info(:timeout, state) do
    Registry.keys
    |> Stream.map(&Registry.get/1)
    |> Enum.each(&restart/1)

    {:noreply, state}
  end

  @doc """
  This is called when one of the processes being monitored goes down.
  """
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Registry.get(pid) do
      %{restart: restart} = child -> if should_restart?(reason, restart), do: restart(child)
      _ -> nil
    end

    unmonitor(pid)

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end

