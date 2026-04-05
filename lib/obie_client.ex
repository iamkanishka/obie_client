defmodule ObieClient do
  @moduledoc """
  ObieClient — production-grade Elixir client for the UK Open Banking (OBIE)
  Read/Write API **v3.1.3**.

  ## Quick start

      config :obie_client,
        client_id:       System.fetch_env!("OBIE_CLIENT_ID"),
        token_url:       System.fetch_env!("OBIE_TOKEN_URL"),
        private_key_pem: File.read!(System.fetch_env!("OBIE_KEY_PATH")),
        signing_key_id:  System.fetch_env!("OBIE_KID"),
        financial_id:    System.fetch_env!("OBIE_FINANCIAL_ID"),
        environment:     :production

      {:ok, client} = ObieClient.new_client()

      # AIS — create consent
      perms = ObieClient.Types.Enums.detail_permissions()
      {:ok, consent} = ObieClient.AISP.Consent.create(client, perms)

      # After PSU authorises …
      {:ok, %{"Data" => %{"Account" => accounts}}} = ObieClient.Accounts.list(client)

      # PIS — domestic payment
      {:ok, payment_consent} = ObieClient.Payments.create_domestic_consent(client, initiation)
      # After PSU authorises …
      {:ok, payment} = ObieClient.Payments.submit_domestic(client, consent_id, initiation)
      {:ok, _}       = ObieClient.Payments.poll_domestic(client, payment["Data"]["DomesticPaymentId"])

  ## Module index

  | Module | Purpose |
  |--------|---------|
  | `ObieClient.Client` | HTTP pipeline — auth, retry, circuit breaker |
  | `ObieClient.Config` | Configuration struct |
  | `ObieClient.Error`  | Structured error type |
  | `ObieClient.AISP.Consent` | Account-access-consent lifecycle |
  | `ObieClient.Accounts` | AIS read endpoints (13 resource types) |
  | `ObieClient.Payments` | PIS — all 6 payment types |
  | `ObieClient.FilePayments` | Bulk file payment flow |
  | `ObieClient.Funds` | CBPII funds confirmation |
  | `ObieClient.VRP` | Variable recurring payments |
  | `ObieClient.EventNotifications` | Subscriptions, callbacks, polling |
  | `ObieClient.Events.Handler` | Real-time webhook receipt |
  | `ObieClient.Auth.TokenManager` | OAuth2 client-credentials cache |
  | `ObieClient.Auth.JWT` | RS256 `client_assertion` builder |
  | `ObieClient.Auth.MTLS` | mTLS SSL options |
  | `ObieClient.Signing.JWS` | Detached JWS (OBIE `b64=false` profile) |
  | `ObieClient.Validation` | Client-side request validation |
  | `ObieClient.CircuitBreaker` | Closed/Open/HalfOpen circuit breaker |
  | `ObieClient.RateLimiter` | Token-bucket rate limiter |
  | `ObieClient.Cache` | ETS TTL cache |
  | `ObieClient.Telemetry` | Telemetry events |
  | `ObieClient.Pagination` | Lazy HATEOAS stream |
  | `ObieClient.Types.Enums` | All OBIE v3.1.3 enumeration values |
  | `ObieClient.Types.Common` | Shared struct types |
  """

  alias ObieClient.Client
  alias ObieClient.Config

  @version "1.0.0"
  @spec_version "v3.1.3"

  @doc "Library version."
  @spec version() :: String.t()
  def version, do: @version

  @doc "OBIE Read/Write API specification version targeted by this library."
  @spec spec_version() :: String.t()
  def spec_version, do: @spec_version

  @doc """
  Creates a new `ObieClient.Client` from application configuration.

  Reads `config :obie_client, ...` and merges `opts` as overrides.
  Supports `{:system, "ENV_VAR"}` tuples for runtime secret loading.

  ## Examples

      {:ok, client} = ObieClient.new_client()

      {:ok, client} = ObieClient.new_client(
        client_id: "my-client",
        token_url:  "https://aspsp.example.com/token",
        private_key_pem: File.read!("private.pem"),
        environment: :production
      )
  """
  @spec new_client(keyword()) :: {:ok, Client.t()} | {:error, term()}
  def new_client(opts \\ []) do
    with {:ok, config} <- Config.from_app_env(opts) do
      Client.new(config)
    end
  end
end
