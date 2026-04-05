defmodule ObieClient.ValidationTest do
  use ExUnit.Case, async: true

  alias ObieClient.Types.Enums
  alias ObieClient.Validation

  describe "validate_amount/2" do
    test "accepts valid GBP amount" do
      assert :ok = Validation.validate_amount(%{"Amount" => "10.50", "Currency" => "GBP"}, "f")
    end

    test "accepts whole number amount" do
      assert :ok = Validation.validate_amount(%{"Amount" => "100", "Currency" => "GBP"}, "f")
    end

    test "accepts maximum 5 decimal places" do
      assert :ok = Validation.validate_amount(%{"Amount" => "10.12345", "Currency" => "GBP"}, "f")
    end

    test "rejects 6+ decimal places" do
      assert {:error, msg} =
               Validation.validate_amount(%{"Amount" => "10.123456", "Currency" => "GBP"}, "f")

      assert msg =~ "Amount"
    end

    test "rejects non-numeric amount" do
      assert {:error, _} =
               Validation.validate_amount(%{"Amount" => "ten", "Currency" => "GBP"}, "f")
    end

    test "rejects lowercase currency code" do
      assert {:error, msg} =
               Validation.validate_amount(%{"Amount" => "10.00", "Currency" => "gbp"}, "f")

      assert msg =~ "Currency"
    end

    test "rejects 4-letter currency code" do
      assert {:error, _} =
               Validation.validate_amount(%{"Amount" => "10.00", "Currency" => "GBPS"}, "f")
    end

    test "rejects missing Amount key" do
      assert {:error, _} = Validation.validate_amount(%{"Currency" => "GBP"}, "f")
    end

    test "rejects missing Currency key" do
      assert {:error, _} = Validation.validate_amount(%{"Amount" => "10.00"}, "f")
    end
  end

  describe "validate_account/2" do
    test "accepts valid sort-code account number (14 digits)" do
      assert :ok =
               Validation.validate_account(
                 %{
                   "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                   "Identification" => "20000319825731"
                 },
                 "CreditorAccount"
               )
    end

    test "accepts sort-code with dashes stripped" do
      assert :ok =
               Validation.validate_account(
                 %{
                   "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                   "Identification" => "200003-19825731"
                 },
                 "CreditorAccount"
               )
    end

    test "rejects sort-code shorter than 14 digits" do
      assert {:error, msg} =
               Validation.validate_account(
                 %{
                   "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
                   "Identification" => "12345678"
                 },
                 "CreditorAccount"
               )

      assert msg =~ "14 digits"
    end

    test "accepts valid GB IBAN" do
      assert :ok =
               Validation.validate_account(
                 %{"SchemeName" => "UK.OBIE.IBAN", "Identification" => "GB29NWBK60161331926819"},
                 "CreditorAccount"
               )
    end

    test "rejects malformed IBAN (no country code)" do
      assert {:error, _} =
               Validation.validate_account(
                 %{"SchemeName" => "UK.OBIE.IBAN", "Identification" => "12345678901234"},
                 "CreditorAccount"
               )
    end

    test "accepts other scheme names with non-empty identification" do
      assert :ok =
               Validation.validate_account(
                 %{"SchemeName" => "UK.OBIE.BBAN", "Identification" => "12345678901234"},
                 "CreditorAccount"
               )
    end

    test "rejects missing Identification" do
      assert {:error, _} =
               Validation.validate_account(
                 %{"SchemeName" => "UK.OBIE.SortCodeAccountNumber"},
                 "CreditorAccount"
               )
    end
  end

  describe "validate_permissions/1" do
    test "accepts all known permissions" do
      assert :ok = Validation.validate_permissions(Enums.all_permissions())
    end

    test "accepts subset of permissions" do
      assert :ok = Validation.validate_permissions(["ReadBalances", "ReadTransactionsDetail"])
    end

    test "rejects empty list" do
      assert {:error, msg} = Validation.validate_permissions([])
      assert msg =~ "empty"
    end

    test "rejects unknown permission codes" do
      assert {:error, msg} = Validation.validate_permissions(["ReadEverything", "WriteData"])
      assert msg =~ "ReadEverything"
    end
  end

  describe "validate_domestic_initiation/1" do
    @valid_init %{
      "InstructionIdentification" => "INSTR-001",
      "EndToEndIdentification" => "E2E-001",
      "InstructedAmount" => %{"Amount" => "10.50", "Currency" => "GBP"},
      "CreditorAccount" => %{
        "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
        "Identification" => "20000319825731"
      }
    }

    test "accepts valid initiation" do
      assert {:ok, init} = Validation.validate_domestic_initiation(@valid_init)
      assert init == @valid_init
    end

    test "returns errors for completely empty map" do
      assert {:error, errors} = Validation.validate_domestic_initiation(%{})
      assert errors != []
    end

    test "catches missing InstructionIdentification" do
      bad = Map.delete(@valid_init, "InstructionIdentification")
      assert {:error, errors} = Validation.validate_domestic_initiation(bad)
      assert Enum.any?(errors, &String.contains?(&1, "InstructionIdentification"))
    end

    test "catches invalid amount" do
      bad = put_in(@valid_init, ["InstructedAmount", "Amount"], "not-a-number")
      assert {:error, errors} = Validation.validate_domestic_initiation(bad)
      assert Enum.any?(errors, &String.contains?(&1, "Amount"))
    end

    test "catches invalid creditor account" do
      bad = put_in(@valid_init, ["CreditorAccount", "Identification"], "12345")
      assert {:error, errors} = Validation.validate_domestic_initiation(bad)
      assert Enum.any?(errors, &String.contains?(&1, "CreditorAccount"))
    end
  end

  describe "validate_vrp_control_parameters/1" do
    test "accepts valid control parameters" do
      params = %{
        "MaximumIndividualAmount" => %{"Amount" => "500.00", "Currency" => "GBP"},
        "PeriodicLimits" => [
          %{
            "PeriodType" => "Month",
            "PeriodAlignment" => "Calendar",
            "Amount" => %{"Amount" => "2000.00", "Currency" => "GBP"}
          }
        ]
      }

      assert {:ok, _} = Validation.validate_vrp_control_parameters(params)
    end

    test "rejects invalid period type" do
      params = %{
        "MaximumIndividualAmount" => %{"Amount" => "500.00", "Currency" => "GBP"},
        "PeriodicLimits" => [
          %{
            "PeriodType" => "Millennium",
            "Amount" => %{"Amount" => "2000.00", "Currency" => "GBP"}
          }
        ]
      }

      assert {:error, errors} = Validation.validate_vrp_control_parameters(params)
      assert Enum.any?(errors, &String.contains?(&1, "Millennium"))
    end

    test "rejects empty PeriodicLimits" do
      params = %{
        "MaximumIndividualAmount" => %{"Amount" => "500.00", "Currency" => "GBP"},
        "PeriodicLimits" => []
      }

      assert {:error, errors} = Validation.validate_vrp_control_parameters(params)
      assert Enum.any?(errors, &String.contains?(&1, "PeriodicLimits"))
    end
  end
end
