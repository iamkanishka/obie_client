defmodule ObieClient.Telemetry do
  @moduledoc """
  Telemetry events emitted by ObieClient for every HTTP operation.

  ## Events

  | Event | Measurements | Metadata |
  |-------|-------------|----------|
  | `[:obie_client, :request, :start]` | `%{system_time: t}` | `%{method: m, path: p, interaction_id: id}` |
  | `[:obie_client, :request, :stop]` | `%{duration: ns}` | `%{method: m, path: p, status: s}` |
  | `[:obie_client, :request, :exception]` | `%{duration: ns}` | `%{method: m, path: p, error: e}` |
  | `[:obie_client, :token, :fetched]` | `%{expires_in: s}` | `%{client_id: id}` |
  | `[:obie_client, :circuit_breaker, :state_change]` | `%{}` | `%{from: f, to: t, client_id: id}` |

  ## Example

      :telemetry.attach_many("my-handler",
        [[:obie_client, :request, :stop], [:obie_client, :request, :exception]],
        &MyApp.handle_obie_event/4, nil)

      def handle_obie_event(event, measurements, metadata, _config) do
        Logger.info("OBIE \#{inspect(event)}: \#{inspect(metadata)}")
      end
  """

  @doc false
  @spec request_start(atom() | String.t(), String.t(), String.t()) :: :ok
  def request_start(method, path, interaction_id) do
    :telemetry.execute(
      [:obie_client, :request, :start],
      %{system_time: System.system_time()},
      %{method: method, path: strip_query(path), interaction_id: interaction_id}
    )
  end

  @doc false
  @spec request_stop(atom() | String.t(), String.t(), integer(), integer()) :: :ok
  def request_stop(method, path, status, duration_native) do
    :telemetry.execute(
      [:obie_client, :request, :stop],
      %{duration: System.convert_time_unit(duration_native, :native, :nanosecond)},
      %{method: method, path: strip_query(path), status: status}
    )
  end

  @doc false
  @spec request_exception(atom() | String.t(), String.t(), term(), integer()) :: :ok
  def request_exception(method, path, error, duration_native) do
    :telemetry.execute(
      [:obie_client, :request, :exception],
      %{duration: System.convert_time_unit(duration_native, :native, :nanosecond)},
      %{method: method, path: strip_query(path), error: error}
    )
  end

  @doc false
  @spec token_fetched(String.t(), integer()) :: :ok
  def token_fetched(client_id, expires_in) do
    :telemetry.execute(
      [:obie_client, :token, :fetched],
      %{expires_in: expires_in},
      %{client_id: client_id}
    )
  end

  @doc false
  @spec circuit_breaker_state_change(String.t(), atom(), atom()) :: :ok
  def circuit_breaker_state_change(client_id, from, to) do
    :telemetry.execute(
      [:obie_client, :circuit_breaker, :state_change],
      %{},
      %{from: from, to: to, client_id: client_id}
    )
  end

  # Strip query params so high-cardinality IDs don't explode metric labels
  defp strip_query(path) do
    case String.split(path, "?", parts: 2) do
      [base | _] -> base
      _ -> path
    end
  end
end
