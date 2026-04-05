import Config

# ── Development environment ────────────────────────────────────────────────
#
# Targets the OBIE sandbox. Credentials can be set here directly for
# local development convenience, but prefer environment variables so secrets
# never live in source control.
#
# Quickstart with env vars:
#
#   export OBIE_CLIENT_ID="your-sandbox-client-id"
#   export OBIE_TOKEN_URL="https://sandbox.aspsp.example.com/token"
#   export OBIE_KEY_PATH="/path/to/sandbox_private.pem"
#   export OBIE_CERT_PATH="/path/to/sandbox_transport.pem"   # mTLS, optional
#   export OBIE_SIGNING_KID="your-signing-key-id"
#   export OBIE_FINANCIAL_ID="0015800001041RHAAY"
#
# Then in config/runtime.exs (preferred) or here:
#
#   config :obie_client,
#     client_id:       System.fetch_env!("OBIE_CLIENT_ID"),
#     token_url:       System.fetch_env!("OBIE_TOKEN_URL"),
#     private_key_pem: File.read!(System.fetch_env!("OBIE_KEY_PATH"))

config :obie_client,
  environment: :sandbox,
  # Lower timeouts make feedback faster during development
  timeout: 15_000,
  max_retries: 1

# Uncomment and fill in to hard-code sandbox credentials locally.
# NEVER commit real keys — add config/dev.secret.exs to .gitignore and use:
#   import_config "dev.secret.exs"
#
# config :obie_client,
#   client_id:       "my-sandbox-client-id",
#   token_url:       "https://sandbox.aspsp.example.com/token",
#   private_key_pem: File.read!("priv/keys/sandbox_private.pem"),
#   certificate_pem: File.read!("priv/keys/sandbox_transport.pem"),
#   signing_key_id:  "my-kid-2025",
#   financial_id:    "0015800001041RHAAY"
