defmodule ObieClient.Cache do
  @moduledoc """
  ETS-backed TTL cache for tokens, consents, and other short-lived data.

  The GenServer owns the ETS table and runs a periodic eviction sweep
  every 60 seconds.

  ## Usage

      # Store for 5 minutes
      ObieClient.Cache.put("consent:\#{id}\", data, 5 * 60 * 1_000)

      # Retrieve
      case ObieClient.Cache.get("consent:\#{id}\") do
        {:ok, data} -> data
        :miss       -> fetch_from_aspsp()
      end

      # Fetch-or-compute pattern
      data = ObieClient.Cache.get_or_put("consent:\#{id}\", 5 * 60 * 1_000, fn ->
        {:ok, c} = ObieClient.AISP.Consent.get(client, id)
        c
      end)
  """

  use GenServer

  @table :obie_cache
  @eviction_interval_ms 60_000

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Stores `value` under `key` with a TTL in milliseconds."
  @spec put(term(), term(), non_neg_integer()) :: :ok
  def put(key, value, ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {key, value, expires_at})
    :ok
  end

  @doc "Returns `{:ok, value}` if found and not expired, `:miss` otherwise."
  @spec get(term()) :: {:ok, term()} | :miss
  def get(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{_, value, expires_at}] when expires_at > now -> {:ok, value}
      _ -> :miss
    end
  end

  @doc "Returns the cached value or calls `fun` to compute and cache it."
  @spec get_or_put(term(), non_neg_integer(), (-> term())) :: term()
  def get_or_put(key, ttl_ms, fun) do
    case get(key) do
      {:ok, value} ->
        value

      :miss ->
        value = fun.()
        put(key, value, ttl_ms)
        value
    end
  end

  @doc "Removes a key."
  @spec delete(term()) :: :ok
  def delete(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc "Deletes all string keys with the given prefix. Returns count deleted."
  @spec invalidate_prefix(String.t()) :: non_neg_integer()
  def invalidate_prefix(prefix) when is_binary(prefix) do
    all_keys = :ets.select(@table, [{{:"$1", :_, :_}, [], [:"$1"]}])

    Enum.count(all_keys, fn key ->
      is_binary(key) and String.starts_with?(key, prefix) and
        :ets.delete(@table, key) == true
    end)
  end

  @doc "Clears all entries."
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  # ── GenServer ────────────────────────────────────────────────────────────

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc false
  @spec init(term()) :: {:ok, %{}}
  @impl true
  def init(_) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_eviction()
    {:ok, %{}}
  end

  @doc false
  @spec handle_info(atom(), map()) :: {:noreply, map()}
  @impl true
  def handle_info(:evict, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_eviction()
    {:noreply, state}
  end

  defp schedule_eviction,
    do: Process.send_after(self(), :evict, @eviction_interval_ms)
end
