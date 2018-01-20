defmodule DD.Child do
  @moduledoc """
  Module used to starting a distributed GenServer with Swarm.

  The `register/1` functions is used to start the child, and pass the pid to
  the supervisor to monitor
  """
  @enforce_keys [:name, :start]
  defstruct name: nil, group: nil, start: nil, restart: :permanent
  alias DD.Supervisor
  @max_start_attempts 3
  @delay 250

  @doc """
  Create a default child spec for a singlton process with a start_link
  """
  def new(module, args \\ []) do
    %__MODULE__{
      name: module,
      start: {module, :start_link, args}
    }
  end

  @doc """
  Calls a GenServer that has a distributed child spec as state to start that
  distributed child spec.
  """
  def register(%__MODULE__{} = child) do
    {:ok, pid} = attempt_start(child.start)
    Supervisor.monitor(pid, child)
    {:ok, pid}
  end

  @doc """
  Attempts to start a process. Takes one argument a MFA tuple.
  Start will be attempted @max_start_attempts with increasing delay
  """
  def attempt_start(start), do: attempt_start(start, 0)
  def attempt_start(_, @max_start_attempts), do: :error
  def attempt_start({mod, fun, args} = start, attempt_number) do
    backoff(attempt_number)

    with {:ok, pid} <- apply(mod, fun, args) do
      {:ok, pid}
    else
      e -> IO.puts("Failed attempt: #{attempt_number}")
        IO.inspect(e)
        attempt_start(start, attempt_number + 1)
    end
  end

  @doc """
  Exponential backoff with jitter
  https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
  """
  def backoff(0), do: nil
  def backoff(attempt_number) do
    :rand.uniform() * @delay * :math.pow(2, attempt_number)
    |> round
    |> Process.sleep
  end

end
