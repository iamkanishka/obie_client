defmodule ObieClientTest do
  use ExUnit.Case
  doctest ObieClient

  test "greets the world" do
    assert ObieClient.hello() == :world
  end
end
