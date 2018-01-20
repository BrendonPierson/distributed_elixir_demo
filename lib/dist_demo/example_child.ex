defmodule DD.ExampleChild do
  @moduledoc """
  Example of implementing a DistGenServer for supervision with Swarm.
  """
  alias DD.DistGenServer

  # use DistGenServer can be used as a drop in replacement for use GenServer
  # The GenServer API is extended with default `Swarm` message handlers that
  # can be overridden for custon behavior ie `begin_handoff/1` below.
  use DistGenServer, handoff_strategy: :resume
  require Logger

  def start_link(name), do: GenServer.start_link(__MODULE__, name)

  # Callbacks
  def init(name) do
    Logger.debug "Initializing example child: #{name}"
    {:ok, {name, :rand.uniform(5_000)}}
  end

  # Normal GenServer callbacks can be implemented
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  # This is an example of one of the overridden swarm callbacks
  # More information in `Aspire.Distributed.DistGenServer`
  def begin_handoff(state) do
    IO.puts "----------------------------------- Custom begin handoff func ---"
    {:resume, state}
  end

end
