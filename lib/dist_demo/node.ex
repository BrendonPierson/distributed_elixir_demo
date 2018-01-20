defmodule DD.Node do
  @moduledoc """
  Module for connecting to other elixir nodes.
  Once this node is connected to other nodes, it stops looking for other nodes
  to connect to. If the other nodes go down and it is the sole node, it will
  begin looking for other nodes again.
  """
  use GenServer
  import SweetXml, only: [xpath: 2, sigil_x: 2]

  @node_prefix "aspire_server"
  @timeout 30 * 1000

  def start_link([]), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  Manually check if there are any nodes not connected to the cluster
  """
  def ensure_connected, do: GenServer.call(__MODULE__, :ensure_connected)

  @doc """
  Looks for all ec2 instances with specific tage `NodeType`=`node_type/0`
  Connects all the found nodes into a cluster.
  Monitors all nodes in the cluster in case they go down or restart.
  Returns list of nodes in newly formed cluster.
  """
  def check_cluster do
    nodes = get_nodes()
    connect_nodes(nodes)
    monitor_nodes()
    nodes
  end

  @doc """
  Retrieves all running instance internal ip addresses where the NodeType tag
  is set to `node_type/0`.
  """
  def get_nodes do
    [
      {:"filter.1.Name", "tag:NodeType"}, {:"filter.1.Value.1", node_type()},
      {:"filter.2.Name", "instance-state-code"}, {:"filter.2.Value.1", 16},
    ]
    |> ExAws.EC2.describe_instances
    |> ExAws.request!
    |> parse_response
    |> Enum.map(&format_node_name/1)
  end

  @doc """
  Connects a list of atom node names forming a clusters, returns node names
  """
  def connect_nodes(nodes), do: Enum.each(nodes, &Node.connect/1)

  @doc """
  Monitors all nodes currently connected in the cluster
  """
  def monitor_nodes, do: :net_kernel.monitor_nodes(true)

  @doc false
  def node_type, do: Application.get_env(:aspire_distributed, :node_type)

  @doc false
  def parse_response(%{body: body}) do
    body
    |> xpath(~x"//reservationSet/item/instancesSet/item/privateIpAddress/text()"l)
  end

  @doc """
  Taks a character list ip address and turns it into a formatted node atom
  """
  def format_node_name(ip), do: String.to_atom("#{@node_prefix}@#{to_string(ip)}")

  # callbacks
  def init([]), do: {:ok, %MapSet{}, 100}

  @doc """
  Called 100ms after startup to give :hackney time to start.
  attempts to find and connect to nodes only if no nodes are currently connected.
  """
  def handle_info(:timeout, _) do
    live_nodes = check_cluster() |> MapSet.new

    if MapSet.size(live_nodes) == 0, do: Process.send_after(self(), :timeout, @timeout)

    {:noreply, live_nodes}
  end

  def handle_info({:nodedown, dead_node}, nodes) do
    Process.send(self(), :timeout, [])
    {:noreply, MapSet.delete(nodes, dead_node)}
  end

  def handle_info({:nodeup, new_node}, nodes) do
    {:noreply, MapSet.put(nodes, new_node)}
  end

  def handle_call(:ensure_connected, _, _) do
    live_nodes = check_cluster() |> MapSet.new
    {:reply, :ok, live_nodes}
  end

  def handle_call(:monitor, _, state) do
    monitor_nodes()
    {:reply, :ok, state}
  end
end
