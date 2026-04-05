defmodule ObieClient.Error do
  @moduledoc """
  Structured error returned by all ObieClient API calls.

  Fields:
  - `:status` — HTTP status code, or `nil` for transport errors
  - `:code` — OBIE error code, e.g. `"UK.OBIE.Field.Missing"`
  - `:message` — human-readable summary
  - `:errors` — list of per-field `OBErrorDetail` maps from the ASPSP
  - `:interaction_id` — the `x-fapi-interaction-id` echoed in the response
  """

  @type t :: %__MODULE__{
          status: integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          errors: [map()],
          interaction_id: String.t() | nil
        }

  defexception [:status, :code, :message, errors: [], interaction_id: nil]

  @doc false
  @impl true
  @spec message(t()) :: String.t()
  def message(%__MODULE__{status: status, code: code, message: msg}) do
    [status && "[#{status}]", code, msg]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" — ")
  end

  @doc "Returns true if any error detail entry has the given OBIE code."
  @spec has_code?(t(), String.t()) :: boolean()
  def has_code?(%__MODULE__{errors: errors}, code) do
    Enum.any?(errors, &(&1["ErrorCode"] == code))
  end

  @doc "Returns true if the error is worth retrying."
  @spec retryable?(t() | term()) :: boolean()
  def retryable?(%__MODULE__{status: s}) when is_integer(s) and s >= 500, do: true
  def retryable?({:transport_error, _}), do: true
  def retryable?({:rate_limited, _}), do: true
  def retryable?(_), do: false
end
