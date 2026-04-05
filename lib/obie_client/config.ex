defmodule ObieClient.Config do
  @moduledoc """
  Configuration for an OBIE client connection.

  ## Required fields
  - `:client_id` — software client ID in the Open Banking Directory
  - `:token_url` — OAuth2 token endpoint of the ASPSP
  - `:private_key_pem` — PEM-encoded RSA private key (PKCS#1 or PKCS#8)

  ## Optional fields
  | Key | Default | Description |
  |-----|---------|-------------|
  | `:environment` | `:sandbox` | `:sandbox` or `:production` |
  | `:base_url` | derived | Override ASPSP base URL |
  | `:certificate_pem` | `nil` | PEM transport cert for mTLS |
  | `:signing_key_id` | `""` | `kid` header for JWS/JWT |
  | `:financial_id` | `""` | `x-fapi-financial-id` |
  | `:customer_ip_address` | `nil` | `x-fapi-customer-ip-address` |
  | `:scopes` | `["accounts","payments","fundsconfirmations"]` | OAuth2 scopes |
  | `:timeout` | `30_000` | HTTP timeout (ms) |
  | `:max_retries` | `3` | Retry count on idempotent failures |
  | `:pool_size` | `10` | Connection pool size |

  ## Runtime secret resolution

  Any value can be written as `{:system, "ENV_VAR"}` to defer resolution
  until `ObieClient.Config.from_app_env/1` is called at runtime:

      config :obie_client, private_key_pem: {:system, "OBIE_PRIVATE_KEY_PEM"}
  """

  @enforce_keys [:client_id, :token_url, :private_key_pem]
  defstruct [
    :client_id,
    :token_url,
    :private_key_pem,
    :base_url,
    :certificate_pem,
    signing_key_id: "",
    financial_id: "",
    customer_ip_address: nil,
    environment: :sandbox,
    scopes: ~w[accounts payments fundsconfirmations],
    timeout: 30_000,
    max_retries: 3,
    pool_size: 10
  ]

  @type t :: %__MODULE__{
          client_id: String.t(),
          token_url: String.t(),
          private_key_pem: binary(),
          base_url: String.t() | nil,
          certificate_pem: binary() | nil,
          signing_key_id: String.t(),
          financial_id: String.t(),
          customer_ip_address: String.t() | nil,
          environment: :sandbox | :production,
          scopes: [String.t()],
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          pool_size: pos_integer()
        }

  @sandbox_url "https://sandbox.token.io"
  @production_url "https://api.token.io"

  @doc """
  Builds a Config from application env, merging `overrides`.
  Resolves `{:system, "VAR"}` tuples at call time.
  """
  @spec from_app_env(keyword()) :: {:ok, t()} | {:error, String.t()}
  def from_app_env(overrides \\ []) do
    app = Application.get_all_env(:obie_client)
    merged = Keyword.merge(app, overrides)

    with {:ok, resolved} <- resolve_system_env(merged) do
      new(resolved)
    end
  end

  @doc "Builds a Config from a keyword list or map."
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) do
    config = struct!(__MODULE__, Enum.into(attrs, %{}))

    with :ok <- validate(config) do
      {:ok, set_base_url(config)}
    end
  rescue
    e in KeyError -> {:error, "missing required key: #{e.key}"}
  end

  @doc "Returns the effective base URL."
  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{base_url: url}) when is_binary(url) and url != "", do: url
  def base_url(%__MODULE__{environment: :production}), do: @production_url
  def base_url(_), do: @sandbox_url

  # ── Private ─────────────────────────────────────────────────────────────

  defp set_base_url(%__MODULE__{base_url: nil} = cfg), do: %{cfg | base_url: base_url(cfg)}
  defp set_base_url(cfg), do: cfg

  defp validate(%__MODULE__{client_id: v}) when not (is_binary(v) and v != ""),
    do: {:error, "client_id is required and must be a non-empty string"}

  defp validate(%__MODULE__{token_url: v}) when not (is_binary(v) and v != ""),
    do: {:error, "token_url is required and must be a non-empty string"}

  defp validate(%__MODULE__{private_key_pem: v})
       when not (is_binary(v) and byte_size(v) > 0),
       do: {:error, "private_key_pem is required and must be a non-empty binary"}

  defp validate(%__MODULE__{environment: env}) when env not in [:sandbox, :production],
    do: {:error, "environment must be :sandbox or :production, got: #{inspect(env)}"}

  defp validate(_), do: :ok

  defp resolve_system_env(kw) do
    result =
      Enum.map(kw, fn
        {k, {:system, var}} ->
          case System.get_env(var) do
            nil -> throw({:missing_env, var})
            val -> {k, val}
          end

        pair ->
          pair
      end)

    {:ok, result}
  catch
    {:missing_env, var} -> {:error, "environment variable #{var} is not set"}
  end
end
