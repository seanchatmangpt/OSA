defmodule OptimalSystemAgent.SDK.SessionTest do
  use ExUnit.Case, async: true
  alias OptimalSystemAgent.SDK

  describe "Session.create/1 with provider and model" do
    test "stores provider and model in returned metadata" do
      {:ok, meta} = SDK.Session.create(
        user_id: "test-user",
        provider: "groq",
        model: "openai/gpt-oss-20b"
      )
      assert meta.provider == "groq"
      assert meta.model == "openai/gpt-oss-20b"
      assert is_binary(meta.session_id)
    end

    test "omits provider and model keys when not given" do
      {:ok, meta} = SDK.Session.create(user_id: "test-user")
      refute Map.has_key?(meta, :provider)
      refute Map.has_key?(meta, :model)
    end
  end
end
