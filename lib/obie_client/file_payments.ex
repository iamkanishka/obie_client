defmodule ObieClient.FilePayments do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function,
             [create_consent: 3, create_consent: 2, upload_file: 4, submit: 3, poll: 3, poll: 2]}
  @moduledoc """
  File Payment Initiation — bulk payment file upload and submission.

  Lifecycle: create consent → upload file → PSU authorises → submit → poll → report.
  """

  alias ObieClient.Client
  alias ObieClient.Signing.JWS

  @base "/open-banking/v3.1/pisp"
  @terminal ~w[InitiationCompleted InitiationFailed Rejected]

  @doc "Creates a file payment consent."
  @spec create_consent(Client.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_consent(%Client{} = c, initiation, opts \\ []) do
    body = %{"Data" => %{"Initiation" => initiation}, "Risk" => Keyword.get(opts, :risk, %{})}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/file-payment-consents", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /file-payment-consents/{ConsentId}"
  @spec get_consent(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_consent(%Client{} = c, id),
    do: Client.get(c, "#{@base}/file-payment-consents/#{id}")

  @doc "POST /file-payment-consents/{ConsentId}/file — upload payment file."
  @spec upload_file(Client.t(), String.t(), binary(), String.t()) ::
          :ok | {:error, term()}
  def upload_file(%Client{} = c, consent_id, file_bytes, content_type) do
    case Client.post_raw(
           c,
           "#{@base}/file-payment-consents/#{consent_id}/file",
           file_bytes,
           content_type,
           idempotency_key: Uniq.UUID.uuid4()
         ) do
      {:ok, _, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc "GET /file-payment-consents/{ConsentId}/file — download uploaded file."
  @spec download_file(Client.t(), String.t()) ::
          {:ok, binary(), String.t()} | {:error, term()}
  def download_file(%Client{} = c, consent_id),
    do: Client.get_raw(c, "#{@base}/file-payment-consents/#{consent_id}/file")

  @doc "POST /file-payments — submit file payment after authorisation."
  @spec submit(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit(%Client{} = c, consent_id, initiation) do
    body = %{"Data" => %{"ConsentId" => consent_id, "Initiation" => initiation}, "Risk" => %{}}

    with {:ok, jws} <- sign(c, body) do
      Client.post(c, "#{@base}/file-payments", body,
        jws_signature: jws,
        idempotency_key: Uniq.UUID.uuid4()
      )
    end
  end

  @doc "GET /file-payments/{FilePaymentId}"
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Client{} = c, id), do: Client.get(c, "#{@base}/file-payments/#{id}")

  @doc "GET /file-payments/{FilePaymentId}/payment-details"
  @spec get_details(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_details(%Client{} = c, id),
    do: Client.get(c, "#{@base}/file-payments/#{id}/payment-details")

  @doc "GET /file-payments/{FilePaymentId}/report-file — download results report."
  @spec get_report(Client.t(), String.t()) ::
          {:ok, binary(), String.t()} | {:error, term()}
  def get_report(%Client{} = c, id),
    do: Client.get_raw(c, "#{@base}/file-payments/#{id}/report-file")

  @doc "Polls until terminal status. Options: `:interval_ms` (5000), `:timeout_ms` (600_000)."
  @spec poll(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :timeout} | {:error, term()}
  def poll(%Client{} = c, id, opts \\ []) do
    interval = Keyword.get(opts, :interval_ms, 5_000)
    timeout = Keyword.get(opts, :timeout_ms, 600_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(c, id, interval, deadline)
  end

  defp do_poll(c, id, interval, deadline) do
    case get(c, id) do
      {:ok, %{"Data" => %{"Status" => s}} = resp} when s in @terminal ->
        {:ok, resp}

      {:ok, _} ->
        if System.monotonic_time(:millisecond) >= deadline,
          do: {:error, :timeout},
          else:
            (
              Process.sleep(interval)
              do_poll(c, id, interval, deadline)
            )

      {:error, _} = e ->
        e
    end
  end

  defp sign(%Client{config: cfg}, body), do: JWS.sign(body, cfg)
end
