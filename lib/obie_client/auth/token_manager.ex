defmodule ObieClient.Auth.TokenManager do
  @moduledoc """
  OAuth2 client-credentials token manager.

  Caches the access token in a `GenServer` and auto-refreshes it when
  within 30 seconds of expiry. All callers share one cached token.
  Uses `private_key_jwt` (`client_assertion`) as required by OBIE/FAPI.
  """

  use GenServer

  alias ObieClient.Auth.JWT
  alias ObieClient.Config

  @expiry_buffer_sec 30

  # Dialyzer: fetch/1 and post_token/2 are called only through handle_call/3
  # which dialyzer cannot trace through the JWT signing chain.
  @dialyzer {:nowarn_function, [fetch: 1, post_token: 2]}

  @opaque t :: pid()

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Starts the token manager (unsupervised — owned by `ObieClient.Client`)."
  @spec start_link(ObieClient.Config.t()) :: {:ok, t()} | {:error, term()}
  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc "Returns a valid access token, fetching one if necessary."
  @spec access_token(t()) :: {:ok, String.t()} | {:error, term()}
  def access_token(pid), do: GenServer.call(pid, :access_token, 15_000)

  @doc "Clears the cached token, forcing a fresh fetch on the next call."
  @spec invalidate(t()) :: :ok
  def invalidate(pid), do: GenServer.cast(pid, :invalidate)

  # ── GenServer callbacks ─────────────────────────────────────────────────

  @impl true
  def init(%Config{} = config),
    do: {:ok, %{config: config, token: nil, expires_at: 0}}

  @impl true
  def handle_call(:access_token, _from, state) do
    if token_valid?(state) do
      {:reply, {:ok, state.token}, state}
    else
      case fetch(state.config) do
        {:ok, token, expires_at} ->
          {:reply, {:ok, token}, %{state | token: token, expires_at: expires_at}}

        {:error, _} = err ->
          {:reply, err, state}
      end
    end
  end

  @impl true
  # Dialyzer success typing: @spec handle_cast(:invalidate, %{expires_at:_, token:_, _=>_})
  def handle_cast(:invalidate, state),
    do: {:noreply, %{state | token: nil, expires_at: 0}}

  # ── Private ─────────────────────────────────────────────────────────────

  defp token_valid?(%{token: nil}), do: false

  defp token_valid?(%{expires_at: exp}),
    do: System.system_time(:second) < exp - @expiry_buffer_sec

  defp fetch(%Config{} = cfg) do
    with {:ok, assertion} <- JWT.client_assertion(cfg),
         {:ok, body} <- post_token(cfg, assertion) do
      expires_at = System.system_time(:second) + (body["expires_in"] || 3_600)
      {:ok, body["access_token"], expires_at}
    end
  end

  defp post_token(%Config{} = cfg, assertion) do
    form =
      URI.encode_query(%{
        "grant_type" => "client_credentials",
        "client_assertion_type" => "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_assertion" => assertion,
        "scope" => Enum.join(cfg.scopes, " ")
      })

    case Req.post(cfg.token_url,
           body: form,
           headers: [{"content-type", "application/x-www-form-urlencoded"}],
           receive_timeout: cfg.timeout
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: bin}} when is_binary(bin) ->
        case Jason.decode(bin) do
          {:ok, map} -> {:ok, map}
          {:error, _} -> {:error, {:token_decode_error, bin}}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:token_request_failed, status, body}}

      {:error, err} ->
        {:error, {:token_transport_error, err}}
    end
  end
end
