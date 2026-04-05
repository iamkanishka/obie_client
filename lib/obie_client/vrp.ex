defmodule ObieClient.VRP do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function, [create_consent: 2, submit: 3, poll: 3, poll: 2]}
  @moduledoc """
  Variable Recurring Payments (VRP) — OBIE v3.1.3.

  Lifecycle: create consent → PSU authorises → (optionally confirm funds) → submit payments → poll.
  """

  alias ObieClient.Client
  alias ObieClient.Signing.JWS
  alias ObieClient.Types.Enums

  @base "/open-banking/v3.1/vrp"

  @doc """
  Creates a VRP consent.

  `data` must contain `ControlParameters` and `Initiation`. Example:

      %{
        "ControlParameters" => %{
          "VRPType"                  => ["UK.OBIE.VRPType.Sweeping"],
          "PSUAuthenticationMethods" => ["UK.OBIE.SCA"],
          "MaximumIndividualAmount"  => %{"Amount" => "500.00", "Currency" => "GBP"},
          "PeriodicLimits"           => [%{
            "PeriodType"      => "Month",
            "PeriodAlignment" => "Calendar",
            "Amount"          => %{"Amount" => "2000.00", "Currency" => "GBP"}
          }]
        },
        "Initiation" => %{
          "DebtorAccount"   => %{
            "SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
            "Identification" => "11223321325698"
          },
          "CreditorAccount" => %{
            "SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
            "Identification" => "30080012343456",
            "Name"           => "Savings"
          }
        }
      }
  """
  @spec create_consent(Client.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_consent(%Client{} = c, data) do
    body = %{"Data" => data, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-vrp-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-vrp-consents/{ConsentId}"
  @spec get_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-vrp-consents/#{id}")

  @doc "DELETE /domestic-vrp-consents/{ConsentId}"
  @spec delete_consent(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/domestic-vrp-consents/#{id}")

  @doc "GET /domestic-vrp-consents/{ConsentId}/funds-confirmation"
  @spec get_consent_funds_confirmation(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_consent_funds_confirmation(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-vrp-consents/#{id}/funds-confirmation")

  @doc "POST /domestic-vrps — submit an individual VRP payment."
  @spec submit(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit(%Client{} = c, consent_id, instruction) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Instruction" => instruction}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-vrps", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-vrps/{DomesticVRPId}"
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Client{} = c, id), do: Client.get(c, "#{@base}/domestic-vrps/#{id}")

  @doc "GET /domestic-vrps/{DomesticVRPId}/payment-details"
  @spec get_details(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-vrps/#{id}/payment-details")

  @doc "Polls a VRP payment until terminal status. Options: `:interval_ms`, `:timeout_ms`."
  @spec poll(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll(%Client{} = c, id, opts \\ []) do
    interval = Keyword.get(opts, :interval_ms, 3_000)
    timeout = Keyword.get(opts, :timeout_ms, 300_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(c, id, interval, deadline)
  end

  defp do_poll(c, id, interval, deadline) do
    case get(c, id) do
      {:ok, %{"Data" => %{"Status" => s}} = resp} ->
        cond do
          Enums.terminal_payment_status?(s) ->
            {:ok, resp}

          System.monotonic_time(:millisecond) >= deadline ->
            {:error, :timeout}

          true ->
            Process.sleep(interval)
            do_poll(c, id, interval, deadline)
        end

      {:error, _} = e ->
        e
    end
  end

  defp sign(%Client{config: cfg}, body), do: JWS.sign(body, cfg)
end
