# ── Local sandbox credentials (git-ignored) ────────────────────────────────
#
# This file is NOT committed. Add to .gitignore:
#   echo "config/dev.secret.exs" >> .gitignore
#
# Fill in your real sandbox values then save this file.

import Config

config :obie_client,
  client_id: "REPLACE_WITH_YOUR_SANDBOX_CLIENT_ID",
  token_url: "REPLACE_WITH_YOUR_SANDBOX_TOKEN_URL",
  # Read the key from disk — adjust the path to your sandbox private key:
  # private_key_pem: File.read!(Path.expand("~/.obie/sandbox_private.pem")),
  private_key_pem: "-----BEGIN RSA PRIVATE KEY-----\nREPLACE_ME\n-----END RSA PRIVATE KEY-----\n",
  signing_key_id: "REPLACE_WITH_YOUR_KID",
  financial_id: "REPLACE_WITH_YOUR_FINANCIAL_ID"
