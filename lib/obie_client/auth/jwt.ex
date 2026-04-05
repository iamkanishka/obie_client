defmodule ObieClient.Auth.JWT do
  @moduledoc """
  Builds RS256 `client_assertion` JWTs for OAuth2 `private_key_jwt` authentication
  as required by OBIE/FAPI.

  The assertion carries: `iss`/`sub` = `client_id`, `aud` = token URL,
  `exp` = now+5 min, `iat` = now, `jti` = UUID, `kid` in the JOSE header.
  """

  alias ObieClient.Config

  @assertion_ttl 300

  @doc """
  Builds and signs a `client_assertion` JWT using the config's private key.

  Returns `{:ok, compact_jwt}` or `{:error, reason}`.
  """
  @spec client_assertion(Config.t()) :: {:ok, String.t()} | {:error, term()}
  def client_assertion(%Config{} = cfg) do
    now = System.system_time(:second)

    claims = %{
      "iss" => cfg.client_id,
      "sub" => cfg.client_id,
      "aud" => cfg.token_url,
      "exp" => now + @assertion_ttl,
      "iat" => now,
      "jti" => Uniq.UUID.uuid4()
    }

    # Joken.Signer.create/2 signature: (algorithm, key_source_map)
    # key_source_map must be %{"pem" => pem_binary} for RSA keys.
    signer = Joken.Signer.create("RS256", %{"pem" => cfg.private_key_pem})

    case Joken.generate_and_sign(%{}, claims, signer) do
      {:ok, token, _claims} ->
        # If a signing_key_id is configured, prepend kid header via re-encoding.
        # For simplicity and correctness we inject kid by reconstructing the JWT
        # header — this avoids the incorrect Joken.Signer.create/3 call that
        # expects a map (not keyword list) as the third argument.
        if cfg.signing_key_id != "" do
          inject_kid(token, cfg.signing_key_id, cfg.private_key_pem)
        else
          {:ok, token}
        end

      {:error, reason} ->
        {:error, {:jwt_sign_error, reason}}
    end
  end

  @doc """
  Parses a PEM-encoded RSA private key (PKCS#1 or PKCS#8).
  Returns `{:ok, key}` or `{:error, :invalid_pem | :unsupported_key_type}`.
  """
  @spec parse_private_key(binary()) ::
          {:ok, term()} | {:error, :invalid_pem | :unsupported_key_type}
  def parse_private_key(pem) when is_binary(pem) do
    case :public_key.pem_decode(pem) do
      [{type, der, _} | _] when type in [:RSAPrivateKey, :PrivateKeyInfo] ->
        {:ok, :public_key.pem_entry_decode({type, der, :not_encrypted})}

      [] ->
        {:error, :invalid_pem}

      _ ->
        {:error, :unsupported_key_type}
    end
  end

  @doc "Parses a PEM-encoded RSA public key."
  @spec parse_public_key(binary()) ::
          {:ok, term()} | {:error, :invalid_pem | :unsupported_key_type}
  def parse_public_key(pem) when is_binary(pem) do
    case :public_key.pem_decode(pem) do
      [{type, der, _} | _] when type in [:SubjectPublicKeyInfo, :RSAPublicKey] ->
        {:ok, :public_key.pem_entry_decode({type, der, :not_encrypted})}

      [] ->
        {:error, :invalid_pem}

      _ ->
        {:error, :unsupported_key_type}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────

  # Re-sign the JWT with a kid header injected.
  # We decode the payload, rebuild the header with kid, and re-sign.
  defp inject_kid(jwt, kid, pem) do
    [_header_b64, payload_b64, _sig] = String.split(jwt, ".")

    header_json = Jason.encode!(%{"alg" => "RS256", "typ" => "JWT", "kid" => kid})
    new_header_b64 = Base.url_encode64(header_json, padding: false)
    signing_input = new_header_b64 <> "." <> payload_b64

    with {:ok, key} <- parse_private_key(pem) do
      sig = :public_key.sign(signing_input, :sha256, key)
      sig_b64 = Base.url_encode64(sig, padding: false)
      {:ok, new_header_b64 <> "." <> payload_b64 <> "." <> sig_b64}
    end
  end
end
