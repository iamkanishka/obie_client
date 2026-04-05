defmodule ObieClient.EventNotifications do
  # Suppress known-safe dialyzer warnings caused by RSA key-parsing
  # through the JWS signing chain. The @spec is correct.
  @dialyzer {:nowarn_function,
             [
               create_subscription: 2,
               update_subscription: 3,
               create_callback_url: 3,
               update_callback_url: 4
             ]}
  @moduledoc """
  Event Notifications — subscriptions, callback URLs, and aggregated polling.

  ## Spec
  - Event Notification Subscription API v3.1.2
  - Aggregated Polling API v3.1.2
  - Callback URL API v3.1.2
  """

  alias ObieClient.Client

  @base "/open-banking/v3.1"

  # ── Event Subscriptions ──────────────────────────────────────────────────

  @doc """
  Creates an event subscription.

  Options: `:callback_url`, `:version` (required), `:event_types`.
  """
  @spec create_subscription(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_subscription(%Client{} = c, opts) do
    data =
      %{"Version" => Keyword.fetch!(opts, :version)}
      |> maybe_put("CallbackUrl", Keyword.get(opts, :callback_url))
      |> maybe_put("EventTypes", Keyword.get(opts, :event_types))

    Client.post(c, "#{@base}/event-subscriptions", %{"Data" => data},
      idempotency_key: Uniq.UUID.uuid4()
    )
  end

  @doc "GET /event-subscriptions"
  @spec list_subscriptions(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_subscriptions(%Client{} = c),
    do: Client.get(c, "#{@base}/event-subscriptions")

  @doc "PUT /event-subscriptions/{EventSubscriptionId}"
  @spec update_subscription(Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def update_subscription(%Client{} = c, id, opts) do
    data =
      %{"Version" => Keyword.fetch!(opts, :version)}
      |> maybe_put("CallbackUrl", Keyword.get(opts, :callback_url))
      |> maybe_put("EventTypes", Keyword.get(opts, :event_types))

    Client.put(c, "#{@base}/event-subscriptions/#{id}", %{"Data" => data},
      idempotency_key: Uniq.UUID.uuid4()
    )
  end

  @doc "DELETE /event-subscriptions/{EventSubscriptionId}"
  @spec delete_subscription(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_subscription(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/event-subscriptions/#{id}")

  # ── Callback URLs ────────────────────────────────────────────────────────

  @doc "POST /callback-urls — registers a callback URL."
  @spec create_callback_url(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def create_callback_url(%Client{} = c, url, version) do
    Client.post(c, "#{@base}/callback-urls", %{"Data" => %{"Url" => url, "Version" => version}},
      idempotency_key: Uniq.UUID.uuid4()
    )
  end

  @doc "GET /callback-urls"
  @spec list_callback_urls(Client.t()) :: {:ok, map()} | {:error, term()}
  def list_callback_urls(%Client{} = c), do: Client.get(c, "#{@base}/callback-urls")

  @doc "PUT /callback-urls/{CallbackUrlId}"
  @spec update_callback_url(Client.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def update_callback_url(%Client{} = c, id, url, version) do
    Client.put(
      c,
      "#{@base}/callback-urls/#{id}",
      %{"Data" => %{"Url" => url, "Version" => version}},
      idempotency_key: Uniq.UUID.uuid4()
    )
  end

  @doc "DELETE /callback-urls/{CallbackUrlId}"
  @spec delete_callback_url(Client.t(), String.t()) :: :ok | {:error, term()}
  def delete_callback_url(%Client{} = c, id),
    do: Client.delete(c, "#{@base}/callback-urls/#{id}")

  # ── Aggregated Polling ────────────────────────────────────────────────────

  @doc """
  POST /events — aggregated event polling.

  `ack` is a list of JTIs to acknowledge (processed without error).
  `set_errs` is a map of `%{jti => %{"err" => code, "description" => msg}}`.

  Returns `{:ok, %{"sets" => %{jti => jwt_string}, "moreAvailable" => bool}}`.

  ## Examples

      # First poll — no acks yet
      {:ok, %{"sets" => sets}} = ObieClient.EventNotifications.poll_events(client, [], %{})

      # Process and acknowledge
      acked = Map.keys(sets)
      {:ok, _} = ObieClient.EventNotifications.poll_events(client, acked, %{})
  """
  @spec poll_events(Client.t(), [String.t()], map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def poll_events(%Client{} = c, ack, set_errs \\ %{}, opts \\ []) do
    body =
      %{
        "maxEvents" => Keyword.get(opts, :max_events, 10),
        "returnImmediately" => Keyword.get(opts, :return_immediately, true)
      }
      |> then(fn b -> if ack != [], do: Map.put(b, "ack", ack), else: b end)
      |> then(fn b -> if set_errs != %{}, do: Map.put(b, "setErrs", set_errs), else: b end)

    Client.post(c, "#{@base}/events", body)
  end

  defp maybe_put(m, _k, nil), do: m
  defp maybe_put(m, k, v), do: Map.put(m, k, v)
end
