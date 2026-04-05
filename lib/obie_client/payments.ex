defmodule ObieClient.Payments do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function,
             [
               create_domestic_consent: 3,
               submit_domestic: 3,
               poll_domestic: 3,
               create_domestic_scheduled_consent: 3,
               submit_domestic_scheduled: 3,
               poll_domestic_scheduled: 3,
               create_domestic_standing_order_consent: 3,
               submit_domestic_standing_order: 3,
               create_international_consent: 3,
               submit_international: 3,
               poll_international: 3,
               create_international_scheduled_consent: 3,
               submit_international_scheduled: 3,
               poll_international_scheduled: 3,
               create_international_standing_order_consent: 3,
               submit_international_standing_order: 3,
               poll_international_standing_order: 3
             ]}
  @moduledoc """
  Payment Initiation Service (PIS) — all 6 payment types, full lifecycle.

  Each type follows: **create consent → PSU authorises → submit → poll**.

  | Type | Consent | Submit | Poll |
  |------|---------|--------|------|
  | Domestic | `create_domestic_consent/3` | `submit_domestic/3` | `poll_domestic/3` |
  | Dom. Scheduled | `create_domestic_scheduled_consent/3` | `submit_domestic_scheduled/3` | `poll_domestic_scheduled/3` |
  | Dom. Standing Order | `create_domestic_standing_order_consent/3` | `submit_domestic_standing_order/3` | — |
  | International | `create_international_consent/3` | `submit_international/3` | `poll_international/3` |
  | Intl. Scheduled | `create_international_scheduled_consent/3` | `submit_international_scheduled/3` | `poll_international_scheduled/3` |
  | Intl. Standing Order | `create_international_standing_order_consent/3` | `submit_international_standing_order/3` | `poll_international_standing_order/3` |

  ## Spec
  Payment Initiation API v3.1.3 — resources-and-data-models/pisp/
  """

  alias ObieClient.Client
  alias ObieClient.Signing.JWS
  alias ObieClient.Types.Enums

  @base "/open-banking/v3.1/pisp"

  # ══════════════════════════════════════════════════════════════════════════
  # DOMESTIC PAYMENTS
  # ══════════════════════════════════════════════════════════════════════════

  @doc """
  Creates a domestic payment consent.

  `initiation` is a map matching `OBDomesticInitiation` (see spec), e.g.:

      %{
        "InstructionIdentification" => "INSTR-001",
        "EndToEndIdentification"    => "E2E-001",
        "InstructedAmount"          => %{"Amount" => "10.50", "Currency" => "GBP"},
        "CreditorAccount"           => %{
          "SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
          "Identification" => "20000319825731",
          "Name"           => "Beneficiary Name"
        }
      }
  """
  @spec create_domestic_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_domestic_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-payment-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-payment-consents/{ConsentId}"
  @spec get_domestic_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-payment-consents/#{id}")

  @doc "GET /domestic-payment-consents/{ConsentId}/funds-confirmation"
  @spec get_domestic_consent_funds_confirmation(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_domestic_consent_funds_confirmation(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-payment-consents/#{id}/funds-confirmation")

  @doc "Submits a domestic payment against an authorised consent."
  @spec submit_domestic(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit_domestic(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-payments", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-payments/{DomesticPaymentId}"
  @spec get_domestic(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-payments/#{id}")

  @doc "GET /domestic-payments/{DomesticPaymentId}/payment-details"
  @spec get_domestic_details(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-payments/#{id}/payment-details")

  @doc "Polls until terminal status or timeout. Options: `:interval_ms`, `:timeout_ms`."
  @spec poll_domestic(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll_domestic(%Client{} = c, id, opts \\ []),
    do: poll(c, &get_domestic/2, id, opts)

  # ══════════════════════════════════════════════════════════════════════════
  # DOMESTIC SCHEDULED PAYMENTS
  # ══════════════════════════════════════════════════════════════════════════

  @doc "Creates a domestic scheduled payment consent."
  @spec create_domestic_scheduled_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_domestic_scheduled_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-scheduled-payment-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-scheduled-payment-consents/{ConsentId}"
  @spec get_domestic_scheduled_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_scheduled_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-scheduled-payment-consents/#{id}")

  @doc "DELETE /domestic-scheduled-payment-consents/{ConsentId}"
  @spec delete_domestic_scheduled_consent(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_domestic_scheduled_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/domestic-scheduled-payment-consents/#{id}")

  @doc "Submits a domestic scheduled payment."
  @spec submit_domestic_scheduled(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def submit_domestic_scheduled(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-scheduled-payments", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-scheduled-payments/{DomesticScheduledPaymentId}"
  @spec get_domestic_scheduled(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_scheduled(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-scheduled-payments/#{id}")

  @doc "GET /domestic-scheduled-payments/{DomesticScheduledPaymentId}/payment-details"
  @spec get_domestic_scheduled_details(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_scheduled_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-scheduled-payments/#{id}/payment-details")

  @doc "Polls a domestic scheduled payment until terminal status."
  @spec poll_domestic_scheduled(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll_domestic_scheduled(%Client{} = c, id, opts \\ []),
    do: poll(c, &get_domestic_scheduled/2, id, opts)

  # ══════════════════════════════════════════════════════════════════════════
  # DOMESTIC STANDING ORDERS
  # ══════════════════════════════════════════════════════════════════════════

  @doc "Creates a domestic standing order consent."
  @spec create_domestic_standing_order_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_domestic_standing_order_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-standing-order-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-standing-order-consents/{ConsentId}"
  @spec get_domestic_standing_order_consent(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_domestic_standing_order_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-standing-order-consents/#{id}")

  @doc "DELETE /domestic-standing-order-consents/{ConsentId}"
  @spec delete_domestic_standing_order_consent(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_domestic_standing_order_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/domestic-standing-order-consents/#{id}")

  @doc "Submits a domestic standing order."
  @spec submit_domestic_standing_order(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def submit_domestic_standing_order(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/domestic-standing-orders", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /domestic-standing-orders/{DomesticStandingOrderId}"
  @spec get_domestic_standing_order(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_domestic_standing_order(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-standing-orders/#{id}")

  @doc "GET /domestic-standing-orders/{DomesticStandingOrderId}/payment-details"
  @spec get_domestic_standing_order_details(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_domestic_standing_order_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/domestic-standing-orders/#{id}/payment-details")

  # ══════════════════════════════════════════════════════════════════════════
  # INTERNATIONAL PAYMENTS
  # ══════════════════════════════════════════════════════════════════════════

  @doc "Creates an international payment consent."
  @spec create_international_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_international_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-payment-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-payment-consents/{ConsentId}"
  @spec get_international_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_international_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-payment-consents/#{id}")

  @doc "GET /international-payment-consents/{ConsentId}/funds-confirmation"
  @spec get_international_consent_funds_confirmation(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_consent_funds_confirmation(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-payment-consents/#{id}/funds-confirmation")

  @doc "Submits an international payment."
  @spec submit_international(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit_international(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-payments", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-payments/{InternationalPaymentId}"
  @spec get_international(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_international(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-payments/#{id}")

  @doc "GET /international-payments/{InternationalPaymentId}/payment-details"
  @spec get_international_details(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_international_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-payments/#{id}/payment-details")

  @doc "Polls an international payment until terminal status."
  @spec poll_international(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll_international(%Client{} = c, id, opts \\ []),
    do: poll(c, &get_international/2, id, opts)

  # ══════════════════════════════════════════════════════════════════════════
  # INTERNATIONAL SCHEDULED PAYMENTS
  # ══════════════════════════════════════════════════════════════════════════

  @doc "Creates an international scheduled payment consent."
  @spec create_international_scheduled_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_international_scheduled_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-scheduled-payment-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-scheduled-payment-consents/{ConsentId}"
  @spec get_international_scheduled_consent(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_scheduled_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-scheduled-payment-consents/#{id}")

  @doc "DELETE /international-scheduled-payment-consents/{ConsentId}"
  @spec delete_international_scheduled_consent(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_international_scheduled_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/international-scheduled-payment-consents/#{id}")

  @doc "Submits an international scheduled payment."
  @spec submit_international_scheduled(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def submit_international_scheduled(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-scheduled-payments", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-scheduled-payments/{InternationalScheduledPaymentId}"
  @spec get_international_scheduled(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_international_scheduled(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-scheduled-payments/#{id}")

  @doc "GET /international-scheduled-payments/{InternationalScheduledPaymentId}/payment-details"
  @spec get_international_scheduled_details(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_scheduled_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-scheduled-payments/#{id}/payment-details")

  @doc "Polls an international scheduled payment until terminal status."
  @spec poll_international_scheduled(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll_international_scheduled(%Client{} = c, id, opts \\ []),
    do: poll(c, &get_international_scheduled/2, id, opts)

  # ══════════════════════════════════════════════════════════════════════════
  # INTERNATIONAL STANDING ORDERS
  # ══════════════════════════════════════════════════════════════════════════

  @doc "Creates an international standing order consent."
  @spec create_international_standing_order_consent(Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_international_standing_order_consent(%Client{} = c, initiation, opts \\ []) do
    body = payment_body(initiation, opts)

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-standing-order-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-standing-order-consents/{ConsentId}"
  @spec get_international_standing_order_consent(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_standing_order_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-standing-order-consents/#{id}")

  @doc "DELETE /international-standing-order-consents/{ConsentId}"
  @spec delete_international_standing_order_consent(Client.t(), String.t()) ::
          :ok | {:error, term()}
  def delete_international_standing_order_consent(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/international-standing-order-consents/#{id}")

  @doc "Submits an international standing order."
  @spec submit_international_standing_order(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def submit_international_standing_order(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/international-standing-orders", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /international-standing-orders/{InternationalStandingOrderPaymentId}"
  @spec get_international_standing_order(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_standing_order(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-standing-orders/#{id}")

  @doc "GET /international-standing-orders/{InternationalStandingOrderPaymentId}/payment-details"
  @spec get_international_standing_order_details(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_international_standing_order_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/international-standing-orders/#{id}/payment-details")

  @doc "Polls an international standing order until terminal status."
  @spec poll_international_standing_order(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll_international_standing_order(%Client{} = c, id, opts \\ []),
    do: poll(c, &get_international_standing_order/2, id, opts)

  # ── Private ───────────────────────────────────────────────────────────────

  defp payment_body(initiation, opts) do
    data =
      %{"Initiation" => initiation}
      |> maybe_put("Authorisation", Keyword.get(opts, :authorisation))
      |> maybe_put("SCASupportData", Keyword.get(opts, :sca_support_data))

    %{"Data" => data, "Risk" => Keyword.get(opts, :risk, %{})}
  end

  defp maybe_put(m, _k, nil), do: m
  defp maybe_put(m, k, v), do: Map.put(m, k, v)

  defp sign(%Client{config: cfg}, body),
    do: JWS.sign(body, cfg)

  defp poll(client, get_fn, id, opts) do
    interval = Keyword.get(opts, :interval_ms, 3_000)
    timeout = Keyword.get(opts, :timeout_ms, 300_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(client, get_fn, id, interval, deadline)
  end

  defp do_poll(client, get_fn, id, interval, deadline) do
    case get_fn.(client, id) do
      {:ok, %{"Data" => %{"Status" => s}} = resp} ->
        handle_poll_status(s, resp, client, get_fn, id, interval, deadline)

      {:error, _} = err ->
        err
    end
  end

  defp handle_poll_status(status, resp, client, get_fn, id, interval, deadline) do
    cond do
      Enums.terminal_payment_status?(status) ->
        {:ok, resp}

      System.monotonic_time(:millisecond) >= deadline ->
        {:error, :timeout}

      true ->
        Process.sleep(interval)
        do_poll(client, get_fn, id, interval, deadline)
    end
  end
end
