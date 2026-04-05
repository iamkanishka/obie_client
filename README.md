# ObieClient

[![Hex.pm](https://img.shields.io/hexpm/v/obie_client.svg)](https://hex.pm/packages/obie_client)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/obie_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Elixir CI](https://github.com/iamkanishka/obie_client/actions/workflows/ci.yml/badge.svg)](https://github.com/iamkanishka/obie_client/actions)

Production-grade Elixir client for the **UK Open Banking (OBIE) Read/Write API v3.1.3**.

---

## Coverage

| API | Coverage |
|-----|----------|
| **AIS** — Account Information | Consents + 13 resource types (accounts, balances, transactions, beneficiaries, direct debits, standing orders, scheduled payments, statements, parties, products, offers) — bulk and per-account |
| **PIS** — Payment Initiation | All 6 types (domestic, scheduled, standing order, international × 3) × full lifecycle |
| **CBPII** — Funds Confirmation | Consent lifecycle + funds check |
| **VRP** — Variable Recurring | Consent, funds confirmation, payment submit/poll |
| **File Payments** | Consent, upload, download, submit, report |
| **Event Notifications** | Subscriptions, callback URLs, aggregated polling, real-time webhook handler |

---

## Installation

```elixir
# mix.exs
def deps do
  [{:obie_client, "~> 1.0"}]
end
```

---

## Configuration

### Runtime config (recommended)

```elixir
# config/runtime.exs
import Config

config :obie_client,
  client_id:       System.fetch_env!("OBIE_CLIENT_ID"),
  token_url:       System.fetch_env!("OBIE_TOKEN_URL"),
  private_key_pem: File.read!(System.fetch_env!("OBIE_KEY_PATH")),
  certificate_pem: File.read!(System.fetch_env!("OBIE_CERT_PATH")),  # mTLS
  signing_key_id:  System.fetch_env!("OBIE_SIGNING_KID"),
  financial_id:    System.fetch_env!("OBIE_FINANCIAL_ID"),
  environment:     :production,
  timeout:         30_000,
  max_retries:     3
```

Or use `{:system, "VAR"}` tuples in compile-time config:

```elixir
# config/config.exs
config :obie_client, private_key_pem: {:system, "OBIE_PRIVATE_KEY_PEM"}
```

### Programmatic config

```elixir
{:ok, client} = ObieClient.new_client(
  client_id:       "my-client-id",
  token_url:       "https://aspsp.example.com/token",
  private_key_pem: File.read!("private.pem"),
  signing_key_id:  "key-2025",
  financial_id:    "0015800001041RHAAY",
  environment:     :sandbox
)
```

---

## Usage

### AIS — read account data

```elixir
{:ok, client} = ObieClient.new_client()

# 1. Create consent
{:ok, consent} = ObieClient.AISP.Consent.create(client,
  ObieClient.Types.Enums.detail_permissions(),
  expiration_date_time: DateTime.add(DateTime.utc_now(), 90, :day))

consent_id = consent["Data"]["ConsentId"]
# => "urn-alphabank-intent-88379"

# 2. Redirect PSU to ASPSP for authorisation …

# 3. Poll until Authorised
{:ok, _} = ObieClient.AISP.Consent.poll_until_authorised(client, consent_id,
  interval_ms: 2_000, timeout_ms: 120_000)

# 4. Read accounts and balances
{:ok, %{"Data" => %{"Account" => accounts}}} = ObieClient.Accounts.list(client)
account_id = hd(accounts)["AccountId"]

{:ok, balances}     = ObieClient.Accounts.list_account_balances(client, account_id)
{:ok, transactions} = ObieClient.Accounts.list_account_transactions(client, account_id,
  from_booking_date_time: ~U[2024-01-01 00:00:00Z])
```

### Paginate large result sets

```elixir
# Lazy stream — fetches next page only when needed
all_transactions =
  client
  |> ObieClient.Pagination.stream(&ObieClient.Accounts.list_transactions/1)
  |> Stream.flat_map(fn page -> page["Data"]["Transaction"] || [] end)
  |> Enum.to_list()

# Eager — all pages at once
{:ok, pages} = ObieClient.Pagination.all_pages(client, &ObieClient.Accounts.list_statements/1)
```

### PIS — domestic payment

```elixir
initiation = %{
  "InstructionIdentification" => "INSTR-#{Uniq.UUID.uuid4()}",
  "EndToEndIdentification"    => "E2E-#{Uniq.UUID.uuid4()}",
  "InstructedAmount"          => %{"Amount" => "10.50", "Currency" => "GBP"},
  "CreditorAccount"           => %{
    "SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
    "Identification" => "20000319825731",
    "Name"           => "Beneficiary Name"
  }
}

# Create consent
{:ok, consent} = ObieClient.Payments.create_domestic_consent(client, initiation)
consent_id = consent["Data"]["ConsentId"]

# … PSU authorises at ASPSP …

# Submit payment
{:ok, payment} = ObieClient.Payments.submit_domestic(client, consent_id, initiation)
payment_id = payment["Data"]["DomesticPaymentId"]

# Poll until settled
{:ok, %{"Data" => %{"Status" => "AcceptedSettlementCompleted"}}} =
  ObieClient.Payments.poll_domestic(client, payment_id,
    interval_ms: 5_000, timeout_ms: 300_000)
```

### VRP

```elixir
{:ok, consent} = ObieClient.VRP.create_consent(client, %{
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
    "DebtorAccount"   => %{"SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                           "Identification" => "11223321325698"},
    "CreditorAccount" => %{"SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                           "Identification" => "30080012343456", "Name" => "Savings"}
  }
})

# After PSU authorises …
{:ok, payment} = ObieClient.VRP.submit(client, consent["Data"]["ConsentId"], %{
  "InstructionIdentification" => Uniq.UUID.uuid4(),
  "EndToEndIdentification"    => Uniq.UUID.uuid4(),
  "InstructedAmount"          => %{"Amount" => "100.00", "Currency" => "GBP"},
  "CreditorAccount"           => %{"SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
                                   "Identification" => "30080012343456", "Name" => "Savings"}
})
```

### CBPII — funds confirmation

```elixir
{:ok, consent} = ObieClient.Funds.create_consent(client, %{
  "DebtorAccount" => %{
    "SchemeName"     => "UK.OBIE.SortCodeAccountNumber",
    "Identification" => "20000319825731"
  },
  "ExpirationDateTime" => DateTime.add(DateTime.utc_now(), 90, :day) |> DateTime.to_iso8601()
})

# After PSU authorises …
{:ok, result} = ObieClient.Funds.confirm(client, consent["Data"]["ConsentId"],
  "ref-001", %{"Amount" => "150.00", "Currency" => "GBP"})

result["Data"]["FundsAvailableResult"]["FundsAvailable"]  # => true
```

### File payments

```elixir
file_bytes = File.read!("payments.json")
hash = Base.encode64(:crypto.hash(:sha256, file_bytes))

{:ok, consent} = ObieClient.FilePayments.create_consent(client, %{
  "FileType"               => "UK.OBIE.PaymentInitiation.3.1",
  "FileHash"               => hash,
  "NumberOfTransactions"   => "10",
  "ControlSum"             => 15_000.0
})

:ok = ObieClient.FilePayments.upload_file(client, consent["Data"]["ConsentId"],
  file_bytes, "application/json")

# After PSU authorises …
{:ok, payment}  = ObieClient.FilePayments.submit(client, consent["Data"]["ConsentId"], initiation)
{:ok, _settled} = ObieClient.FilePayments.poll(client, payment["Data"]["FilePaymentId"])
{:ok, report, _content_type} = ObieClient.FilePayments.get_report(client, payment["Data"]["FilePaymentId"])
```

### Real-time webhook events

```elixir
# Plug/Phoenix router
post "/webhooks/obie", ObieClient.Events.Handler.plug(
  aspsp_public_key_pem: File.read!("aspsp_signing_public.pem"),
  on_event: fn event ->
    MyApp.process_event(event["jti"], event["events"])
  end,
  on_error: fn reason ->
    Logger.error("OBIE webhook: #{inspect(reason)}")
  end
)
```

### Event subscriptions

```elixir
# Register a push callback URL
{:ok, sub} = ObieClient.EventNotifications.create_subscription(client,
  callback_url: "https://tpp.example.com/events",
  version: "3.1",
  event_types: [
    "urn:uk:org:openbanking:events:resource-update",
    "urn:uk:org:openbanking:events:consent-authorization-revoked"
  ])

# Aggregated polling (if no push)
{:ok, %{"sets" => sets, "moreAvailable" => more}} =
  ObieClient.EventNotifications.poll_events(client, [], %{}, max_events: 20)

# Acknowledge
acked = Map.keys(sets)
{:ok, _} = ObieClient.EventNotifications.poll_events(client, acked, %{})
```

---

## Error handling

All functions return `{:ok, result}` or `{:error, reason}`.

```elixir
case ObieClient.Accounts.list(client) do
  {:ok, result} ->
    result["Data"]["Account"]

  {:error, %ObieClient.Error{status: 401}} ->
    reauthenticate()

  {:error, %ObieClient.Error{status: 429}} ->
    # Already retried internally; caller should back off
    {:error, :rate_limited}

  {:error, %ObieClient.Error{} = err} ->
    if ObieClient.Error.has_code?(err, "UK.OBIE.Resource.NotFound") do
      nil
    else
      Logger.error(Exception.message(err))
      {:error, err}
    end

  {:error, {:transport_error, _}} ->
    {:error, :aspsp_unavailable}
end
```

---

## Client-side validation

Validate requests before sending to catch errors early:

```elixir
with {:ok, initiation} <- ObieClient.Validation.validate_domestic_initiation(init),
     :ok <- ObieClient.Validation.validate_permissions(perms) do
  ObieClient.Payments.create_domestic_consent(client, initiation)
end
```

---

## Telemetry

```elixir
# Attach to all OBIE request events
:telemetry.attach_many("my-obie-handler",
  [
    [:obie_client, :request, :start],
    [:obie_client, :request, :stop],
    [:obie_client, :request, :exception],
    [:obie_client, :circuit_breaker, :state_change]
  ],
  fn event, measurements, metadata, _cfg ->
    Logger.debug("[OBIE] #{inspect(event)} #{inspect(metadata)}")
  end,
  nil
)

# With Telemetry.Metrics
def metrics do
  [
    Telemetry.Metrics.summary("obie_client.request.stop.duration",
      tags: [:method, :status], unit: {:native, :millisecond}),
    Telemetry.Metrics.counter("obie_client.request.exception.count",
      tags: [:method])
  ]
end
```

---

## Resilience features

| Feature | Default | Behaviour |
|---------|---------|-----------|
| **Retry** | 3 retries | Exponential backoff with ±25% crypto-random jitter; 5xx + transport errors on idempotent methods |
| **Rate limiter** | 50-token burst, 10 req/s | Returns `{:error, :rate_limited}` when exhausted |
| **Circuit breaker** | 5 failures opens, 30 s timeout | `{:error, :circuit_open}` when open; auto-probes after timeout |
| **mTLS** | Configured by `certificate_pem` | All ASPSP connections use the OBWAC transport cert |
| **Token cache** | Refreshed 30 s before expiry | Zero latency on every API call after first token fetch |

---

## Architecture

```
ObieClient
├── Client              Req + FAPI headers + auth + retry pipeline
│   ├── Auth.TokenManager  OAuth2 GenServer token cache
│   ├── CircuitBreaker  ETS state machine
│   └── RateLimiter     ETS token bucket
├── AISP.Consent        AIS consent lifecycle
├── Accounts            13 AIS resource endpoints (26 functions)
├── Payments            6 PIS payment types (40+ functions)
├── FilePayments        Bulk file payment flow
├── Funds               CBPII
├── VRP                 Variable recurring payments
├── EventNotifications  Subscriptions, callbacks, polling
├── Events.Handler      Webhook handler + Plug factory
├── Auth.JWT            RS256 client_assertion (Joken)
├── Auth.MTLS           mTLS SSL options (:public_key OTP)
├── Signing.JWS         Detached JWS (OBIE b64=false)
├── Cache               ETS TTL cache
├── Pagination          Lazy HATEOAS Stream
├── Validation          Client-side request validation
├── Telemetry           :telemetry emission
└── Types               Enums, common structs
```

---

## Requirements

- Elixir `~> 1.15`
- Erlang/OTP `~> 26`

---

## License

MIT — see [LICENSE](LICENSE).
