defmodule ObieClient.PaginationTest do
  use ExUnit.Case, async: true

  import ObieClient.Test.Factory

  alias ObieClient.Accounts
  alias ObieClient.Error
  alias ObieClient.Pagination

  setup do
    bypass = Bypass.open()
    config = test_config(bypass)
    {:ok, client} = ObieClient.Client.new(config)
    {:ok, bypass: bypass, client: client, port: bypass.port}
  end

  describe "all_pages/2" do
    test "returns single page when no Next link", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      assert {:ok, [page]} = Pagination.all_pages(client, &Accounts.list/1)
      assert [_] = page["Data"]["Account"]
    end

    test "follows Next link to second page", %{bypass: bypass, client: client, port: port} do
      page1 = %{
        "Data" => %{"Account" => [%{"AccountId" => "a1"}]},
        "Links" => %{
          "Self" => "http://localhost:#{port}/open-banking/v3.1/aisp/accounts",
          "Next" => "http://localhost:#{port}/open-banking/v3.1/aisp/accounts?page=2"
        },
        "Meta" => %{"TotalPages" => 2}
      }

      page2 = %{
        "Data" => %{"Account" => [%{"AccountId" => "a2"}]},
        "Links" => %{"Self" => "http://localhost:#{port}/open-banking/v3.1/aisp/accounts?page=2"},
        "Meta" => %{"TotalPages" => 2}
      }

      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        n = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)
        body = if n == 0, do: page1, else: page2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(body))
      end)

      assert {:ok, pages} = Pagination.all_pages(client, &Accounts.list/1)
      assert length(pages) == 2

      all_ids =
        Enum.flat_map(pages, fn p -> Enum.map(p["Data"]["Account"], & &1["AccountId"]) end)

      assert "a1" in all_ids
      assert "a2" in all_ids
    end

    test "returns error on HTTP failure", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      assert {:error, %Error{status: 503}} = Pagination.all_pages(client, &Accounts.list/1)
    end
  end

  describe "stream/2" do
    test "returns an enumerable of pages", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      pages = Pagination.stream(client, &Accounts.list/1) |> Enum.to_list()
      assert length(pages) == 1
    end

    test "can be used with Stream.flat_map", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      accounts =
        client
        |> Pagination.stream(&Accounts.list/1)
        |> Stream.flat_map(fn page -> page["Data"]["Account"] end)
        |> Enum.to_list()

      assert [%{"AccountId" => "acc-001"}] = accounts
    end
  end
end
