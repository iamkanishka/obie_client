defmodule ObieClient.CircuitBreaker do
  @moduledoc """
  ETS-backed circuit breaker (Closed → Open → HalfOpen).

  Each ASPSP connection (identified by `client_id`) gets its own circuit.
  State is stored in a named ETS table owned by `ObieClient.CircuitBreaker.Registry`.

  ## Thresholds (configurable via application config)
  - `max_failures: 5` — consecutive failures before opening
  - `open_timeout_ms: 30_000` — ms before transitioning Open → HalfOpen
  - `success_threshold: 2` — successes in HalfOpen before closing
  """

  @table :obie_circuit_breaker
  @max_failures 5
  @open_timeout_ms 30_000
  @success_threshold 2

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Returns `:ok` if a request may proceed, `{:error, :circuit_open}` otherwise."
  @spec allow(String.t()) :: :ok | {:error, :circuit_open}
  def allow(client_id) do
    case lookup(client_id) do
      nil ->
        :ok

      {:closed, _, _} ->
        :ok

      {:half_open, _, _} ->
        :ok

      {:open, _, opened_at} ->
        elapsed = System.monotonic_time(:millisecond) - opened_at

        if elapsed >= @open_timeout_ms do
          set(client_id, :half_open, 0)
          :ok
        else
          {:error, :circuit_open}
        end
    end
  end

  @doc "Records a successful response."
  @spec record_success(String.t()) :: :ok
  def record_success(client_id) do
    case lookup(client_id) do
      {:half_open, successes, _} ->
        if successes + 1 >= @success_threshold do
          :ets.delete(@table, client_id)
        else
          set(client_id, :half_open, successes + 1)
        end

      _ ->
        :ok
    end

    :ok
  end

  @doc "Records a failed response."
  @spec record_failure(String.t()) :: :ok
  def record_failure(client_id) do
    now = System.monotonic_time(:millisecond)

    case lookup(client_id) do
      nil ->
        set_with_ts(client_id, :closed, 1, 0)

      {:closed, failures, _} ->
        if failures + 1 >= @max_failures do
          set_with_ts(client_id, :open, 0, now)
        else
          set_with_ts(client_id, :closed, failures + 1, 0)
        end

      {:half_open, _, _} ->
        set_with_ts(client_id, :open, 0, now)

      _ ->
        :ok
    end

    :ok
  end

  @doc "Returns the current circuit state: `:closed`, `:open`, or `:half_open`."
  @spec state(String.t()) :: :closed | :open | :half_open
  def state(client_id) do
    case lookup(client_id) do
      nil -> :closed
      {s, _, _} -> s
    end
  end

  @doc "Manually resets the circuit to closed."
  @spec reset(String.t()) :: :ok
  def reset(client_id) do
    :ets.delete(@table, client_id)
    :ok
  end

  # ── Registry GenServer (owns the ETS table) ─────────────────────────────

  defmodule Registry do
    @moduledoc false
    use GenServer

    @doc false
    @spec start_link(term()) :: GenServer.on_start()
    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    @doc false
    @spec init(term()) :: {:ok, %{}}
    @impl true
    def init(_) do
      :ets.new(:obie_circuit_breaker, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

      {:ok, %{}}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp lookup(id) do
    case :ets.lookup(@table, id) do
      [{_, state, count, ts}] -> {state, count, ts}
      [] -> nil
    end
  end

  defp set(id, state, count),
    do: :ets.insert(@table, {id, state, count, 0})

  defp set_with_ts(id, state, count, ts),
    do: :ets.insert(@table, {id, state, count, ts})
end
