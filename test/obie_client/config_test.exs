defmodule ObieClient.ConfigTest do
  use ExUnit.Case, async: true

  alias ObieClient.Config

  @valid [
    client_id: "test-client",
    token_url: "https://aspsp.example.com/token",
    private_key_pem: "-----BEGIN RSA PRIVATE KEY-----\nfake\n-----END RSA PRIVATE KEY-----"
  ]

  describe "new/1" do
    test "builds a valid config" do
      assert {:ok, %Config{client_id: "test-client"}} = Config.new(@valid)
    end

    test "defaults environment to :sandbox" do
      {:ok, cfg} = Config.new(@valid)
      assert cfg.environment == :sandbox
    end

    test "defaults timeout to 30_000 ms" do
      {:ok, cfg} = Config.new(@valid)
      assert cfg.timeout == 30_000
    end

    test "defaults max_retries to 3" do
      {:ok, cfg} = Config.new(@valid)
      assert cfg.max_retries == 3
    end

    test "defaults scopes include accounts and payments" do
      {:ok, cfg} = Config.new(@valid)
      assert "accounts" in cfg.scopes
      assert "payments" in cfg.scopes
    end

    test "accepts :production environment" do
      {:ok, cfg} = Config.new(Keyword.put(@valid, :environment, :production))
      assert cfg.environment == :production
    end

    test "rejects missing client_id" do
      assert {:error, msg} = Config.new(Keyword.delete(@valid, :client_id))
      assert msg =~ "client_id"
    end

    test "rejects empty client_id" do
      assert {:error, _} = Config.new(Keyword.put(@valid, :client_id, ""))
    end

    test "rejects missing token_url" do
      assert {:error, msg} = Config.new(Keyword.delete(@valid, :token_url))
      assert msg =~ "token_url"
    end

    test "rejects missing private_key_pem" do
      assert {:error, msg} = Config.new(Keyword.delete(@valid, :private_key_pem))
      assert msg =~ "private_key_pem"
    end

    test "rejects invalid environment" do
      assert {:error, msg} = Config.new(Keyword.put(@valid, :environment, :staging))
      assert msg =~ "environment"
    end

    test "accepts overridden base_url" do
      {:ok, cfg} = Config.new(Keyword.put(@valid, :base_url, "https://ob.mybank.com"))
      assert cfg.base_url == "https://ob.mybank.com"
    end

    test "accepts custom pool_size" do
      {:ok, cfg} = Config.new(Keyword.put(@valid, :pool_size, 25))
      assert cfg.pool_size == 25
    end
  end

  describe "base_url/1" do
    test "sandbox config returns sandbox URL" do
      {:ok, cfg} = Config.new(@valid)
      assert cfg.base_url =~ "sandbox"
    end

    test "production config returns non-sandbox URL" do
      {:ok, cfg} = Config.new(Keyword.put(@valid, :environment, :production))
      refute cfg.base_url =~ "sandbox"
    end

    test "explicit base_url takes priority" do
      {:ok, cfg} = Config.new(Keyword.put(@valid, :base_url, "https://custom.aspsp.com"))
      assert cfg.base_url == "https://custom.aspsp.com"
    end
  end
end
