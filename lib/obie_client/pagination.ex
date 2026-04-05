defmodule ObieClient.Pagination do
  @dialyzer {:nowarn_function, [stream: 2]}
  @moduledoc """
  Lazy HATEOAS pagination for OBIE list endpoints.

  Follows `Links.Next` links transparently, either as a lazy `Stream`
  (memory-efficient for large result sets) or eagerly with `all_pages/2`.

  ## Examples

      # Stream all transactions without loading everything into memory
      client
      |> ObieClient.Pagination.stream(&ObieClient.Accounts.list_transactions/1)
      |> Stream.flat_map(fn page -> page["Data"]["Transaction"] || [] end)
      |> Enum.take(200)

      # Collect all statement pages
      {:ok, pages} = ObieClient.Pagination.all_pages(client,
        fn c -> ObieClient.Accounts.list_statements(c) end)

      all_statements = Enum.flat_map(pages, fn page ->
        page["Data"]["Statement"] || []
      end)
  """

  alias ObieClient.Client

  @doc """
  Returns a lazy `Stream` of pages, following `Links.Next` until exhausted.

  The stream halts on the first HTTP error (it does not raise).
  """
  @spec stream(Client.t(), (Client.t() -> {:ok, map()} | {:error, term()})) :: Enumerable.t()
  def stream(%Client{} = client, fetch_fn) do
    Stream.resource(
      fn -> {:first, fetch_fn} end,
      fn
        :done ->
          {:halt, :done}

        {:first, f} ->
          case f.(client) do
            {:ok, page} -> {[page], next_cursor(client, page)}
            {:error, _} -> {:halt, :done}
          end

        {:next_url, url} ->
          case Client.get(client, url) do
            {:ok, page} -> {[page], next_cursor(client, page)}
            {:error, _} -> {:halt, :done}
          end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Eagerly collects all pages into a list.

  Returns `{:ok, [page, ...]}` or `{:error, reason}` on the first HTTP error.
  """
  @spec all_pages(Client.t(), (Client.t() -> {:ok, map()} | {:error, term()})) ::
          {:ok, [map()]} | {:error, term()}
  def all_pages(%Client{} = client, fetch_fn) do
    collect(client, {:first, fetch_fn}, [])
  end

  # ── Private ──────────────────────────────────────────────────────────────

  defp next_cursor(_client, page) do
    case get_in(page, ["Links", "Next"]) do
      url when is_binary(url) and url != "" -> {:next_url, url}
      _ -> :done
    end
  end

  defp collect(_client, :done, acc), do: {:ok, Enum.reverse(acc)}

  defp collect(client, {:first, fetch_fn}, acc) do
    case fetch_fn.(client) do
      {:ok, page} -> collect(client, next_cursor(client, page), [page | acc])
      {:error, _} = err -> err
    end
  end

  defp collect(client, {:next_url, url}, acc) do
    case Client.get(client, url) do
      {:ok, page} -> collect(client, next_cursor(client, page), [page | acc])
      {:error, _} = err -> err
    end
  end
end
