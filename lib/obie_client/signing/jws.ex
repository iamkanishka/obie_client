defmodule ObieClient.Signing.JWS do
  @moduledoc """
  Detached JWS signatures for OBIE payment request bodies.

  The OBIE signing profile (RFC 7797) requires:
  - `alg: RS256`, `kid:` = signing key ID
  - `b64: false` — unencoded payload in signing input
  - `crit: ["b64"]`

  The result is the `x-jws-signature` header value:
  `<base64url(header)>..<base64url(signature)>`
  """

  alias ObieClient.Auth.JWT
  alias ObieClient.Config

  @doc "Signs `payload` (a map) with the config's private key."
  @spec sign(map(), Config.t()) :: {:ok, String.t()} | {:error, term()}
  def sign(payload, %Config{private_key_pem: pem, signing_key_id: kid}) do
    with {:ok, json} <- Jason.encode(payload),
         {:ok, key} <- JWT.parse_private_key(pem) do
      sign_bytes(json, key, kid)
    end
  end

  @doc "Signs raw bytes as a detached JWS."
  @spec sign_bytes(binary(), term(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def sign_bytes(payload_bytes, private_key, kid) do
    header = %{"alg" => "RS256", "kid" => kid, "b64" => false, "crit" => ["b64"]}

    with {:ok, header_json} <- Jason.encode(header) do
      encoded_header = Base.url_encode64(header_json, padding: false)
      signing_input = encoded_header <> "." <> payload_bytes
      digest = :crypto.hash(:sha256, signing_input)
      # :public_key.sign/3 always returns binary() — no other clause needed
      signature = :public_key.sign(digest, :sha256, private_key)
      {:ok, encoded_header <> ".." <> Base.url_encode64(signature, padding: false)}
    end
  end

  @doc "Verifies a detached JWS against `payload_bytes` using an RSA public key."
  @spec verify(String.t(), binary(), term()) ::
          :ok
          | {:error, :invalid_jws_format | :base64_decode_error | :signature_mismatch}
  def verify(jws, payload_bytes, public_key) do
    case String.split(jws, "..") do
      [encoded_header, encoded_sig] ->
        verify_parts(encoded_header, encoded_sig, payload_bytes, public_key)

      _ ->
        {:error, :invalid_jws_format}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────

  defp verify_parts(encoded_header, encoded_sig, payload_bytes, public_key) do
    with {:ok, _header_json} <- Base.url_decode64(encoded_header, padding: false),
         {:ok, signature} <- Base.url_decode64(encoded_sig, padding: false) do
      signing_input = encoded_header <> "." <> payload_bytes
      digest = :crypto.hash(:sha256, signing_input)

      if :public_key.verify(digest, :sha256, signature, public_key),
        do: :ok,
        else: {:error, :signature_mismatch}
    else
      _ -> {:error, :base64_decode_error}
    end
  end
end
