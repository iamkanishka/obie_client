import Config

# ── Production environment ──────────────────────────────────────────────────
#
# Production secrets must NEVER be committed to source control.
# All credentials are loaded at runtime from environment variables via
# config/runtime.exs. This file only sets non-secret, non-sensitive defaults.
#
# Required runtime config (set in config/runtime.exs):
#
#   config :obie_client,
#     client_id:       System.fetch_env!("OBIE_CLIENT_ID"),
#     token_url:       System.fetch_env!("OBIE_TOKEN_URL"),
#     private_key_pem: File.read!(System.fetch_env!("OBIE_KEY_PATH")),
#     certificate_pem: File.read!(System.fetch_env!("OBIE_CERT_PATH")),
#     signing_key_id:  System.fetch_env!("OBIE_SIGNING_KID"),
#     financial_id:    System.fetch_env!("OBIE_FINANCIAL_ID")

config :obie_client,
  environment: :production,
  timeout: 30_000,
  max_retries: 3,
  pool_size: 20,
  scopes: ~w[accounts payments fundsconfirmations]
