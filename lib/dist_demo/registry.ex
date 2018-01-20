defmodule DD.Registry do
  @moduledoc """
  A Module for storing processes started with Swarm locally. It contains a
  number of wrapper functions for interacting with an ets table that tracks the
  started processes. ets is used instead of genserver state because we want the
  state to persist even if this process goes down. This process should be a per
  node singleton
  """
  use GenServer
  @table :distributed_process_registry

  def start_link([]), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  Given a pid return a child stored at that pid, or nil if it doesn't exist
  """
  def get(key) do
    case :ets.lookup(@table, key) do
      [{_pid, child}] -> child
      _ -> nil
    end
  end

  @doc """
  Returns a bool if the pid is stored in the table or not
  """
  def member?(key), do: :ets.member(@table, key)

  @doc """
  Stores a child spec under a given pid key
  """
  def put(key, value), do: GenServer.call(__MODULE__, {:put, key, value})

  @doc """
  Deletes a pid and it's associated value.
  """
  def delete(key), do: GenServer.call(__MODULE__, {:delete, key})

  # Callbacks
  def init([]) do
    name = :ets.new(@table, [:set, :protected, :named_table])
    {:ok, name}
  end

  def handle_call({:put, key, value}, _from, state) do
    res = :ets.insert_new(@table, {key, value})
    {:reply, res, state}
  end

  def handle_call({:delete, key}, _from, state) do
    res = :ets.delete(@table, key)
    {:reply, res, state}
  end

  def keys(table_name \\ @table) do
    Stream.resource(
      fn -> :ets.first(table_name) end,
      fn :"$end_of_table" -> {:halt, nil}
         previous_key -> {[previous_key], :ets.next(table_name, previous_key)} end,
      fn _ -> :ok end
    )
  end

end
