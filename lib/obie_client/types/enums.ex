defmodule ObieClient.Types.Enums do
  @moduledoc """
  All OBIE v3.1.3 enumeration values as module functions.

  Values match the Namespaced Enumerations spec:
  https://openbankinguk.github.io/read-write-api-site2/
  standards/v3.1.3/references/namespaced-enumerations/
  """

  @doc "Returns all 21 AIS permission codes."
  @spec all_permissions() :: [String.t()]
  def all_permissions do
    ~w[
      ReadAccountsBasic ReadAccountsDetail ReadBalances
      ReadBeneficiariesBasic ReadBeneficiariesDetail ReadDirectDebits
      ReadOffers ReadPAN ReadParty ReadPartyPSU ReadProducts
      ReadScheduledPaymentsBasic ReadScheduledPaymentsDetail
      ReadStandingOrdersBasic ReadStandingOrdersDetail
      ReadStatementsBasic ReadStatementsDetail
      ReadTransactionsBasic ReadTransactionsCredits
      ReadTransactionsDebits ReadTransactionsDetail
    ]
  end

  @doc "Returns the 15 Detail-level permissions (recommended for most TPPs)."
  @spec detail_permissions() :: [String.t()]
  def detail_permissions do
    ~w[
      ReadAccountsDetail ReadBalances ReadBeneficiariesDetail
      ReadDirectDebits ReadOffers ReadPAN ReadParty ReadPartyPSU
      ReadProducts ReadScheduledPaymentsDetail ReadStandingOrdersDetail
      ReadStatementsDetail ReadTransactionsCredits
      ReadTransactionsDebits ReadTransactionsDetail
    ]
  end

  @terminal_payment_statuses ~w[
    AcceptedCreditSettlementCompleted AcceptedSettlementCompleted Rejected
  ]

  @doc "All payment status values."
  @spec payment_statuses() :: [String.t()]
  def payment_statuses do
    ~w[
      AcceptedCreditSettlementCompleted AcceptedSettlementCompleted
      AcceptedSettlementInProcess AcceptedWithoutPosting
      InitiationCompleted InitiationFailed InitiationPending
      Pending Rejected
    ]
  end

  @doc "Terminal payment statuses (polling stops here)."
  @spec terminal_payment_statuses() :: [String.t()]
  def terminal_payment_statuses, do: @terminal_payment_statuses

  @doc "Returns true if the payment status is terminal."
  @spec terminal_payment_status?(String.t()) :: boolean()
  def terminal_payment_status?(s), do: s in @terminal_payment_statuses

  @doc "AIS consent status values."
  @spec consent_statuses() :: [String.t()]
  def consent_statuses, do: ~w[Authorised AwaitingAuthorisation Consumed Rejected Revoked]

  @doc "File consent status values."
  @spec file_consent_statuses() :: [String.t()]
  def file_consent_statuses,
    do: ~w[AwaitingUpload AwaitingAuthorisation Authorised Consumed Rejected]

  @doc "Account type codes."
  @spec account_types() :: [String.t()]
  def account_types, do: ~w[Business Personal]

  @doc "Account sub-type codes."
  @spec account_sub_types() :: [String.t()]
  def account_sub_types do
    ~w[ChargeCard CreditCard CurrentAccount EMoney Loan Mortgage PrePaymentCard Savings]
  end

  @doc "Balance type codes."
  @spec balance_types() :: [String.t()]
  def balance_types do
    ~w[
      ClosingAvailable ClosingBooked ClosingCleared Expected ForwardAvailable
      Information InterimAvailable InterimBooked InterimCleared
      OpeningAvailable OpeningBooked OpeningCleared PreviouslyClosedBooked
    ]
  end

  @doc "Scheme name codes."
  @spec scheme_names() :: [String.t()]
  def scheme_names do
    ~w[
      UK.OBIE.SortCodeAccountNumber UK.OBIE.IBAN UK.OBIE.BBAN
      UK.OBIE.PAN UK.OBIE.GetBranchCode UK.OBIE.SWIFT UK.OBIE.BICFI
    ]
  end

  @doc "Charge bearer codes."
  @spec charge_bearers() :: [String.t()]
  def charge_bearers, do: ~w[BorneByCreditor BorneByDebtor FollowingServiceLevel Shared SLEV]

  @doc "Exchange rate type codes."
  @spec exchange_rate_types() :: [String.t()]
  def exchange_rate_types, do: ~w[Agreed Actual Indicative]

  @doc "Instruction priority codes."
  @spec instruction_priorities() :: [String.t()]
  def instruction_priorities, do: ~w[Normal Urgent]

  @doc "File type codes for file payments."
  @spec file_types() :: [String.t()]
  def file_types do
    ~w[
      UK.OBIE.PaymentInitiation.2.1
      UK.OBIE.PaymentInitiation.3.1
      UK.OBIE.pain.001.001.08
    ]
  end

  @doc "VRP type codes."
  @spec vrp_types() :: [String.t()]
  def vrp_types, do: ~w[UK.OBIE.VRPType.Sweeping UK.OBIE.VRPType.Other]

  @doc "VRP period type codes."
  @spec period_types() :: [String.t()]
  def period_types, do: ~w[Day Week Fortnight Month Half-year Year]

  @doc "VRP period alignment codes."
  @spec period_alignments() :: [String.t()]
  def period_alignments, do: ~w[Calendar Consent]

  @doc "Payment context codes."
  @spec payment_contexts() :: [String.t()]
  def payment_contexts, do: ~w[BillPayment EcommerceGoods EcommerceServices Other PartyToParty]

  @doc "Known OBIE error codes."
  @spec error_codes() :: [String.t()]
  def error_codes do
    ~w[
      UK.OBIE.Field.Expected UK.OBIE.Field.Invalid UK.OBIE.Field.InvalidDate
      UK.OBIE.Field.Missing UK.OBIE.Field.Unexpected
      UK.OBIE.Header.Invalid UK.OBIE.Header.Missing
      UK.OBIE.Param.Invalid UK.OBIE.Param.Missing UK.OBIE.Param.Unexpected
      UK.OBIE.Resource.ConsentMismatch UK.OBIE.Resource.InvalidConsentStatus
      UK.OBIE.Resource.InvalidFormat UK.OBIE.Resource.NotFound UK.OBIE.Resource.Duplicate
      UK.OBIE.Signature.Invalid UK.OBIE.Signature.Malformed UK.OBIE.Signature.Missing
      UK.OBIE.Unexpected.Error UK.OBIE.NotAuthorised
      UK.OBIE.Rules.AfterCutOffDateTime UK.OBIE.Rules.DuplicateReference
    ]
  end

  @doc "Standing order frequency codes."
  @spec frequencies() :: [String.t()]
  def frequencies do
    ~w[EvryDay EvryWorkgDay IntrvlDay IntrvlWkDay WkInMnthDay IntrvlMnthDay QtrDay]
  end
end
