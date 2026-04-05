import Config

# ── ObieClient base configuration ─────────────────────────────────────────
#
# Defaults shared across all environments. Override in the env-specific files
# below, or at runtime in config/runtime.exs.
#
# See `ObieClient.Config` for full documentation of every key.

config :obie_client,
  environment: :sandbox,
  timeout: 30_000,
  max_retries: 3,
  pool_size: 10,
  scopes: ~w[accounts payments fundsconfirmations],
  signing_key_id: "",
  financial_id: ""

# Import environment-specific config. This must remain at the bottom.
import_config "#{config_env()}.exs"
