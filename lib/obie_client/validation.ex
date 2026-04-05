defmodule ObieClient.Validation do
  alias ObieClient.Types.Enums

  @moduledoc """
  Client-side validation of OBIE request maps.

  Catching errors before sending avoids unnecessary round-trips and gives
  richer messages than a raw HTTP 400 from an ASPSP.

  All functions return `:ok` or `{:error, reason | [reason]}`.
  """

  @amount_re ~r/^\d{1,13}(\.\d{1,5})?$/
  @iso4217_re ~r/^[A-Z]{3}$/
  # sort-code(6) + account-number(8)
  @scan_re ~r/^\d{14}$/
  @iban_re ~r/^[A-Z]{2}\d{2}[A-Z0-9]{1,30}$/

  @doc """
  Validates an amount map: `%{"Amount" => "10.50", "Currency" => "GBP"}`.

  Returns `:ok` or `{:error, message}`.
  """
  @spec validate_amount(map(), String.t()) :: :ok | {:error, String.t()}
  def validate_amount(%{"Amount" => amount, "Currency" => currency}, field) do
    cond do
      not Regex.match?(@amount_re, to_string(amount)) ->
        {:error, "#{field}.Amount: must match format 0..13 digits with up to 5 decimal places"}

      not Regex.match?(@iso4217_re, to_string(currency)) ->
        {:error, "#{field}.Currency: must be a 3-letter ISO 4217 code, got #{inspect(currency)}"}

      true ->
        :ok
    end
  end

  def validate_amount(_, field), do: {:error, "#{field}: must contain Amount and Currency"}

  @doc "Validates an account identification block."
  @spec validate_account(map(), String.t()) :: :ok | {:error, String.t()}
  def validate_account(%{"SchemeName" => scheme, "Identification" => id}, field) do
    case scheme do
      "UK.OBIE.SortCodeAccountNumber" ->
        digits = String.replace(id, ["-", " "], "")

        if Regex.match?(@scan_re, digits),
          do: :ok,
          else:
            {:error,
             "#{field}: SortCodeAccountNumber must be 14 digits (sort code + account number)"}

      "UK.OBIE.IBAN" ->
        if Regex.match?(@iban_re, id),
          do: :ok,
          else: {:error, "#{field}: invalid IBAN format"}

      _ ->
        if String.length(id) > 0,
          do: :ok,
          else: {:error, "#{field}: Identification must not be empty"}
    end
  end

  def validate_account(_, field),
    do: {:error, "#{field}: must contain SchemeName and Identification"}

  @doc "Validates a list of AIS permission strings."
  @spec validate_permissions([String.t()]) :: :ok | {:error, String.t()}
  def validate_permissions([]),
    do: {:error, "permissions: list must not be empty"}

  def validate_permissions(perms) do
    known = Enums.all_permissions()
    unknown = Enum.reject(perms, &(&1 in known))

    if unknown == [],
      do: :ok,
      else: {:error, "permissions: unknown values: #{Enum.join(unknown, ", ")}"}
  end

  @doc """
  Validates a domestic payment initiation map.

  Returns `{:ok, initiation}` or `{:error, [error_string]}`.
  """
  @spec validate_domestic_initiation(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_domestic_initiation(init) do
    errors =
      []
      |> check_length(init, "InstructionIdentification", 1, 35)
      |> check_length(init, "EndToEndIdentification", 1, 35)
      |> check_amount_field(init, "InstructedAmount")
      |> check_account_field(init, "CreditorAccount")

    if errors == [], do: {:ok, init}, else: {:error, Enum.reverse(errors)}
  end

  @doc """
  Validates VRP control parameters.

  Returns `{:ok, params}` or `{:error, [error_string]}`.
  """
  @spec validate_vrp_control_parameters(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_vrp_control_parameters(params) do
    errors =
      []
      |> check_amount_field(params, "MaximumIndividualAmount")
      |> check_vrp_periodic_limits(params)

    if errors == [], do: {:ok, params}, else: {:error, Enum.reverse(errors)}
  end

  # ── Private ──────────────────────────────────────────────────────────────

  defp check_length(errors, map, field, min, max) do
    val = to_string(map[field] || "")
    len = String.length(val)

    cond do
      len == 0 -> ["#{field}: is required" | errors]
      len < min -> ["#{field}: minimum length #{min}, got #{len}" | errors]
      len > max -> ["#{field}: maximum length #{max}, got #{len}" | errors]
      true -> errors
    end
  end

  defp check_amount_field(errors, map, field) do
    case validate_amount(map[field] || %{}, field) do
      :ok -> errors
      {:error, msg} -> [msg | errors]
    end
  end

  defp check_account_field(errors, map, field) do
    case validate_account(map[field] || %{}, field) do
      :ok -> errors
      {:error, msg} -> [msg | errors]
    end
  end

  defp check_vrp_periodic_limits(errors, %{"PeriodicLimits" => []}),
    do: ["PeriodicLimits: must have at least one entry" | errors]

  defp check_vrp_periodic_limits(errors, %{"PeriodicLimits" => limits})
       when is_list(limits) do
    Enum.reduce(limits, errors, &check_periodic_limit(&1, &2, Enums.period_types()))
  end

  defp check_vrp_periodic_limits(errors, _), do: errors

  defp check_periodic_limit(limit, acc, valid) do
    acc
    |> validate_period_type(limit["PeriodType"], valid)
    |> check_amount_field(limit, "Amount")
  end

  defp validate_period_type(acc, period, valid) do
    if period in valid do
      acc
    else
      ["PeriodicLimits[PeriodType]: #{inspect(period)} is not a valid period type" | acc]
    end
  end
end
