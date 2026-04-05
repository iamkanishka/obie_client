defmodule ObieClient.PaymentsTest do
  use ExUnit.Case, async: true

  import ObieClient.Test.Factory

  alias ObieClient.Payments

  setup do
    bypass = Bypass.open()
    config = test_config(bypass)
    {:ok, client} = ObieClient.Client.new(config)
    {:ok, bypass: bypass, client: client}
  end

  describe "create_domestic_consent/3" do
    test "POSTs with idempotency-key and returns consent", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/open-banking/v3.1/pisp/domestic-payment-consents",
        fn conn ->
          assert [_] = Plug.Conn.get_req_header(conn, "x-idempotency-key")

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(domestic_payment_consent_response()))
        end
      )

      assert {:ok, %{"Data" => %{"ConsentId" => _}}} =
               Payments.create_domestic_consent(client, domestic_initiation())
    end
  end

  describe "get_domestic_consent/2" do
    test "GETs the consent", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/pisp/domestic-payment-consents/c-001",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(domestic_payment_consent_response()))
        end
      )

      assert {:ok, _} = Payments.get_domestic_consent(client, "c-001")
    end
  end

  describe "delete_domestic_scheduled_consent/2" do
    test "sends DELETE and returns :ok", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/open-banking/v3.1/pisp/domestic-scheduled-payment-consents/sc-001",
        fn conn -> Plug.Conn.send_resp(conn, 204, "") end
      )

      assert :ok = Payments.delete_domestic_scheduled_consent(client, "sc-001")
    end
  end

  describe "delete_domestic_standing_order_consent/2" do
    test "sends DELETE and returns :ok", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/open-banking/v3.1/pisp/domestic-standing-order-consents/so-001",
        fn conn -> Plug.Conn.send_resp(conn, 204, "") end
      )

      assert :ok = Payments.delete_domestic_standing_order_consent(client, "so-001")
    end
  end

  describe "delete_international_scheduled_consent/2" do
    test "sends DELETE and returns :ok", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/open-banking/v3.1/pisp/international-scheduled-payment-consents/isc-001",
        fn conn -> Plug.Conn.send_resp(conn, 204, "") end
      )

      assert :ok = Payments.delete_international_scheduled_consent(client, "isc-001")
    end
  end

  describe "delete_international_standing_order_consent/2" do
    test "sends DELETE and returns :ok", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/open-banking/v3.1/pisp/international-standing-order-consents/iso-001",
        fn conn -> Plug.Conn.send_resp(conn, 204, "") end
      )

      assert :ok = Payments.delete_international_standing_order_consent(client, "iso-001")
    end
  end

  describe "submit_domestic/3" do
    test "POSTs with ConsentId in body", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "POST", "/open-banking/v3.1/pisp/domestic-payments", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["Data"]["ConsentId"] == "c-001"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(domestic_payment_response()))
      end)

      assert {:ok, %{"Data" => %{"DomesticPaymentId" => _}}} =
               Payments.submit_domestic(client, "c-001", domestic_initiation())
    end
  end

  describe "poll_domestic/3" do
    test "returns immediately on terminal status", %{bypass: bypass, client: client} do
      resp = domestic_payment_response("AcceptedSettlementCompleted")

      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/pisp/domestic-payments/p-001",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      )

      assert {:ok, %{"Data" => %{"Status" => "AcceptedSettlementCompleted"}}} =
               Payments.poll_domestic(client, "p-001")
    end

    test "polls multiple times until terminal", %{bypass: bypass, client: client} do
      pending = domestic_payment_response("Pending")
      terminal = domestic_payment_response("AcceptedSettlementCompleted")
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/open-banking/v3.1/pisp/domestic-payments/p-002", fn conn ->
        n = :counters.get(counter, 1)
        :counters.add(counter, 1, 1)
        body = if n == 0, do: pending, else: terminal

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(body))
      end)

      assert {:ok, %{"Data" => %{"Status" => "AcceptedSettlementCompleted"}}} =
               Payments.poll_domestic(client, "p-002", interval_ms: 10)
    end

    test "returns :timeout when deadline exceeded", %{bypass: bypass, client: client} do
      pending = domestic_payment_response("Pending")

      Bypass.expect(bypass, "GET", "/open-banking/v3.1/pisp/domestic-payments/p-003", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(pending))
      end)

      assert {:error, :timeout} =
               Payments.poll_domestic(client, "p-003", interval_ms: 10, timeout_ms: 30)
    end
  end

  describe "get_domestic_consent_funds_confirmation/2" do
    test "GETs the funds confirmation", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/pisp/domestic-payment-consents/c-001/funds-confirmation",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(funds_confirmation_response()))
        end
      )

      assert {:ok, %{"Data" => %{"FundsAvailableResult" => _}}} =
               Payments.get_domestic_consent_funds_confirmation(client, "c-001")
    end
  end
end
