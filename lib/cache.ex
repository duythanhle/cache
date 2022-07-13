defmodule Cache do
  use GenServer

  @type result ::
          {:ok, any()}
          | {:error, :timeout}
          | {:error, :not_registered}

  @doc ~s"""
  Creates a new Cache server, linked to the current process.

  Arguments:
    - `opts`: Optional argument.
  """
  @spec start_link(opts :: Keyword.t()) :: {atom, pid}
  def start_link(opts \\ []) when is_list(opts) do
    GenServer.start_link(__MODULE__, [], opts ++ [name: {:global, __MODULE__}])
  end

  @doc ~s"""
  Starts a new Cache server for each `register_function` to process and store return value of `fun`

  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.
  """
  @spec start_link(fun :: (() -> {:ok, any()} | {:error, any()}),
                    ttl :: non_neg_integer(),
                    refresh_interval :: non_neg_integer()) :: {atom, pid}
  def start_link(fun, ttl, refresh_interval) do
    Process.flag(:trap_exit, true)
    GenServer.start_link(__MODULE__, [fun, ttl, refresh_interval])
  end

  @doc false
  # Basic initialization phase for a cache.
  @impl true
  def init([]) do
    Cache.Store.init()
    {:ok, %{}}
  end

  @doc false
  # Basic initialization phase for a `start_link/3`.
  @impl true
  def init([fun, ttl, refresh_interval]) do
    ref = Process.send_after(self(), :timeout, ttl)
    {:ok, %{value: nil, fun: fun, ttl: ttl, refresh_interval: refresh_interval, waiting_results: [], progress: false, ttl_ref: ref}}
  end

  @doc ~s"""
  Registers a function that will be computed periodically to update the cache.

  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.

  The value is stored only if `{:ok, value}` is returned by `fun`. If `{:error,
  reason}` is returned, the value is not stored and `fun` must be retried on
  the next run.
  """
  @spec register_function(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any,
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: :ok | {:error, :already_registered}
  def register_function(fun, key, ttl, refresh_interval)
      when is_function(fun, 0) and is_integer(ttl) and ttl > 0 and
             is_integer(refresh_interval) and refresh_interval > 0 and
             refresh_interval < ttl do
    GenServer.call({:global, __MODULE__}, {:register_function, fun, key, ttl, refresh_interval})
    catch
      # Receive :timeout
      :exit, {:timeout, _} ->
        {:error, :timeout}
      #Other error
      :exit, res ->
        {:error, res}
  end

  def register_function(_fun, _key, _ttl, _refresh_interval) do
    {:error, :unexpected_value}
  end

  @doc ~s"""
  Get the value associated with `key`.

  Details:
    - If the value for `key` is stored in the cache, the value is returned
      immediately.
    - If a recomputation of the function is in progress, the last stored value
      is returned.
    - If the value for `key` is not stored in the cache but a computation of
      the function associated with this `key` is in progress, wait up to
      `timeout` milliseconds. If the value is computed within this interval,
      the value is returned. If the computation does not finish in this
      interval, `{:error, :timeout}` is returned.
    - If `key` is not associated with any function, return `{:error,
      :not_registered}`
  """
  @spec get(any(), non_neg_integer(), Keyword.t()) :: result
  def get(key, timeout \\ 30_000, _opts \\ []) when is_integer(timeout) and timeout > 0 do
    GenServer.call({:global, __MODULE__}, {:get, key}, timeout)
    catch
      # Receive :timeout
      :exit, {:timeout, _} ->
        {:error, :timeout}
      #Other error
      :exit, res ->
        {:error, res}
  end

  def handle_call({:register_function, fun, key, ttl, refresh_interval}, _from, state) do
    reply =
      case :ets.lookup(:cache_table, key) do
        [] ->
          {:ok, pid} = Cache.start_link(fun, ttl, refresh_interval)
          GenServer.call(pid, :register)
          Cache.Store.store(key, pid)
          :ok
        _ ->
          {:error, :already_registered}
      end

    {:reply, reply, state}
  end

  def handle_call({:get, key}, from ,state) do
    case :ets.lookup(:cache_table, key) do
      [] ->
        {:reply, {:error, :not_registered}, state}
      [{_key, pid}] ->
        GenServer.cast(pid, {:get, from})
        {:noreply, state}
    end
  end

  @doc ~s"""
  Handles call messages
  """
  # Receive :register signal
  # Start a Task for process `fun`, ttl timer for ttl
  @impl true
  def handle_call(:register, _from, %{fun: fun} = state) do
    #IO.puts("#{inspect(pid)} Got register func from #{inspect(from)}")
    Task.async(fun)
    {:reply, :ok, %{state | progress: true}}
  end

  # Receives :get cast message
  # Returns {:error, :not_registered}
  @impl true
  def handle_cast({:get, from}, %{value: nil, progress: false} = state) do
    GenServer.reply(from, {:error, :not_registered})
    {:noreply, state}
  end

  # Receives :get cast message
  # Waits for computing value
  @impl true
  def handle_cast({:get, from},  %{value: nil, waiting_results: list} = state) do
    # wating result
    #IO.puts("Got get func for key #from #{inspect(from)}| wating result")
    {:noreply, %{state | waiting_results: [from | list]}}
  end

  # Receives :get cast message
  # Returns stored value
  @impl true
  def handle_cast({:get, from},  %{value: value} = state) do
    GenServer.reply(from, {:ok, value})
    {:noreply, state}
  end

  # Receive :recompute for `refresh_interval`
  # Start a Task for process `fun`
  @impl true
  def handle_info(:recompute, %{fun: fun} = state) do
    # retried
    Task.async(fun)
    {:noreply, %{state | progress: true}}
  end

  # Receives return {:ok, value} of Task
  def handle_info({_ref, {:ok, value} = result}, %{ttl: ttl, refresh_interval: refresh_interval, ttl_ref: ref} = state) do
    #IO.puts("Receive result #{inspect result}")
    # Checks waiting process to send result
    case state.waiting_results do
      [] ->
        :ok
      list_waiting_processes ->
        for from <- Enum.reverse(list_waiting_processes), do: GenServer.reply(from, result)
    end
    # Cancels and restarts ttl_ref
    Process.cancel_timer(ref)
    schedule_recompute(refresh_interval)
    {:noreply, %{state |value: value, progress: false, waiting_results: [], ttl_ref: Process.send_after(self(), :timeout, ttl)}}
  end

  # Receives return error value of Task
  def handle_info({_ref, _result}, %{refresh_interval: refresh_interval} = state) do
    schedule_recompute(refresh_interval)
    {:noreply, %{state | progress: false}}
  end

  # Receives DOWN signal of Task with reason :normal
  def handle_info({:DOWN, _ref, :process, _process, :normal}, state)  do
    #IO.puts("Task down #{inspect process}")
    {:noreply, state}
  end

  # Receives DOWN signal of Task with other reason
  def handle_info({:DOWN, _ref, :process, _process, _reason}, state)  do
    {:noreply, state}
  end

  # Receives DOWN signal of Task
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Cache.Store.delete(self())
    state
  end

  # Start a periodic timer for `refresh_interval`
  defp schedule_recompute(refresh_interval) do
    Process.send_after(self(), :recompute, refresh_interval)
  end

end

defmodule Cache.Store do

  @doc ~s"""
  Initialize a ets table to store `key` and `pid` of cache server
  """
  def init() do
    case :ets.whereis :cache_table do
      :undefined ->
        :ets.new(:cache_table, [:set, :public, :named_table, read_concurrency: true])
        :ok
      _ ->
        :ok
    end
  end

  @doc ~s"""
  Stores `key` and `pid` of cache server
  Arguments:
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `pid`: process id of of cache server
  """
  @spec store(
          key :: any,
          pid :: pid()
        ) :: :ok
  def store(key, pid) do
    :ets.insert(:cache_table, {key, pid})
    :ok
  end

  @doc ~s"""
  Gets `pid` of cache server with `key`
  Arguments:
    - `key`: associated with the function and is used to retrieve the stored
    value.
  """
  @spec get(
          key :: any
        ) :: [] | [{any,pid()}]
  def get(key) do
    :ets.lookup(:cache_table, key)
  end

  @doc ~s"""
  Delete `key` by `pid`
  Arguments:
    - `pid`: process id of of cache server
  """
  @spec delete(
          pid :: pid()
        ) :: :ok
  def delete(pid) do
    # IO.puts("Deleting #{inspect(pid)}")
    :ets.match_delete(:cache_table, {:_, pid})
    :ok
  end

end
