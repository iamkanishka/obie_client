defmodule ObieClient.AISP.ConsentTest do
  use ExUnit.Case, async: true

  import ObieClient.Test.Factory

  alias ObieClient.Types.Enums

  alias ObieClient.AISP.Consent
  alias ObieClient.Error

  setup do
    bypass = Bypass.open()
    config = test_config(bypass)
    {:ok, client} = ObieClient.Client.new(config)
    {:ok, bypass: bypass, client: client}
  end

  describe "create/3" do
    test "POSTs to correct endpoint and returns consent", %{bypass: bypass, client: client} do
      resp = consent_response()

      Bypass.expect_once(
        bypass,
        "POST",
        "/open-banking/v3.1/aisp/account-access-consents",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)
          assert "ReadBalances" in decoded["Data"]["Permissions"]
          assert decoded["Risk"] == %{}

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(resp))
        end
      )

      assert {:ok, %{"Data" => %{"Status" => "AwaitingAuthorisation"}}} =
               Consent.create(client, Enums.detail_permissions())
    end

    test "includes FAPI headers on every request", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/open-banking/v3.1/aisp/account-access-consents",
        fn conn ->
          assert [_] = Plug.Conn.get_req_header(conn, "x-fapi-interaction-id")
          assert [_] = Plug.Conn.get_req_header(conn, "x-fapi-auth-date")
          assert [_] = Plug.Conn.get_req_header(conn, "authorization")

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(consent_response()))
        end
      )

      assert {:ok, _} = Consent.create(client, ["ReadBalances"])
    end

    test "includes expiration_date_time when provided", %{bypass: bypass, client: client} do
      exp = ~U[2025-12-31 23:59:59Z]

      Bypass.expect_once(
        bypass,
        "POST",
        "/open-banking/v3.1/aisp/account-access-consents",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)
          assert decoded["Data"]["ExpirationDateTime"] =~ "2025-12-31"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(consent_response()))
        end
      )

      assert {:ok, _} = Consent.create(client, ["ReadBalances"], expiration_date_time: exp)
    end

    test "returns ObieClient.Error on 400", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/open-banking/v3.1/aisp/account-access-consents",
        fn conn ->
          body = ~s({"Code":"UK.OBIE.Field.Missing","Message":"Permissions required"})
          Plug.Conn.send_resp(conn, 400, body)
        end
      )

      assert {:error, %Error{status: 400, code: "UK.OBIE.Field.Missing"}} =
               Consent.create(client, [])
    end
  end

  describe "get/2" do
    test "retrieves consent by ConsentId", %{bypass: bypass, client: client} do
      resp =
        consent_response(%{
          "Data" => %{
            "ConsentId" => "urn-test-001",
            "Status" => "Authorised",
            "CreationDateTime" => "2024-01-01T00:00:00Z",
            "StatusUpdateDateTime" => "2024-01-01T00:01:00Z",
            "Permissions" => ["ReadBalances"]
          }
        })

      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/account-access-consents/urn-test-001",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      )

      assert {:ok, %{"Data" => %{"Status" => "Authorised"}}} = Consent.get(client, "urn-test-001")
    end

    test "returns error on 404", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/account-access-consents/not-found",
        fn conn ->
          Plug.Conn.send_resp(conn, 404, ~s({"Code":"UK.OBIE.Resource.NotFound"}))
        end
      )

      assert {:error, %Error{status: 404}} = Consent.get(client, "not-found")
    end
  end

  describe "delete/2" do
    test "sends DELETE and returns :ok on 204", %{bypass: bypass, client: client} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/open-banking/v3.1/aisp/account-access-consents/urn-to-delete",
        fn conn -> Plug.Conn.send_resp(conn, 204, "") end
      )

      assert :ok = Consent.delete(client, "urn-to-delete")
    end
  end

  describe "poll_until_authorised/3" do
    test "returns immediately when status is already Authorised", %{
      bypass: bypass,
      client: client
    } do
      resp =
        consent_response(%{
          "Data" => %{
            "ConsentId" => "c-auth",
            "Status" => "Authorised",
            "CreationDateTime" => "2024-01-01T00:00:00Z",
            "StatusUpdateDateTime" => "2024-01-01T00:00:01Z",
            "Permissions" => ["ReadBalances"]
          }
        })

      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/account-access-consents/c-auth",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      )

      assert {:ok, %{"Data" => %{"Status" => "Authorised"}}} =
               Consent.poll_until_authorised(client, "c-auth")
    end

    test "returns error on Rejected", %{bypass: bypass, client: client} do
      resp =
        consent_response(%{
          "Data" => %{
            "ConsentId" => "c-rej",
            "Status" => "Rejected",
            "CreationDateTime" => "2024-01-01T00:00:00Z",
            "StatusUpdateDateTime" => "2024-01-01T00:00:01Z",
            "Permissions" => ["ReadBalances"]
          }
        })

      Bypass.expect_once(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/account-access-consents/c-rej",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(resp))
        end
      )

      assert {:error, {:consent_rejected, "Rejected"}} =
               Consent.poll_until_authorised(client, "c-rej")
    end

    test "times out when never Authorised", %{bypass: bypass, client: client} do
      Bypass.expect(
        bypass,
        "GET",
        "/open-banking/v3.1/aisp/account-access-consents/c-wait",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(consent_response()))
        end
      )

      assert {:error, :timeout} =
               Consent.poll_until_authorised(client, "c-wait", interval_ms: 10, timeout_ms: 50)
    end
  end
end
