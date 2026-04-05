defmodule ObieClient.CircuitBreakerTest do
  # ETS table is global
  use ExUnit.Case, async: false

  alias ObieClient.CircuitBreaker

  # Each test gets a unique client_id to avoid state pollution
  setup do
    id = "test-cb-#{System.unique_integer([:positive])}"
    CircuitBreaker.reset(id)
    on_exit(fn -> CircuitBreaker.reset(id) end)
    {:ok, id: id}
  end

  describe "allow/1" do
    test "allows requests when circuit is closed", %{id: id} do
      assert :ok = CircuitBreaker.allow(id)
    end

    test "allows a fresh (unknown) client", %{id: _id} do
      assert :ok = CircuitBreaker.allow("brand-new-client-#{System.unique_integer()}")
    end
  end

  describe "record_failure/1 + allow/1" do
    test "opens circuit after 5 consecutive failures", %{id: id} do
      for _ <- 1..5, do: CircuitBreaker.record_failure(id)
      assert {:error, :circuit_open} = CircuitBreaker.allow(id)
    end

    test "stays closed below 5 failures", %{id: id} do
      for _ <- 1..4, do: CircuitBreaker.record_failure(id)
      assert :ok = CircuitBreaker.allow(id)
    end
  end

  describe "record_success/1" do
    test "prevents opening if success interrupts failure streak", %{id: id} do
      for _ <- 1..3, do: CircuitBreaker.record_failure(id)
      CircuitBreaker.record_success(id)
      # Only 3 new failures (total 4 since last success) — stays closed
      for _ <- 1..4, do: CircuitBreaker.record_failure(id)
      assert :ok = CircuitBreaker.allow(id)
    end
  end

  describe "state/1" do
    test "reports :closed initially", %{id: id} do
      assert CircuitBreaker.state(id) == :closed
    end

    test "reports :open after max failures", %{id: id} do
      for _ <- 1..5, do: CircuitBreaker.record_failure(id)
      assert CircuitBreaker.state(id) == :open
    end

    test "reports :closed after reset", %{id: id} do
      for _ <- 1..5, do: CircuitBreaker.record_failure(id)
      CircuitBreaker.reset(id)
      assert CircuitBreaker.state(id) == :closed
    end
  end

  describe "reset/1" do
    test "closes an open circuit", %{id: id} do
      for _ <- 1..10, do: CircuitBreaker.record_failure(id)
      assert {:error, :circuit_open} = CircuitBreaker.allow(id)
      CircuitBreaker.reset(id)
      assert :ok = CircuitBreaker.allow(id)
    end

    test "is idempotent for a closed circuit", %{id: id} do
      assert :ok = CircuitBreaker.reset(id)
      assert :ok = CircuitBreaker.allow(id)
    end
  end
end
