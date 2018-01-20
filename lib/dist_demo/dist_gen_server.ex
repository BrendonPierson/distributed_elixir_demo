defmodule DD.DistGenServer do
  @moduledoc """
  Module containing a macro to extend the GenServer behavior with
  defaults for interacting with Swarm

  Injects default swarm message handlers.  Optionally pass in :handoff_strategy
  Example:
    use DistGenServer, handoff_strategy: :restart
  Strategies = :restart | :resume | :ignore
    :restart will restart to restart on the new node
    :resume to pass off state to the new process on the new node
    :ignore to keep the process on the current node

  The default swarm message handlers can all be overridden:
    `beign_handoff/1`, `end_handoff/2`, `resolve_conflict/2`, `handle_death/1`
  See the default implementations for more information.
  """
  defmacro __using__(opts) do

    quote bind_quoted: [opts: opts] do
      use GenServer
      require Logger

      def options, do: unquote(opts)

      @doc """
      called when a handoff has been initiated due to changes
      in cluster topology.  Recieves process state as the one argument.
      Default is `{:resume, state}`. Valid response values are:

        - `:restart`, to simply restart the process on the new node
        - `{:resume, state}`, to hand off some state to the new process
        - `:ignore`, to leave the process running on its current node
      """
      def begin_handoff(state), do: {:resume, state}

      @doc """
      Called after the process has been restarted on its new node,
      and the old process' state is being handed off. This is only
      sent if the return to `begin_handoff` was `{:resume, state}`.
      **NOTE**: This is called *after* the process is successfully started,
      so make sure to design your processes around this caveat if you
      wish to hand off state like this. Default is to pass on the old state.
      """
      def end_handoff(old_state, _new_state), do: {:noreply, old_state}

      @doc """
      Called when a network split is healed and the local process
      should continue running, but a duplicate process on the other
      side of the split is handing off its state to us. You can choose
      to ignore the handoff state, or apply your own conflict resolution
      strategy. Default is to ignore the other state.
      """
      def resolve_conflict(my_state, _other_state), do: {:noreply, my_state}

      @doc """
      Called when this process should die because it is being moved, use this
      as an opportunity to clean up. Default deletes the pid from the local
      tracking registry before shutting down. This prevents the local supervisor
      from restarting it.
      """
      def handle_death(state) do
        DD.Registry.delete(self())
        {:stop, :shutdown, state}
      end

      def handle_call({:swarm, :begin_handoff}, _from, state) do
        strategy = Keyword.get(options(), :handoff_strategy, :resume)

        response = case strategy do
          :resume -> begin_handoff(state)
          _ -> {:reply, strategy, state}
        end

        {:reply, response, state}
      end

      def handle_cast({:swarm, :end_handoff, old_state}, new_state) do
        end_handoff(old_state, new_state)
      end

      def handle_cast({:swarm, :resolve_conflict, other_state}, my_state) do
        resolve_conflict(my_state, other_state)
      end

      def handle_info({:swarm, :die}, state), do: handle_death(state)


      defoverridable begin_handoff: 1, end_handoff: 2, resolve_conflict: 2, handle_death: 1
    end

  end
end
