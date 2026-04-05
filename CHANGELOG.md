# Changelog

All notable changes to this project will be documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] — 2026-01-01

### Added

**Core infrastructure**
- `ObieClient.Client` — `Req`-based HTTP pipeline with mandatory FAPI headers on every request, exponential backoff with crypto-random jitter, `Retry-After` header parsing for 429 responses, circuit-breaker and rate-limiter integration, JWS signature injection, mTLS transport setup, structured telemetry emission
- `ObieClient.Config` — configuration struct with `{:system, "ENV_VAR"}` runtime secret resolution, environment defaulting, and validation
- `ObieClient.Error` — structured exception with `has_code?/2` and `retryable?/1`
- `ObieClient.Application` — OTP supervisor tree

**AIS (Account Information Service)**
- `ObieClient.AISP.Consent` — account-access-consent lifecycle: `create/3`, `get/2`, `delete/2`, `poll_until_authorised/3`
- `ObieClient.Accounts` — all 13 AIS resource types with bulk and per-account variants:
  - accounts (`list/1`, `get/2`)
  - balances (`list_balances/1`, `list_account_balances/2`)
  - transactions with date filters (`list_transactions/2`, `list_account_transactions/3`)
  - beneficiaries, direct debits, standing orders, scheduled payments
  - statements including per-statement transactions and bulk statement transactions (`list_statement_transactions_bulk/2`)
  - parties (`get_party/1`, `get_account_party/2`, `list_account_parties/2`)
  - products, offers

**PIS (Payment Initiation Service)**
- `ObieClient.Payments` — all 6 payment types, each with full lifecycle (consent create/get/delete, funds-confirmation where applicable, submit, get, payment-details, poll-until-terminal):
  - Domestic payments
  - Domestic scheduled payments
  - Domestic standing orders
  - International payments
  - International scheduled payments
  - International standing orders

**CBPII**
- `ObieClient.Funds` — funds-confirmation-consent (POST/GET/DELETE) + `confirm/4`

**VRP**
- `ObieClient.VRP` — consent lifecycle, funds confirmation, submit, get, payment-details, `poll/3`

**File Payments**
- `ObieClient.FilePayments` — consent, file upload (`upload_file/4`), file download, submit, get, payment-details, report download (`get_report/2`), `poll/3`

**Event Notifications**
- `ObieClient.EventNotifications` — subscriptions (POST/GET/PUT/DELETE), callback URLs (POST/GET/PUT/DELETE), aggregated polling (`poll_events/4`)
- `ObieClient.Events.Handler` — real-time webhook handler with JWS signature verification, per-event-type dispatch, Plug-compatible factory function (`plug/1`)

**Auth**
- `ObieClient.Auth.TokenManager` — GenServer-based OAuth2 client-credentials cache with 30-second refresh buffer, using `private_key_jwt`
- `ObieClient.Auth.JWT` — RS256 `client_assertion` builder via Joken, RSA key parsing (PKCS#1 + PKCS#8)
- `ObieClient.Auth.MTLS` — mTLS SSL options from PEM cert/key

**Signing**
- `ObieClient.Signing.JWS` — detached JWS per OBIE signing profile (`b64=false`, `crit=["b64"]`), with `verify/3`

**Resilience**
- `ObieClient.CircuitBreaker` — ETS-backed Closed/Open/HalfOpen with 5-failure threshold, 30-second open timeout, 2-success close threshold
- `ObieClient.RateLimiter` — token-bucket ETS rate limiter (50-request burst, 10 req/s refill)
- `ObieClient.Cache` — ETS TTL cache with background eviction, `get_or_put/3`, prefix invalidation

**Utilities**
- `ObieClient.Telemetry` — structured `:telemetry` events for request start/stop/exception, token fetch, circuit-breaker state changes
- `ObieClient.Pagination` — lazy HATEOAS `Stream` via `stream/2` and eager `all_pages/2`
- `ObieClient.Validation` — deep client-side validation for amounts, accounts, permissions, domestic initiations, VRP control parameters
- `ObieClient.Types.Enums` — all 30+ OBIE v3.1.3 enumeration values
- `ObieClient.Types.Common` — shared struct types (Amount, CashAccount, Links, Risk, etc.)

[1.0.0]: https://github.com/iamkanishka/obie_client/releases/tag/v1.0.0
