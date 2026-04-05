defmodule ObieClient.RateLimiter do
  @moduledoc """
  Token-bucket rate limiter — one bucket per `client_id`, stored in ETS.

  Default: 50-request burst, refill at 10 requests/second.
  The limiter is checked automatically by `ObieClient.Client` before every request.
  """

  @table :obie_rate_limiter
  @capacity 50
  # tokens per second
  @refill_rate 10

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Returns `:ok` if a token is available, `{:error, :rate_limited}` otherwise."
  @spec check(String.t()) :: :ok | {:error, :rate_limited}
  def check(client_id) do
    now = System.monotonic_time(:millisecond)

    {tokens, last_refill} =
      case :ets.lookup(@table, client_id) do
        [{_, t, ts}] -> {t, ts}
        [] -> {@capacity * 1.0, now}
      end

    elapsed_s = (now - last_refill) / 1_000
    refilled = min(tokens + elapsed_s * @refill_rate, @capacity * 1.0)

    if refilled >= 1.0 do
      :ets.insert(@table, {client_id, refilled - 1.0, now})
      :ok
    else
      {:error, :rate_limited}
    end
  end

  @doc "Returns approximate available tokens (float)."
  @spec available(String.t()) :: float()
  def available(client_id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, client_id) do
      [{_, tokens, last_refill}] ->
        elapsed_s = (now - last_refill) / 1_000
        min(tokens + elapsed_s * @refill_rate, @capacity * 1.0)

      [] ->
        @capacity * 1.0
    end
  end

  @doc "Resets the bucket to full capacity."
  @spec reset(String.t()) :: :ok
  def reset(client_id) do
    :ets.delete(@table, client_id)
    :ok
  end

  # ── Supervisor (owns ETS table) ──────────────────────────────────────────

  defmodule Supervisor do
    @moduledoc false
    use GenServer

    @doc false
    @spec start_link(term()) :: GenServer.on_start()
    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    @doc false
    @spec init(term()) :: {:ok, %{}}
    @impl true
    def init(_) do
      :ets.new(:obie_rate_limiter, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

      {:ok, %{}}
    end
  end
end
