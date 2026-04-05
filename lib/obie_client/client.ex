defmodule ObieClient.Client do
  @moduledoc """
  Core OBIE HTTP client.

  Wraps `Req` and provides all mandatory FAPI headers, OAuth2 token management,
  exponential backoff with crypto-random jitter, `Retry-After` parsing,
  circuit-breaker and rate-limiter integration, JWS signature injection,
  mTLS transport setup, and telemetry emission.

  ## Creating a client

      {:ok, client} = ObieClient.new_client()
      {:ok, client} = ObieClient.Client.new(config)

  `@type t()` (not `@opaque`) so service modules can pattern-match the struct
  without generating dialyzer opaqueness-mismatch warnings.
  """

  alias ObieClient.Auth.MTLS
  alias ObieClient.Auth.TokenManager
  alias ObieClient.CircuitBreaker
  alias ObieClient.Config
  alias ObieClient.Error
  alias ObieClient.RateLimiter
  alias ObieClient.Telemetry

  @type t :: %__MODULE__{
          config: Config.t(),
          token_manager: pid()
        }

  defstruct [:config, :token_manager, :req]

  # Internal context passed between pipeline steps — avoids >8 param functions.
  defmodule RequestContext do
    @moduledoc false
    defstruct [
      :client,
      :method,
      :path,
      :body,
      :token,
      :opts,
      :attempt,
      :interaction_id
    ]
  end

  @doc "Creates a new client from a validated `ObieClient.Config`."
  @spec new(Config.t()) :: {:ok, t()} | {:error, term()}
  def new(%Config{} = config) do
    with {:ok, tm} <- TokenManager.start_link(config) do
      req =
        [base_url: config.base_url, receive_timeout: config.timeout, retry: false]
        |> Req.new()
        |> maybe_add_mtls(config)

      {:ok, %__MODULE__{config: config, token_manager: tm, req: req}}
    end
  end

  # ── HTTP verbs ───────────────────────────────────────────────────────────

  @doc false
  @spec get(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%__MODULE__{} = c, path, opts \\ []),
    do: request(c, :get, path, nil, opts)

  @doc false
  @spec post(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(%__MODULE__{} = c, path, body, opts \\ []),
    do: request(c, :post, path, body, opts)

  @doc false
  @spec put(t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def put(%__MODULE__{} = c, path, body, opts \\ []),
    do: request(c, :put, path, body, opts)

  @doc false
  @spec delete(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(%__MODULE__{} = c, path, opts \\ []) do
    case request(c, :delete, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc false
  @spec post_raw(t(), String.t(), binary(), String.t(), keyword()) ::
          {:ok, binary(), String.t()} | {:error, term()}
  def post_raw(%__MODULE__{} = c, path, body, content_type, opts \\ []),
    do: raw_request(c, :post, path, body, content_type, opts)

  @doc false
  @spec get_raw(t(), String.t(), keyword()) ::
          {:ok, binary(), String.t()} | {:error, term()}
  def get_raw(%__MODULE__{} = c, path, opts \\ []),
    do: raw_request(c, :get, path, nil, nil, opts)

  # ── Core pipeline ────────────────────────────────────────────────────────

  defp request(client, method, path, body, opts) do
    with :ok <- RateLimiter.check(client.config.client_id),
         :ok <- CircuitBreaker.allow(client.config.client_id),
         {:ok, token} <- TokenManager.access_token(client.token_manager) do
      ctx = %RequestContext{
        client: client,
        method: method,
        path: path,
        body: body,
        token: token,
        opts: opts,
        attempt: 0,
        interaction_id: Uniq.UUID.uuid4()
      }

      do_request(ctx)
    end
  end

  defp do_request(%RequestContext{} = ctx) do
    iid = ctx.interaction_id
    ikey = Keyword.get(ctx.opts, :idempotency_key, Uniq.UUID.uuid4())
    jws = Keyword.get(ctx.opts, :jws_signature)

    headers =
      base_headers(ctx.client.config, ctx.token, iid)
      |> maybe_header("x-idempotency-key", ikey)
      |> maybe_header("x-jws-signature", jws)

    req_opts = [method: ctx.method, url: ctx.path, headers: headers]
    req_opts = if ctx.body, do: Keyword.put(req_opts, :json, ctx.body), else: req_opts

    t0 = System.monotonic_time()
    Telemetry.request_start(ctx.method, ctx.path, iid)

    result = Req.request(ctx.client.req, req_opts)
    handle_response(result, ctx, System.monotonic_time() - t0)
  end

  defp handle_response({:ok, %Req.Response{status: s, body: body}}, ctx, dur)
       when s in 200..299 do
    CircuitBreaker.record_success(ctx.client.config.client_id)
    Telemetry.request_stop(ctx.method, ctx.path, s, dur)
    {:ok, if(is_map(body), do: body, else: parse_body(body))}
  end

  defp handle_response({:ok, %Req.Response{status: 204}}, ctx, dur) do
    CircuitBreaker.record_success(ctx.client.config.client_id)
    Telemetry.request_stop(ctx.method, ctx.path, 204, dur)
    {:ok, %{}}
  end

  defp handle_response({:ok, %Req.Response{status: 429, headers: rh}}, ctx, dur) do
    Telemetry.request_stop(ctx.method, ctx.path, 429, dur)
    wait = parse_retry_after(rh["retry-after"])

    if ctx.attempt < ctx.client.config.max_retries do
      Process.sleep(wait)
      do_request(%{ctx | attempt: ctx.attempt + 1})
    else
      {:error,
       %Error{
         status: 429,
         message: "Rate limited",
         interaction_id: ctx.interaction_id
       }}
    end
  end

  defp handle_response({:ok, %Req.Response{status: s} = resp}, ctx, dur)
       when s >= 500 and ctx.method in [:get, :delete, :put] do
    CircuitBreaker.record_failure(ctx.client.config.client_id)
    Telemetry.request_stop(ctx.method, ctx.path, s, dur)

    if ctx.attempt < ctx.client.config.max_retries do
      Process.sleep(backoff(ctx.attempt))
      do_request(%{ctx | attempt: ctx.attempt + 1})
    else
      {:error, build_error(s, resp.body, ctx.interaction_id)}
    end
  end

  defp handle_response({:ok, %Req.Response{status: s} = resp}, ctx, dur)
       when s >= 400 do
    Telemetry.request_stop(ctx.method, ctx.path, s, dur)
    {:error, build_error(s, resp.body, ctx.interaction_id)}
  end

  defp handle_response({:error, err}, ctx, dur) do
    CircuitBreaker.record_failure(ctx.client.config.client_id)
    Telemetry.request_exception(ctx.method, ctx.path, err, dur)

    if ctx.attempt < ctx.client.config.max_retries do
      Process.sleep(backoff(ctx.attempt))
      do_request(%{ctx | attempt: ctx.attempt + 1})
    else
      {:error, {:transport_error, err}}
    end
  end

  defp raw_request(client, method, path, body, content_type, opts) do
    with {:ok, token} <- TokenManager.access_token(client.token_manager) do
      iid = Uniq.UUID.uuid4()
      ikey = Keyword.get(opts, :idempotency_key, Uniq.UUID.uuid4())

      headers =
        base_headers(client.config, token, iid)
        |> maybe_header("x-idempotency-key", ikey)
        |> maybe_header("content-type", content_type)

      req_opts = [method: method, url: path, headers: headers]
      req_opts = if body, do: Keyword.put(req_opts, :body, body), else: req_opts

      case Req.request(client.req, req_opts) do
        {:ok, %Req.Response{status: s, body: rb, headers: rh}} when s in 200..204 ->
          ct = get_in(rh, ["content-type"]) || "application/octet-stream"
          {:ok, rb, ct}

        {:ok, %Req.Response{status: s, body: rb}} ->
          {:error, build_error(s, rb, iid)}

        {:error, err} ->
          {:error, {:transport_error, err}}
      end
    end
  end

  # ── FAPI headers ─────────────────────────────────────────────────────────

  defp base_headers(%Config{} = cfg, token, iid) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"},
      {"x-fapi-interaction-id", iid},
      {"x-fapi-auth-date", fapi_date()}
    ]
    |> maybe_header("x-fapi-financial-id", cfg.financial_id)
    |> maybe_header("x-fapi-customer-ip-address", cfg.customer_ip_address)
  end

  defp fapi_date, do: Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S GMT")

  defp maybe_header(h, _k, v) when v in [nil, ""], do: h
  defp maybe_header(h, k, v), do: [{k, v} | h]

  # ── Backoff ───────────────────────────────────────────────────────────────

  @max_backoff_ms 30_000

  defp backoff(attempt) do
    base = min(trunc(:math.pow(2, attempt - 1) * 500), @max_backoff_ms)
    jitter = :rand.uniform(max(div(base, 2), 1))
    if :rand.uniform(2) == 1, do: max(base - div(jitter, 2), 100), else: base + div(jitter, 2)
  end

  defp parse_retry_after(nil), do: 1_000
  defp parse_retry_after([v | _]), do: parse_retry_after(v)

  defp parse_retry_after(v) when is_binary(v) do
    case Integer.parse(v) do
      {s, ""} -> s * 1_000
      _ -> 1_000
    end
  end

  defp parse_retry_after(_), do: 1_000

  # ── Error ─────────────────────────────────────────────────────────────────

  defp build_error(status, body, iid) do
    parsed =
      case body do
        m when is_map(m) -> m
        b when is_binary(b) -> Jason.decode(b) |> elem_ok(%{"Message" => b})
        _ -> %{}
      end

    %Error{
      status: status,
      code: parsed["Code"],
      message: parsed["Message"] || parsed["message"],
      errors: parsed["Errors"] || [],
      interaction_id: iid
    }
  end

  defp elem_ok({:ok, m}, _), do: m
  defp elem_ok(_, default), do: default

  defp parse_body(bin) when is_binary(bin) do
    case Jason.decode(bin) do
      {:ok, m} -> m
      _ -> %{}
    end
  end

  defp parse_body(other), do: other

  defp maybe_add_mtls(req, %Config{certificate_pem: nil}), do: req

  defp maybe_add_mtls(req, config) do
    case MTLS.build_ssl_opts(config) do
      {:ok, ssl} -> Req.merge(req, connect_options: [transport_opts: ssl])
      _ -> req
    end
  end
end
