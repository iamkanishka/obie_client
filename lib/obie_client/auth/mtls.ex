defmodule ObieClient.Auth.MTLS do
  @moduledoc """
  Builds SSL/TLS options for mutual TLS (mTLS) as required by OBIE.

  Returns `:ssl` keyword options suitable for
  `Req.new(connect_options: [transport_opts: opts])`.
  """

  alias ObieClient.Config

  @doc "Builds SSL options from the config's PEM cert and key."
  @spec build_ssl_opts(ObieClient.Config.t()) :: {:ok, keyword()} | {:error, term()}
  def build_ssl_opts(%Config{certificate_pem: nil}),
    do: {:error, :no_certificate_configured}

  def build_ssl_opts(%Config{certificate_pem: cert_pem, private_key_pem: key_pem}) do
    with {:ok, cert_der} <- decode_cert(cert_pem),
         {:ok, key_entry} <- decode_key(key_pem) do
      {:ok,
       [
         cert: cert_der,
         key: key_entry,
         verify: :verify_peer,
         cacerts: :public_key.cacerts_get(),
         versions: [:"tlsv1.2", :"tlsv1.3"]
       ]}
    end
  end

  defp decode_cert(pem) do
    case :public_key.pem_decode(pem) do
      [{:Certificate, der, _} | _] -> {:ok, der}
      _ -> {:error, :invalid_certificate_pem}
    end
  end

  defp decode_key(pem) do
    case :public_key.pem_decode(pem) do
      [{type, der, _} | _] when type in [:RSAPrivateKey, :PrivateKeyInfo] ->
        {:ok, {type, der}}

      _ ->
        {:error, :invalid_private_key_pem}
    end
  end
end
