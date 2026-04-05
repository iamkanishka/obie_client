defmodule ObieClient.Accounts do
  @moduledoc """
  AIS resource reads — all 13 resource types, each with bulk and per-account variants.

  All functions require an `Authorised` account-access-consent obtained via
  `ObieClient.AISP.Consent.create/3`.

  ## Spec
  Account and Transaction API v3.1.3 — resources-and-data-models/aisp/
  """

  alias ObieClient.Client

  @base "/open-banking/v3.1/aisp"

  # ── Accounts ──────────────────────────────────────────────────────────────

  @doc "GET /accounts — all accounts for the PSU."
  @spec list(Client.t()) :: {:ok, map()} | {:error, term()}
  def list(%Client{} = c), do: Client.get(c, "#{@base}/accounts")

  @doc "GET /accounts/{AccountId} — single account."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Client{} = c, id), do: Client.get(c, "#{@base}/accounts/#{id}")

  # ── Balances ──────────────────────────────────────────────────────────────

  @doc "GET /balances — all balances across all accounts."
  @spec list_balances(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_balances(%Client{} = c), do: Client.get(c, "#{@base}/balances")

  @doc "GET /accounts/{AccountId}/balances"
  @spec list_account_balances(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_balances(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/balances")

  # ── Transactions ──────────────────────────────────────────────────────────

  @doc """
  GET /transactions — all transactions, with optional date filters.

  Options: `:from_booking_date_time`, `:to_booking_date_time` (DateTime or ISO-8601 string).
  """
  @spec list_transactions(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list_transactions(%Client{} = c, opts \\ []) do
    Client.get(c, "#{@base}/transactions#{date_query(opts)}")
  end

  @doc "GET /accounts/{AccountId}/transactions"
  @spec list_account_transactions(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def list_account_transactions(%Client{} = c, id, opts \\ []) do
    Client.get(c, "#{@base}/accounts/#{id}/transactions#{date_query(opts)}")
  end

  # ── Beneficiaries ─────────────────────────────────────────────────────────

  @doc "GET /beneficiaries"
  @spec list_beneficiaries(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_beneficiaries(%Client{} = c), do: Client.get(c, "#{@base}/beneficiaries")

  @doc "GET /accounts/{AccountId}/beneficiaries"
  @spec list_account_beneficiaries(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_beneficiaries(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/beneficiaries")

  # ── Direct Debits ─────────────────────────────────────────────────────────

  @doc "GET /direct-debits"
  @spec list_direct_debits(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_direct_debits(%Client{} = c), do: Client.get(c, "#{@base}/direct-debits")

  @doc "GET /accounts/{AccountId}/direct-debits"
  @spec list_account_direct_debits(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_direct_debits(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/direct-debits")

  # ── Standing Orders ───────────────────────────────────────────────────────

  @doc "GET /standing-orders"
  @spec list_standing_orders(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_standing_orders(%Client{} = c), do: Client.get(c, "#{@base}/standing-orders")

  @doc "GET /accounts/{AccountId}/standing-orders"
  @spec list_account_standing_orders(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_standing_orders(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/standing-orders")

  # ── Scheduled Payments ────────────────────────────────────────────────────

  @doc "GET /scheduled-payments"
  @spec list_scheduled_payments(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_scheduled_payments(%Client{} = c), do: Client.get(c, "#{@base}/scheduled-payments")

  @doc "GET /accounts/{AccountId}/scheduled-payments"
  @spec list_account_scheduled_payments(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_scheduled_payments(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/scheduled-payments")

  # ── Statements ────────────────────────────────────────────────────────────

  @doc "GET /statements"
  @spec list_statements(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_statements(%Client{} = c), do: Client.get(c, "#{@base}/statements")

  @doc "GET /accounts/{AccountId}/statements"
  @spec list_account_statements(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_statements(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/statements")

  @doc "GET /accounts/{AccountId}/statements/{StatementId}"
  @spec get_statement(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_statement(%Client{} = c, account_id, statement_id),
    do: Client.get(c, "#{@base}/accounts/#{account_id}/statements/#{statement_id}")

  @doc "GET /accounts/{AccountId}/statements/{StatementId}/transactions"
  @spec list_statement_transactions(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def list_statement_transactions(%Client{} = c, account_id, statement_id),
    do: Client.get(c, "#{@base}/accounts/#{account_id}/statements/#{statement_id}/transactions")

  @doc "GET /statements/{StatementId}/transactions — bulk, no account ID required."
  @spec list_statement_transactions_bulk(Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def list_statement_transactions_bulk(%Client{} = c, statement_id),
    do: Client.get(c, "#{@base}/statements/#{statement_id}/transactions")

  # ── Parties ───────────────────────────────────────────────────────────────

  @doc "GET /party — PSU-level party."
  @spec get_party(Client.t()) :: {:ok, map()} | {:error, term()}
  def get_party(%Client{} = c), do: Client.get(c, "#{@base}/party")

  @doc "GET /accounts/{AccountId}/party"
  @spec get_account_party(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_account_party(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/party")

  @doc "GET /accounts/{AccountId}/parties"
  @spec list_account_parties(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_parties(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/parties")

  # ── Products ──────────────────────────────────────────────────────────────

  @doc "GET /products"
  @spec list_products(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_products(%Client{} = c), do: Client.get(c, "#{@base}/products")

  @doc "GET /accounts/{AccountId}/product"
  @spec get_account_product(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_account_product(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/product")

  # ── Offers ────────────────────────────────────────────────────────────────

  @doc "GET /offers"
  @spec list_offers(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_offers(%Client{} = c), do: Client.get(c, "#{@base}/offers")

  @doc "GET /accounts/{AccountId}/offers"
  @spec list_account_offers(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_account_offers(%Client{} = c, id),
    do: Client.get(c, "#{@base}/accounts/#{id}/offers")

  # ── Private ───────────────────────────────────────────────────────────────

  defp date_query(opts) do
    params =
      []
      |> add_param("fromBookingDateTime", Keyword.get(opts, :from_booking_date_time))
      |> add_param("toBookingDateTime", Keyword.get(opts, :to_booking_date_time))

    if params == [], do: "", else: "?" <> URI.encode_query(params)
  end

  defp add_param(p, _k, nil), do: p
  defp add_param(p, k, %DateTime{} = dt), do: [{k, DateTime.to_iso8601(dt)} | p]
  defp add_param(p, k, v), do: [{k, v} | p]
end
