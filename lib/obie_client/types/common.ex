defmodule ObieClient.Types.Common do
  @moduledoc "Shared OBIE v3.1.3 data structures used across all resource types."

  defmodule Amount do
    @moduledoc "OBActiveOrHistoricCurrencyAndAmount — amount + ISO 4217 currency."
    @enforce_keys [:amount, :currency]
    defstruct [:amount, :currency]
    @type t :: %__MODULE__{amount: String.t(), currency: String.t()}

    @doc "Builds from a map with `Amount` and `Currency` keys."
    @spec from_map(map()) :: t()
    def from_map(%{"Amount" => a, "Currency" => c}), do: %__MODULE__{amount: a, currency: c}

    @doc "Serialises to the OBIE JSON map shape."
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{amount: a, currency: c}), do: %{"Amount" => a, "Currency" => c}
  end

  defmodule CashAccount do
    @moduledoc "OBCashAccount3 — account identification block."
    @enforce_keys [:scheme_name, :identification]
    defstruct [:scheme_name, :identification, :name, :secondary_identification]

    @type t :: %__MODULE__{
            scheme_name: String.t(),
            identification: String.t(),
            name: String.t() | nil,
            secondary_identification: String.t() | nil
          }

    @doc "Builds a UK sort-code-account-number cash account map."
    @spec sort_code_account(String.t(), String.t()) :: map()
    def sort_code_account(identification, name) do
      %{
        "SchemeName" => "UK.OBIE.SortCodeAccountNumber",
        "Identification" => identification,
        "Name" => name
      }
    end

    @doc "Builds an IBAN cash account map."
    @spec iban(String.t(), String.t()) :: map()
    def iban(iban, name) do
      %{"SchemeName" => "UK.OBIE.IBAN", "Identification" => iban, "Name" => name}
    end
  end

  defmodule Links do
    @moduledoc "HATEOAS navigation links."
    defstruct [:self, :first, :prev, :next, :last]

    @type t :: %__MODULE__{
            self: String.t(),
            first: String.t() | nil,
            prev: String.t() | nil,
            next: String.t() | nil,
            last: String.t() | nil
          }

    @doc "Returns the next-page URL, or nil."
    @spec next_url(map()) :: String.t() | nil
    def next_url(%{"Links" => %{"Next" => url}}) when is_binary(url) and url != "", do: url
    def next_url(_), do: nil
  end

  defmodule Risk do
    @moduledoc "OBRisk1 — payment risk information."
    defstruct [
      :payment_context_code,
      :merchant_category_code,
      :merchant_customer_identification,
      :delivery_address
    ]
  end

  defmodule RemittanceInformation do
    @moduledoc "OBRemittanceInformation1."
    defstruct [:unstructured, :reference]

    @type t :: %__MODULE__{
            unstructured: String.t() | nil,
            reference: String.t() | nil
          }

    @doc "Builds the OBIE map shape."
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{unstructured: u, reference: r}) do
      %{}
      |> then(fn m -> if u, do: Map.put(m, "Unstructured", u), else: m end)
      |> then(fn m -> if r, do: Map.put(m, "Reference", r), else: m end)
    end
  end

  defmodule ExchangeRate do
    @moduledoc "OBExchangeRate1 — exchange rate for international payments."
    @enforce_keys [:unit_currency, :rate_type]
    defstruct [
      :unit_currency,
      :rate_type,
      :exchange_rate,
      :contract_identification,
      :expiration_date_time
    ]
  end
end
