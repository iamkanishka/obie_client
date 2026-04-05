defmodule ObieClient.Funds do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function, [create_consent: 2, confirm: 4]}
  @moduledoc """
  CBPII — Confirmation of Funds API v3.1.3.

  Allows a Card-Based Payment Instrument Issuer to check whether sufficient
  funds are available in a PSU's payment account.
  """

  alias ObieClient.Client

  @base "/open-banking/v3.1/cbpii"

  @doc "Creates a funds confirmation consent."
  @spec create_consent(Client.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_consent(%Client{} = c, data) do
    Client.post(c, "#{@base}/funds-confirmation-consents", %{"Data" => data},
      idempotency_key: Uniq.UUID.uuid4()
    )
  end

  @doc "GET /funds-confirmation-consents/{ConsentId}"
  @spec get_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/funds-confirmation-consents/#{id}")

  @doc "DELETE /funds-confirmation-consents/{ConsentId}"
  @spec delete_consent(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/funds-confirmation-consents/#{id}")

  @doc """
  Checks whether sufficient funds are available.

  ## Examples

      {:ok, result} = ObieClient.Funds.confirm(client, consent_id,
        "purchase-001", %{"Amount" => "150.00", "Currency" => "GBP"})
      result["Data"]["FundsAvailable"]  # => true
  """
  @spec confirm(Client.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def confirm(%Client{} = c, consent_id, reference, amount) do
    body = %{
      "Data" => %{
        "ConsentId" => consent_id,
        "Reference" => reference,
        "InstructedAmount" => amount
      }
    }

    Client.post(c, "#{@base}/funds-confirmations", body, idempotency_key: Uniq.UUID.uuid4())
  end
end
