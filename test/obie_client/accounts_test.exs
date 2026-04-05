defmodule ObieClient.AccountsTest do
  use ExUnit.Case, async: true

  import ObieClient.Test.Factory

  alias ObieClient.Accounts
  alias ObieClient.Error

  setup do
    bypass = Bypass.open()
    config = test_config(bypass)
    {:ok, client} = ObieClient.Client.new(config)
    {:ok, bypass: bypass, client: client}
  end

  describe "list/1" do
    test "returns accounts on 200", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      assert {:ok, %{"Data" => %{"Account" => [_ | _]}}} = Accounts.list(client)
    end

    test "returns ObieClient.Error on 401", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        Plug.Conn.send_resp(conn, 401, ~s({"Code":"UK.OBIE.NotAuthorised"}))
      end)

      assert {:error, %Error{status: 401}} = Accounts.list(client)
    end

    test "includes mandatory FAPI headers", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts", fn conn ->
        assert [_] = Plug.Conn.get_req_header(conn, "x-fapi-interaction-id")
        assert [_] = Plug.Conn.get_req_header(conn, "x-fapi-auth-date")
        assert ["Bearer " <> _] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      assert {:ok, _} = Accounts.list(client)
    end
  end

  describe "get/2" do
    test "GETs single account by ID", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/accounts/acc-001", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(account_response()))
      end)

      assert {:ok, _} = Accounts.get(client, "acc-001")
    end
  end

  describe "list_account_balances/2" do
    test "calls per-account balances endpoint", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/accounts/acc-001/balances",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(balance_response()))
        end
      )

      assert {:ok, %{"Data" => %{"Balance" => [_ | _]}}} =
               Accounts.list_account_balances(client, "acc-001")
    end
  end

  describe "list_transactions/2 with date filter" do
    test "appends fromBookingDateTime query param", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/transactions", fn conn ->
        assert conn.query_string =~ "fromBookingDateTime"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(transaction_response()))
      end)

      assert {:ok, _} =
               Accounts.list_transactions(client,
                 from_booking_date_time: ~U[2024-01-01 00:00:00Z]
               )
    end
  end

  describe "list_statement_transactions_bulk/2" do
    test "uses the correct bulk endpoint path", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/statements/stmt-001/transactions",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(transaction_response()))
        end
      )

      assert {:ok, _} = Accounts.list_statement_transactions_bulk(client, "stmt-001")
    end
  end

  describe "get_party/1" do
    test "calls the /party endpoint", %{bypass: bypass, client: client} do
      party_resp = %{
        "Data" => %{"Party" => %{"PartyId" => "party-001", "PartyType" => "Individual"}},
        "Links" => %{"Self" => "https://aspsp.example.com/party"},
        "Meta" => %{}
      }

      Bypass.expect_once(bypass, "GET", "/open-banking/v3.1/aisp/party", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(party_resp))
      end)

      assert {:ok, %{"Data" => %{"Party" => _}}} = Accounts.get_party(client)
    end
  end
end
