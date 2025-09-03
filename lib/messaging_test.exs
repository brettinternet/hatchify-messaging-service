defmodule MessagingTest do
  use ExUnit.Case, async: true

  describe "environment/0" do
    test "describes the runtime environment" do
      assert "development" == Messaging.environment()
    end
  end

  describe "config_env/0" do
    test "returns the configuration atom" do
      assert :test == Messaging.config_env()
    end
  end

  describe "rate_limit_message/0" do
    test "describes the message rate limit values" do
      assert {token, interval} = Messaging.rate_limit_message()
      assert is_integer(token)
      assert is_integer(interval)
    end
  end
end
