defmodule ObieClient.AISP.Consent do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function, [poll_until_authorised: 2, poll_until_authorised: 3]}
  @moduledoc """
  Account Access Consent lifecycle — POST, GET, DELETE.

  Must be called before any AIS resource reads. The returned `ConsentId`
  is used to build the PSU's authorisation redirect URL at the ASPSP.

  ## Spec
  `POST/GET/DELETE /account-access-consents` (Account Information API v3.1.3)
  """

  alias ObieClient.Client

  @base "/open-banking/v3.1/aisp"

  @doc """
  Creates a new account-access-consent.

  ## Parameters
  - `permissions` — list of permission strings (see `ObieClient.Types.Enums.all_permissions/0`)
  - `opts`:
    - `:expiration_date_time` — `DateTime` or ISO-8601 string; omit for open-ended
    - `:transaction_from_date_time` — earliest transaction date
    - `:transaction_to_date_time` — latest transaction date

  ## Examples

      perms = ObieClient.Types.Enums.detail_permissions()
      {:ok, consent} = ObieClient.AISP.Consent.create(client, perms,
        expiration_date_time: DateTime.add(DateTime.utc_now(), 90, :day))

      consent["Data"]["ConsentId"]   # => "urn-alphabank-intent-88379"
      consent["Data"]["Status"]       # => "AwaitingAuthorisation"
  """
  @spec create(Client.t(), [String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def create(%Client{} = client, permissions, opts \\ []) do
    body = %{
      "Data" => build_data(permissions, opts),
      "Risk" => %{}
    }

    Client.post(client, "#{@base}/account-access-consents", body)
  end

  @doc """
  Retrieves an account-access-consent by `ConsentId`.

  ## Examples

      {:ok, consent} = ObieClient.AISP.Consent.get(client, "urn-alphabank-intent-88379")
      consent["Data"]["Status"]  # => "Authorised"
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Client{} = client, consent_id) do
    Client.get(client, "#{@base}/account-access-consents/#{consent_id}")
  end

  @doc """
  Deletes (revokes) an account-access-consent.

  Should be called when the PSU revokes consent with the TPP so the ASPSP
  is also notified. Returns `:ok` on success (HTTP 204).
  """
  @spec delete(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete(%Client{} = client, consent_id) do
    Client.delete(client, "#{@base}/account-access-consents/#{consent_id}")
  end

  @doc """
  Polls the consent until `"Authorised"`, a terminal rejection, or timeout.

  ## Options
  - `:interval_ms` — poll interval (default: `2_000`)
  - `:timeout_ms`  — total timeout (default: `120_000`)

  ## Examples

      {:ok, consent} = ObieClient.AISP.Consent.poll_until_authorised(
        client, consent_id, interval_ms: 3_000, timeout_ms: 60_000
      )
  """
  @spec poll_until_authorised(Client.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :timeout}
          | {:error, {:consent_rejected, String.t()}}
          | {:error, term()}
  def poll_until_authorised(%Client{} = client, consent_id, opts \\ []) do
    interval = Keyword.get(opts, :interval_ms, 2_000)
    timeout = Keyword.get(opts, :timeout_ms, 120_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(client, consent_id, interval, deadline)
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp build_data(permissions, opts) do
    %{"Permissions" => permissions}
    |> put_datetime("ExpirationDateTime", Keyword.get(opts, :expiration_date_time))
    |> put_datetime("TransactionFromDateTime", Keyword.get(opts, :transaction_from_date_time))
    |> put_datetime("TransactionToDateTime", Keyword.get(opts, :transaction_to_date_time))
  end

  defp put_datetime(map, _key, nil), do: map
  defp put_datetime(map, key, %DateTime{} = dt), do: Map.put(map, key, DateTime.to_iso8601(dt))
  defp put_datetime(map, key, value), do: Map.put(map, key, value)

  defp do_poll(client, consent_id, interval, deadline) do
    case get(client, consent_id) do
      {:ok, %{"Data" => %{"Status" => "Authorised"}} = consent} ->
        {:ok, consent}

      {:ok, %{"Data" => %{"Status" => status}}} when status in ["Rejected", "Revoked"] ->
        {:error, {:consent_rejected, status}}

      {:ok, _} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(interval)
          do_poll(client, consent_id, interval, deadline)
        end

      {:error, _} = err ->
        err
    end
  end
end
