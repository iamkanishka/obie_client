defmodule ObieClient.Events.Handler do
  @moduledoc """
  Real-time event notification handler for ASPSP-pushed webhook events.

  ASPSPs POST signed JWTs to the TPP's registered callback URL.
  This module provides JWS signature verification, per-event-type callback
  dispatch, and a handler factory for use with any Plug-compatible router.

  ## Usage with Phoenix / Plug

  Add `{:plug, "~> 1.16"}` to your dependencies, then in your router:

      post "/webhooks/obie", ObieClient.Events.Handler.plug(
        aspsp_public_key_pem: File.read!("aspsp_signing.pem"),
        on_event: &MyApp.handle_obie_event/1,
        on_error: fn reason -> Logger.error("OBIE webhook error: \#{inspect(reason)}") end
      )

  ## Programmatic usage

      {:ok, handler} = ObieClient.Events.Handler.new(
        aspsp_public_key_pem: File.read!("aspsp_signing.pem")
      )
      ObieClient.Events.Handler.register(handler,
        "urn:uk:org:openbanking:events:resource-update",
        fn event -> MyApp.process(event) end
      )
      # In your Plug conn handler:
      {:ok, event} = ObieClient.Events.Handler.handle(handler, body, jws_header)
  """

  use Agent

  alias ObieClient.Auth.JWT
  alias ObieClient.Signing.JWS

  # ── Public API ──────────────────────────────────────────────────────────

  @doc "Starts a handler process. Options: `:aspsp_public_key_pem`."
  @spec new(keyword()) :: {:ok, pid()} | {:error, term()}
  def new(opts \\ []) do
    Agent.start_link(fn ->
      %{pem: Keyword.get(opts, :aspsp_public_key_pem), handlers: %{}}
    end)
  end

  @doc "Registers a callback for a specific event type URN."
  @spec register(pid(), String.t(), (map() -> any())) :: :ok
  def register(pid, event_type, fun) when is_function(fun, 1) do
    Agent.update(pid, fn s -> put_in(s, [:handlers, event_type], fun) end)
  end

  @doc "Registers a wildcard handler invoked for every event."
  @spec register_wildcard(pid(), (map() -> any())) :: :ok
  def register_wildcard(pid, fun), do: register(pid, "*", fun)

  @doc "Parses and verifies the event body without dispatching to handlers."
  @spec parse(pid(), binary(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def parse(pid, body, jws_sig) do
    pem = Agent.get(pid, & &1.pem)
    verify_and_decode(pem, body, jws_sig)
  end

  @doc "Parses, verifies, dispatches to registered handlers, and returns the event."
  @spec handle(pid(), binary(), nil | binary()) :: {:ok, map()} | {:error, term()}
  def handle(pid, body, jws_sig) do
    case verify_and_decode(Agent.get(pid, & &1.pem), body, jws_sig) do
      {:ok, event} ->
        dispatch(pid, event)
        {:ok, event}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Returns a function `(conn :: map() -> conn :: map())` suitable for use
  as a Plug handler when `{:plug, "~> 1.16"}` is in your project's deps.

  Options:
  - `:aspsp_public_key_pem` — ASPSP signing public key PEM
  - `:on_event` — `fn event -> any()` (called for each verified event)
  - `:on_error` — `fn reason -> any()` (called on verification failure)

  The returned function reads the raw body, extracts the `x-jws-signature`
  header, verifies the signature, and responds 200 on success or 400 on
  failure. Include `{:plug, "~> 1.16"}` in your deps to use `Plug.Conn`.
  """
  @spec plug(keyword()) :: (map() -> map())
  def plug(opts) do
    pem = Keyword.get(opts, :aspsp_public_key_pem)
    on_event = Keyword.get(opts, :on_event, fn _e -> :ok end)
    on_error = Keyword.get(opts, :on_error, fn _r -> :ok end)

    fn conn ->
      {body, sig} = read_conn(conn)

      case verify_and_decode(pem, body, sig) do
        {:ok, event} ->
          on_event.(event)
          send_conn_resp(conn, 200, "")

        {:error, reason} ->
          on_error.(reason)
          send_conn_resp(conn, 400, "Bad Request")
      end
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────

  defp verify_and_decode(nil, body, _sig) do
    Jason.decode(body)
  end

  defp verify_and_decode(pem, body, sig) do
    case JWT.parse_public_key(pem) do
      {:ok, pub_key} ->
        verify_sig_and_decode(pub_key, body, sig)

      {:error, _} = err ->
        err
    end
  end

  defp verify_sig_and_decode(pub_key, body, sig) do
    case JWS.verify(sig || "", body, pub_key) do
      :ok -> Jason.decode(body)
      {:error, _} = err -> err
    end
  end

  defp dispatch(pid, event) do
    handlers = Agent.get(pid, & &1.handlers)
    event_types = Map.keys(event["events"] || %{})

    Enum.each(event_types, fn type ->
      cond do
        f = handlers[type] -> f.(event)
        f = handlers["*"] -> f.(event)
        true -> :ok
      end
    end)

    if event_types == [] do
      if f = handlers["*"], do: f.(event)
    end

    :ok
  end

  # Plug.Conn integration — dynamically resolved to avoid hard dep on :plug.
  # Add {:plug, "~> 1.16"} to your deps to use the plug/1 factory.
  defp read_conn(conn) do
    {_, body, _} = Plug.Conn.read_body(conn)
    headers = Plug.Conn.get_req_header(conn, "x-jws-signature")
    sig = List.first(headers)
    {body, sig}
  rescue
    _ -> {"", nil}
  end

  defp send_conn_resp(conn, status, body) do
    if Code.ensure_loaded?(Plug.Conn) do
      Plug.Conn.send_resp(conn, status, body)
    else
      conn
    end
  rescue
    _ -> conn
  end
end
