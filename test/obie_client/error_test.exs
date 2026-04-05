defmodule ObieClient.ErrorTest do
  use ExUnit.Case, async: true

  alias ObieClient.Error

  describe "Exception.message/1" do
    test "formats status, code, and message" do
      err = %Error{status: 400, code: "UK.OBIE.Field.Missing", message: "ConsentId required"}
      msg = Exception.message(err)
      assert msg =~ "400"
      assert msg =~ "UK.OBIE.Field.Missing"
      assert msg =~ "ConsentId required"
    end

    test "handles nil code gracefully" do
      err = %Error{status: 500, code: nil, message: "Internal error"}
      msg = Exception.message(err)
      assert msg =~ "500"
      assert msg =~ "Internal error"
    end

    test "handles all-nil fields without crashing" do
      err = %Error{status: nil, code: nil, message: nil}
      assert is_binary(Exception.message(err))
    end
  end

  describe "has_code?/2" do
    test "returns true when code matches an error detail" do
      err = %Error{
        status: 400,
        errors: [%{"ErrorCode" => "UK.OBIE.Field.Missing", "Message" => "missing"}]
      }

      assert Error.has_code?(err, "UK.OBIE.Field.Missing")
    end

    test "returns false when code is absent" do
      err = %Error{status: 400, errors: [%{"ErrorCode" => "UK.OBIE.Field.Invalid"}]}
      refute Error.has_code?(err, "UK.OBIE.Field.Missing")
    end

    test "returns false when errors list is empty" do
      refute Error.has_code?(%Error{status: 404, errors: []}, "UK.OBIE.Resource.NotFound")
    end
  end

  describe "retryable?/1" do
    test "5xx errors are retryable" do
      for s <- [500, 502, 503, 504] do
        assert Error.retryable?(%Error{status: s}), "expected #{s} to be retryable"
      end
    end

    test "4xx errors are not retryable" do
      for s <- [400, 401, 403, 404, 422, 429] do
        refute Error.retryable?(%Error{status: s}), "expected #{s} not to be retryable"
      end
    end

    test "transport errors are retryable" do
      assert Error.retryable?({:transport_error, :econnrefused})
    end

    test "rate limited is retryable" do
      assert Error.retryable?({:rate_limited, %{}})
    end
  end

  describe "raise/1" do
    test "can be raised and caught as an exception" do
      assert_raise ObieClient.Error, fn ->
        raise %Error{status: 404, message: "not found"}
      end
    end
  end
end
