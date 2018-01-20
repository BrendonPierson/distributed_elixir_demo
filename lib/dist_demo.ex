defmodule DD do
  @moduledoc """
  Simple GenServer to demonstrate monitoring elixir nodes
  """
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  Start monitoring all the nodes in the cluster.
  """
  def monitor_nodes, do: GenServer.call(__MODULE__, :monitor_cluster)

  def init(_), do: {:ok, []}

  def handle_call(:monitor_cluster, _, state) do
    :net_kernel.monitor_nodes(true)
    {:reply, :ok, state}
  end

  def handle_info({:nodedown, node}, state) do
    IO.puts("Node has gone down: #{node}")
    {:noreply, state}
  end

  def handle_info({:nodeup, node}, state) do
    IO.puts("Node is up: #{node}")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

end
