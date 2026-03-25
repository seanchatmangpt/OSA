defmodule OptimalSystemAgent.Channels.HTTP.AuthRealTest do
  @moduledoc """
  Chicago TDD integration tests for Channels.HTTP.Auth.

  NO MOCKS. Tests real JWT HS256 token generation, verification, refresh.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Channels.HTTP.Auth

  setup do
    # Ensure a consistent secret for all tests
    original = Application.get_env(:optimal_system_agent, :shared_secret)
    Application.put_env(:optimal_system_agent, :shared_secret, "test-secret-key-for-chicago-tdd")
    on_exit(fn ->
      if original do
        Application.put_env(:optimal_system_agent, :shared_secret, original)
      else
        Application.delete_env(:optimal_system_agent, :shared_secret)
      end
    end)
    :ok
  end

  describe "Auth.generate_token/1" do
    test "CRASH: returns JWT string with 3 parts" do
      token = Auth.generate_token(%{"user_id" => "user_1"})
      parts = String.split(token, ".")
      assert length(parts) == 3
    end

    test "CRASH: includes iat claim" do
      token = Auth.generate_token(%{"user_id" => "user_1"})
      [_header_b64, payload_b64, _sig] = String.split(token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, claims} = Jason.decode(payload_json)
      assert Map.has_key?(claims, "iat")
    end

    test "CRASH: includes exp claim (15 min from now)" do
      token = Auth.generate_token(%{"user_id" => "user_1"})
      [_header_b64, payload_b64, _sig] = String.split(token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, claims} = Jason.decode(payload_json)
      assert claims["exp"] > claims["iat"]
      assert claims["exp"] - claims["iat"] == 900
    end

    test "CRASH: preserves user claims" do
      token = Auth.generate_token(%{"user_id" => "user_1", "role" => "admin"})
      [_header_b64, payload_b64, _sig] = String.split(token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, claims} = Jason.decode(payload_json)
      assert claims["user_id"] == "user_1"
      assert claims["role"] == "admin"
    end
  end

  describe "Auth.verify_token/1" do
    test "CRASH: valid token returns ok with claims" do
      token = Auth.generate_token(%{"user_id" => "user_1"})
      assert {:ok, claims} = Auth.verify_token(token)
      assert claims["user_id"] == "user_1"
    end

    test "CRASH: tampered signature returns error" do
      token = Auth.generate_token(%{"user_id" => "user_1"})
      [header, payload, _sig] = String.split(token, ".")
      tampered = "#{header}.#{payload}.badsignaturehere"
      assert {:error, :invalid_token} = Auth.verify_token(tampered)
    end

    test "CRASH: malformed token returns error" do
      assert {:error, :invalid_token} = Auth.verify_token("not-a-jwt")
    end

    test "CRASH: empty string returns error" do
      assert {:error, :invalid_token} = Auth.verify_token("")
    end

    test "CRASH: expired token returns error" do
      # Generate a token with exp in the past
      now = System.system_time(:second)
      header = %{"alg" => "HS256", "typ" => "JWT"}
      claims = %{"user_id" => "user_1", "iat" => now - 1000, "exp" => now - 500}
      header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
      payload_b64 = Base.url_encode64(Jason.encode!(claims), padding: false)
      signature = :crypto.mac(:hmac, :sha256, "test-secret-key-for-chicago-tdd", "#{header_b64}.#{payload_b64}")
      signature_b64 = Base.url_encode64(signature, padding: false)
      token = "#{header_b64}.#{payload_b64}.#{signature_b64}"
      assert {:error, :invalid_token} = Auth.verify_token(token)
    end
  end

  describe "Auth.generate_refresh_token/1" do
    test "CRASH: returns JWT string with 3 parts" do
      token = Auth.generate_refresh_token(%{"user_id" => "user_1"})
      parts = String.split(token, ".")
      assert length(parts) == 3
    end

    test "CRASH: includes type=refresh claim" do
      token = Auth.generate_refresh_token(%{"user_id" => "user_1"})
      [_header_b64, payload_b64, _sig] = String.split(token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, claims} = Jason.decode(payload_json)
      assert claims["type"] == "refresh"
    end

    test "CRASH: has longer expiration (7 days)" do
      token = Auth.generate_refresh_token(%{"user_id" => "user_1"})
      [_header_b64, payload_b64, _sig] = String.split(token, ".")
      {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
      {:ok, claims} = Jason.decode(payload_json)
      assert claims["exp"] - claims["iat"] == 604_800
    end
  end

  describe "Auth.refresh/1" do
    test "CRASH: valid refresh token returns new access + refresh" do
      refresh_token = Auth.generate_refresh_token(%{"user_id" => "user_1"})
      assert {:ok, result} = Auth.refresh(refresh_token)
      assert Map.has_key?(result, :token)
      assert Map.has_key?(result, :refresh_token)
      assert Map.has_key?(result, :expires_in)
      assert result.expires_in == 900
    end

    test "CRASH: new access token is verifiable" do
      refresh_token = Auth.generate_refresh_token(%{"user_id" => "user_1"})
      assert {:ok, result} = Auth.refresh(refresh_token)
      assert {:ok, claims} = Auth.verify_token(result.token)
      assert claims["user_id"] == "user_1"
    end

    test "CRASH: access token (not refresh) returns error" do
      access_token = Auth.generate_token(%{"user_id" => "user_1"})
      assert {:error, :not_refresh_token} = Auth.refresh(access_token)
    end

    test "CRASH: invalid token returns error" do
      assert {:error, :invalid_token} = Auth.refresh("bad-token")
    end
  end
end
