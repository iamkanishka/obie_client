defmodule ObieClient.Test.Factory do
  @moduledoc "Test data factories for OBIE request and response maps."

  alias ObieClient.Types.Enums

  def token_response(overrides \\ %{}) do
    Map.merge(
      %{
        "access_token" => "test-token-#{:rand.uniform(999_999)}",
        "token_type" => "Bearer",
        "expires_in" => 3600,
        "scope" => "accounts payments fundsconfirmations"
      },
      overrides
    )
  end

  def consent_response(overrides \\ %{}) do
    deep_merge(
      %{
        "Data" => %{
          "ConsentId" => "urn-test-intent-#{:rand.uniform(999_999)}",
          "Status" => "AwaitingAuthorisation",
          "CreationDateTime" => "2024-01-01T00:00:00Z",
          "StatusUpdateDateTime" => "2024-01-01T00:00:00Z",
          "Permissions" => Enums.detail_permissions()
        },
        "Risk" => %{},
        "Links" => %{"Self" => "https://aspsp.example.com/account-access-consents/1"},
        "Meta" => %{"TotalPages" => 1}
      },
      overrides
    )
  end

  def account_response(overrides \\ %{}) do
    deep_merge(
      %{
        "Data" => %{
          "Account" => [
            %{
              "AccountId" => "acc-001",
              "Currency" => "GBP",
              "AccountType" => "Personal",
              "AccountSubType" => "CurrentAccount",
              "Status" => "Enabled",
              "Account" => [
                %{
                  "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                  "Identification" => "20201733115521",
                  "Name" => "Test Account"
                }
              ]
            }
          ]
        },
        "Links" => %{"Self" => "https://aspsp.example.com/accounts"},
        "Meta" => %{"TotalPages" => 1}
      },
      overrides
    )
  end

  def balance_response(overrides \\ %{}) do
    deep_merge(
      %{
        "Data" => %{
          "Balance" => [
            %{
              "AccountId" => "acc-001",
              "Amount" => %{"Amount" => "1000.00", "Currency" => "GBP"},
              "CreditDebitIndicator" => "Credit",
              "Type" => "InterimAvailable",
              "DateTime" => "2024-01-01T00:00:00Z"
            }
          ]
        },
        "Links" => %{"Self" => "https://aspsp.example.com/balances"},
        "Meta" => %{"TotalPages" => 1}
      },
      overrides
    )
  end

  def transaction_response(overrides \\ %{}) do
    deep_merge(
      %{
        "Data" => %{
          "Transaction" => [
            %{
              "AccountId" => "acc-001",
              "TransactionId" => "txn-001",
              "Amount" => %{"Amount" => "25.00", "Currency" => "GBP"},
              "CreditDebitIndicator" => "Debit",
              "Status" => "Booked",
              "BookingDateTime" => "2024-01-01T10:00:00Z"
            }
          ]
        },
        "Links" => %{"Self" => "https://aspsp.example.com/transactions"},
        "Meta" => %{"TotalPages" => 1}
      },
      overrides
    )
  end

  def domestic_payment_consent_response(overrides \\ %{}) do
    deep_merge(
      %{
        "Data" => %{
          "ConsentId" => "pmt-consent-#{:rand.uniform(999_999)}",
          "Status" => "AwaitingAuthorisation",
          "CreationDateTime" => "2024-01-01T00:00:00Z",
          "StatusUpdateDateTime" => "2024-01-01T00:00:00Z",
          "Initiation" => domestic_initiation()
        },
        "Risk" => %{},
        "Links" => %{"Self" => "https://aspsp.example.com/domestic-payment-consents/c1"},
        "Meta" => %{"TotalPages" => 1}
      },
      overrides
    )
  end

  def domestic_payment_response(status \\ "AcceptedSettlementInProcess") do
    %{
      "Data" => %{
        "DomesticPaymentId" => "pmt-#{:rand.uniform(999_999)}",
        "ConsentId" => "pmt-consent-001",
        "Status" => status,
        "CreationDateTime" => "2024-01-01T00:00:00Z",
        "StatusUpdateDateTime" => "2024-01-01T00:00:01Z",
        "Initiation" => domestic_initiation()
      },
      "Links" => %{"Self" => "https://aspsp.example.com/domestic-payments/p1"},
      "Meta" => %{}
    }
  end

  def domestic_initiation do
    %{
      "InstructionIdentification" => "INSTR-001",
      "EndToEndIdentification" => "E2E-001",
      "InstructedAmount" => %{"Amount" => "10.50", "Currency" => "GBP"},
      "CreditorAccount" => %{
        "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
        "Identification" => "20000319825731",
        "Name" => "Test Recipient"
      }
    }
  end

  def funds_confirmation_response(available \\ true) do
    %{
      "Data" => %{
        "FundsAvailableResult" => %{
          "FundsAvailableDateTime" => "2024-01-01T00:00:00Z",
          "FundsAvailable" => available
        }
      },
      "Links" => %{"Self" => "https://aspsp.example.com/funds-confirmations/1"},
      "Meta" => %{}
    }
  end

  # Stub config for tests using Bypass
  def test_config(bypass, overrides \\ []) do
    base_url = "http://localhost:#{bypass.port}"

    Bypass.stub(bypass, "POST", "/token", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(token_response()))
    end)

    defaults = [
      client_id: "test-client",
      token_url: "#{base_url}/token",
      private_key_pem: fake_pem(),
      signing_key_id: "test-kid",
      base_url: base_url
    ]

    {:ok, config} = ObieClient.Config.new(Keyword.merge(defaults, overrides))
    config
  end

  def fake_pem do
    # Minimal PEM stub — token manager will fail to sign assertions in unit tests
    # (that's fine; we stub the token endpoint with Bypass)
    """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4PAtEsHAolCCBq9AMDM4eFGEXoC
    kFiRRSJSdCTzqkMiQSnFHy9ZAFvjVPq3q5w6j+2o0i6zFNMFLBQ8rFfgvJgN6rK
    ZV1hF+jz5c4g9h47qOV9sYYJLQm8x1YzJm7ggN+2wPDMJBmNqU3bHFKfS+d...
    -----END RSA PRIVATE KEY-----
    """
  end

  defp deep_merge(base, overrides) when is_map(base) and is_map(overrides) do
    Map.merge(base, overrides, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2), do: deep_merge(v1, v2), else: v2
    end)
  end
end
