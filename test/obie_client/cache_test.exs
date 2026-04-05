defmodule ObieClient.CacheTest do
  # ETS table is global
  use ExUnit.Case, async: false

  alias ObieClient.Cache

  setup do
    Cache.clear()
    :ok
  end

  describe "put/3 + get/1" do
    test "stores and retrieves a value within TTL" do
      Cache.put("k1", "v1", 60_000)
      assert {:ok, "v1"} = Cache.get("k1")
    end

    test "returns :miss for unknown key" do
      assert :miss = Cache.get("unknown-#{System.unique_integer()}")
    end

    test "returns :miss for expired entry" do
      Cache.put("expiring", "val", 1)
      Process.sleep(10)
      assert :miss = Cache.get("expiring")
    end

    test "overwrites existing entry" do
      Cache.put("overwrite", "first", 60_000)
      Cache.put("overwrite", "second", 60_000)
      assert {:ok, "second"} = Cache.get("overwrite")
    end

    test "caches arbitrary terms" do
      Cache.put(:atom_key, %{nested: [1, 2, 3]}, 60_000)
      assert {:ok, %{nested: [1, 2, 3]}} = Cache.get(:atom_key)
    end
  end

  describe "delete/1" do
    test "removes a cached entry" do
      Cache.put("to-delete", "val", 60_000)
      assert {:ok, "val"} = Cache.get("to-delete")
      Cache.delete("to-delete")
      assert :miss = Cache.get("to-delete")
    end

    test "is idempotent for missing keys" do
      assert :ok = Cache.delete("never-existed-#{System.unique_integer()}")
    end
  end

  describe "get_or_put/3" do
    test "returns cached value without calling the function" do
      Cache.put("cached", "value", 60_000)
      called = :counters.new(1, [])

      result =
        Cache.get_or_put("cached", 60_000, fn ->
          :counters.add(called, 1, 1)
          "computed"
        end)

      assert result == "value"
      assert :counters.get(called, 1) == 0
    end

    test "calls function on miss and caches the result" do
      key = "miss-#{System.unique_integer()}"
      result = Cache.get_or_put(key, 60_000, fn -> "computed-#{key}" end)
      assert result == "computed-#{key}"
      assert {:ok, "computed-#{key}"} = Cache.get(key)
    end
  end

  describe "invalidate_prefix/1" do
    test "removes all matching string keys" do
      Cache.put("user:1", "a", 60_000)
      Cache.put("user:2", "b", 60_000)
      Cache.put("token:x", "c", 60_000)

      count = Cache.invalidate_prefix("user:")
      assert count == 2
      assert :miss = Cache.get("user:1")
      assert :miss = Cache.get("user:2")
      assert {:ok, "c"} = Cache.get("token:x")
    end

    test "returns 0 when no keys match" do
      assert Cache.invalidate_prefix("nonexistent:") == 0
    end
  end
end
