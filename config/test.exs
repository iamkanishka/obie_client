import Config

# ── Test environment ────────────────────────────────────────────────────────
#
# All ASPSP calls are intercepted by Bypass in tests — no real credentials
# are needed at compile time. The test factory (`ObieClient.Test.Factory`)
# stubs the token endpoint automatically via `test_config/2`.
#
# If you want to run integration tests against a real sandbox, set:
#
#   OBIE_INTEGRATION=true
#   OBIE_CLIENT_ID=...   (the real sandbox values)
#   OBIE_TOKEN_URL=...
#   OBIE_KEY_PATH=...
#
# and run: mix test --include integration

config :obie_client,
  environment: :sandbox,
  # Stub values — overridden per-test by ObieClient.Test.Factory.test_config/2
  client_id: "test-client-id",
  token_url: "http://localhost:9999/token",
  private_key_pem: """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4PAtEsHAolCCBq9AMDM4eFGEXoC
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  -----END RSA PRIVATE KEY-----
  """,
  signing_key_id: "test-kid",
  financial_id: "test-financial-id",
  # Fast failure in tests
  timeout: 5_000,
  max_retries: 0
