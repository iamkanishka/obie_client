import Config

# ── Runtime configuration ───────────────────────────────────────────────────
#
# Loaded AFTER compilation in all environments (dev, test, prod).
# This is the right place for secrets loaded from environment variables,
# because unlike config/prod.exs it runs at boot — not at compile time.
#
# Docs: https://hexdocs.pm/elixir/Config.html#module-config-runtime-exs

if config_env() == :prod do
  # ── Required ──────────────────────────────────────────────────────────────

  client_id = System.fetch_env!("OBIE_CLIENT_ID")
  token_url = System.fetch_env!("OBIE_TOKEN_URL")

  private_key_path = System.fetch_env!("OBIE_KEY_PATH")

  private_key_pem =
    case File.read(private_key_path) do
      {:ok, pem} ->
        pem

      {:error, reason} ->
        raise "Cannot read OBIE private key at #{private_key_path}: #{reason}"
    end

  signing_key_id = System.fetch_env!("OBIE_SIGNING_KID")
  financial_id = System.fetch_env!("OBIE_FINANCIAL_ID")

  # ── Optional mTLS transport certificate ──────────────────────────────────

  certificate_pem =
    case System.get_env("OBIE_CERT_PATH") do
      nil ->
        nil

      cert_path ->
        case File.read(cert_path) do
          {:ok, pem} -> pem
          {:error, reason} -> raise "Cannot read OBIE cert at #{cert_path}: #{reason}"
        end
    end

  # ── Optional overrides ────────────────────────────────────────────────────

  # Override base_url to target a specific ASPSP rather than the default.
  base_url = System.get_env("OBIE_BASE_URL")

  # Override customer IP for FAPI header (PSU's IP, not server IP).
  customer_ip = System.get_env("OBIE_CUSTOMER_IP_ADDRESS")

  # Build the runtime config, only including optional keys when set.

  runtime_config =
    [
      client_id: client_id,
      token_url: token_url,
      private_key_pem: private_key_pem,
      certificate_pem: certificate_pem,
      signing_key_id: signing_key_id,
      financial_id: financial_id
    ]

  runtime_config =
    if base_url do
      Keyword.put(runtime_config, :base_url, base_url)
    else
      runtime_config
    end

  runtime_config =
    if customer_ip do
      Keyword.put(runtime_config, :customer_ip_address, customer_ip)
    else
      runtime_config
    end

  config :obie_client, runtime_config
end

if config_env() == :dev do
  # In dev, credentials are usually set via dev.secret.exs or environment variables.
  # This block is optional — uncomment if you prefer runtime loading in dev too.

  # if client_id = System.get_env("OBIE_CLIENT_ID") do
  #   config :obie_client,
  #     client_id:       client_id,
  #     token_url:       System.fetch_env!("OBIE_TOKEN_URL"),
  #     private_key_pem: File.read!(System.fetch_env!("OBIE_KEY_PATH")),
  #     signing_key_id:  System.get_env("OBIE_SIGNING_KID", ""),
  #     financial_id:    System.get_env("OBIE_FINANCIAL_ID", "")
  # end
  :ok
end
