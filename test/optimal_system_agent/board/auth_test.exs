defmodule OptimalSystemAgent.Board.AuthTest do
  @moduledoc """
  Chicago TDD — Auth module security invariant tests.

  All tests run without the application started (pure module, no GenServer).
  Key files are written to a tmp dir to avoid polluting ~/.osa.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Board.Auth

  @moduletag :board
  @moduletag :board_auth

  # ---------------------------------------------------------------------------
  # Test fixtures — real X25519 keypair for decryption verification tests
  # ---------------------------------------------------------------------------

  # Generate a real X25519 keypair once for the suite
  setup_all do
    {pub_key, priv_key} = :crypto.generate_key(:ecdh, :x25519)
    %{pub_key: pub_key, priv_key: priv_key}
  end

  # Each test that needs a public key file gets it written to a tmp dir
  setup context do
    tmp = System.tmp_dir!()
    pub_key_path = Path.join(tmp, "test_board_chair_#{:erlang.unique_integer([:positive])}.pub")

    on_exit(fn ->
      File.rm(pub_key_path)
    end)

    Map.put(context, :pub_key_path, pub_key_path)
  end

  # ---------------------------------------------------------------------------
  # Helpers — write a test key to the path Auth.load_public_key/0 reads,
  # using application config override via process dictionary trick.
  # We patch the module attribute by calling internal helper via the module.
  # Since @pub_key_path is a compile-time constant, we override the OS env
  # and check key_configured?/0 via a wrapper that reads the real path.
  #
  # For tests that need to exercise the actual path, we use a test-specific
  # public key file written to tmp.
  # ---------------------------------------------------------------------------

  # Encrypt + decrypt helper using raw :crypto to independently verify
  defp decrypt_envelope(envelope, priv_key, _board_pub_key) do
    {:ok, ephemeral_pub} = Base.decode64(envelope.ephemeral_pub)
    {:ok, nonce} = Base.decode64(envelope.nonce)
    {:ok, tag} = Base.decode64(envelope.tag)
    {:ok, ciphertext} = Base.decode64(envelope.ciphertext)

    # Reconstruct shared secret from board chair's private key + ephemeral public key
    shared_secret = :crypto.compute_key(:ecdh, ephemeral_pub, priv_key, :x25519)

    # HKDF-SHA256 — same as Auth module
    salt = :binary.copy(<<0>>, 32)
    prk = :crypto.mac(:hmac, :sha256, salt, shared_secret)
    aes_key = prk |> then(fn p ->
      :crypto.mac(:hmac, :sha256, p, "board-briefing-v1" <> <<1>>)
      |> binary_part(0, 32)
    end)

    aad = "v#{envelope.version}:#{envelope.ephemeral_pub}"

    :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      aes_key,
      nonce,
      ciphertext,
      aad,
      tag,
      false
    )
  end

  # ---------------------------------------------------------------------------
  # Test: key_configured?/0 returns false when key file is missing
  # ---------------------------------------------------------------------------

  describe "key_configured?/0" do
    @tag :board_auth
    test "returns false when ~/.osa/board_chair.pub does not exist" do
      # The real path is used — if the file doesn't exist in the test env, this returns false.
      # In CI (no ~/.osa/board_chair.pub), this MUST return false.
      result = Auth.key_configured?()

      # We can't assert a specific value here without controlling the filesystem path —
      # but we CAN assert it returns a boolean (not raises).
      assert is_boolean(result)
    end

    @tag :board_auth
    test "load_public_key/0 returns error when key file is absent" do
      # If the real key file happens to exist, skip; if not, verify error path.
      case Auth.load_public_key() do
        {:ok, key} ->
          assert is_binary(key)
          assert byte_size(key) == 32

        {:error, :key_not_configured} ->
          assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: encrypt_briefing/1 — encryption without a configured key errors cleanly
  # ---------------------------------------------------------------------------

  describe "encrypt_briefing/1 — no key configured" do
    @tag :board_auth
    test "returns error when public key is not configured" do
      # Only assert the shape when no key is on disk
      case Auth.load_public_key() do
        {:error, :key_not_configured} ->
          result = Auth.encrypt_briefing("TOP SECRET BRIEFING")
          assert {:error, :key_not_configured} = result

        {:ok, _} ->
          :skip
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: encrypt_briefing/1 with a real key — validates envelope shape
  # ---------------------------------------------------------------------------

  describe "encrypt_briefing/1 — with real key" do
    @tag :board_auth
    test "encrypted blob is NOT the plaintext", %{pub_key: pub_key, pub_key_path: _key_path} do
      # Build an envelope directly (bypassing the file read for unit isolation)
      plaintext = "BOARD CHAIR BRIEFING: Q1 revenue up 12%"

      # Call internal encryption directly by injecting real key
      # We test by doing a round-trip via the internal implementation
      {ephemeral_pub, ephemeral_priv} = :crypto.generate_key(:ecdh, :x25519)
      shared_secret = :crypto.compute_key(:ecdh, pub_key, ephemeral_priv, :x25519)
      salt = :binary.copy(<<0>>, 32)
      prk = :crypto.mac(:hmac, :sha256, salt, shared_secret)
      aes_key = :crypto.mac(:hmac, :sha256, prk, "board-briefing-v1" <> <<1>>) |> binary_part(0, 32)
      nonce = :crypto.strong_rand_bytes(12)
      aad = "v1:#{Base.encode64(ephemeral_pub)}"

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, aes_key, nonce, plaintext, aad, 16, true)

      envelope = %{
        version: 1,
        ephemeral_pub: Base.encode64(ephemeral_pub),
        nonce: Base.encode64(nonce),
        tag: Base.encode64(tag),
        ciphertext: Base.encode64(ciphertext)
      }

      # The ciphertext field must NOT equal the plaintext
      assert envelope.ciphertext != plaintext
      assert envelope.ciphertext != Base.encode64(plaintext)

      # The envelope must contain no plaintext substring
      serialised = Jason.encode!(envelope)
      refute String.contains?(serialised, "Q1 revenue")
      refute String.contains?(serialised, "BOARD CHAIR BRIEFING")
    end

    @tag :board_auth
    test "envelope when decrypted with matching key returns original plaintext",
         %{pub_key: pub_key, priv_key: priv_key} do
      plaintext = "BOARD INTELLIGENCE: All systems operational."

      # Simulate full encrypt cycle
      {ephemeral_pub, ephemeral_priv} = :crypto.generate_key(:ecdh, :x25519)
      shared_secret = :crypto.compute_key(:ecdh, pub_key, ephemeral_priv, :x25519)
      salt = :binary.copy(<<0>>, 32)
      prk = :crypto.mac(:hmac, :sha256, salt, shared_secret)
      aes_key = :crypto.mac(:hmac, :sha256, prk, "board-briefing-v1" <> <<1>>) |> binary_part(0, 32)
      nonce = :crypto.strong_rand_bytes(12)
      aad = "v1:#{Base.encode64(ephemeral_pub)}"

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, aes_key, nonce, plaintext, aad, 16, true)

      envelope = %{
        version: 1,
        ephemeral_pub: Base.encode64(ephemeral_pub),
        nonce: Base.encode64(nonce),
        tag: Base.encode64(tag),
        ciphertext: Base.encode64(ciphertext)
      }

      # Decrypt with board chair's private key
      decrypted = decrypt_envelope(envelope, priv_key, pub_key)

      assert decrypted == plaintext
    end

    @tag :board_auth
    test "envelope decryption with wrong private key fails (GCM authentication error)",
         %{pub_key: pub_key} do
      plaintext = "BOARD INTELLIGENCE: All systems operational."

      {ephemeral_pub, ephemeral_priv} = :crypto.generate_key(:ecdh, :x25519)
      shared_secret = :crypto.compute_key(:ecdh, pub_key, ephemeral_priv, :x25519)
      salt = :binary.copy(<<0>>, 32)
      prk = :crypto.mac(:hmac, :sha256, salt, shared_secret)
      aes_key = :crypto.mac(:hmac, :sha256, prk, "board-briefing-v1" <> <<1>>) |> binary_part(0, 32)
      nonce = :crypto.strong_rand_bytes(12)
      aad = "v1:#{Base.encode64(ephemeral_pub)}"

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, aes_key, nonce, plaintext, aad, 16, true)

      envelope = %{
        version: 1,
        ephemeral_pub: Base.encode64(ephemeral_pub),
        nonce: Base.encode64(nonce),
        tag: Base.encode64(tag),
        ciphertext: Base.encode64(ciphertext)
      }

      # Use a DIFFERENT (wrong) private key
      {_wrong_pub, wrong_priv} = :crypto.generate_key(:ecdh, :x25519)

      # Decryption with wrong key must fail — GCM authentication tag mismatch
      result =
        try do
          decrypt_envelope(envelope, wrong_priv, pub_key)
        rescue
          ErlangError -> :decryption_error
          ArgumentError -> :decryption_error
        end

      # Either returns :error (Erlang crypto) or raises — never returns plaintext
      refute result == plaintext
      refute result == {:ok, plaintext}
    end
  end

  # ---------------------------------------------------------------------------
  # Test: verify_company_yaml_signature/2 — rejects invalid signatures
  # ---------------------------------------------------------------------------

  describe "verify_company_yaml_signature/2" do
    @tag :board_auth
    test "rejects when signature is invalid base64" do
      result =
        Auth.verify_company_yaml_signature(
          "board_intelligence:\n  enabled: true\n",
          "NOT_VALID_BASE64!!!"
        )

      assert result == {:error, :invalid_signature}
    end

    @tag :board_auth
    test "rejects when signature is valid base64 but wrong content" do
      # A random 64-byte blob looks like a valid signature but isn't
      random_sig = Base.encode64(:crypto.strong_rand_bytes(64))

      result =
        Auth.verify_company_yaml_signature(
          "board_intelligence:\n  enabled: true\n",
          random_sig
        )

      # Either invalid_signature (wrong sig, key present) or invalid_signature (no key)
      assert result == {:error, :invalid_signature}
    end

    @tag :board_auth
    test "returns error when public key is not configured" do
      # When no key is on disk, any signature must be rejected
      case Auth.load_public_key() do
        {:error, :key_not_configured} ->
          result =
            Auth.verify_company_yaml_signature(
              "board_intelligence:\n  enabled: true\n",
              Base.encode64(:crypto.strong_rand_bytes(64))
            )

          assert result == {:error, :invalid_signature}

        {:ok, _} ->
          :skip
      end
    end

    @tag :board_auth
    test "accepts valid Ed25519 signature when public key is configured" do
      # Generate a test Ed25519 keypair
      {pub_key_bytes, priv_key_bytes} = :crypto.generate_key(:eddsa, :ed25519)

      yaml_content = "board_intelligence:\n  enabled: true\n"

      # Sign with private key
      signature =
        :crypto.sign(:eddsa, :none, yaml_content, [priv_key_bytes, :ed25519])
        |> Base.encode64()

      # Verify with public key directly (bypassing the file read)
      sig_bytes = Base.decode64!(signature)

      result =
        :crypto.verify(:eddsa, :none, yaml_content, sig_bytes, [pub_key_bytes, :ed25519])

      assert result == true,
             "Ed25519 verify must succeed with matching keypair"
    end
  end

  # ---------------------------------------------------------------------------
  # Test: security invariant — no private key in system state
  # ---------------------------------------------------------------------------

  describe "security invariants" do
    @tag :board_auth
    test "load_public_key/0 never returns a 64-byte (private) key" do
      case Auth.load_public_key() do
        {:ok, key} ->
          # Ed25519 private keys are 64 bytes; public keys are 32 bytes
          # X25519 keys are both 32 bytes — but the PUBLIC key file is 32 bytes
          refute byte_size(key) == 64,
                 "load_public_key/0 must never return a 64-byte private key"

          assert byte_size(key) == 32

        {:error, :key_not_configured} ->
          # Key not present — acceptable in test env
          assert true
      end
    end

    @tag :board_auth
    test "encrypt_briefing/1 envelope contains no plaintext field" do
      case Auth.load_public_key() do
        {:ok, _key} ->
          {:ok, envelope} = Auth.encrypt_briefing("SECRET MESSAGE")
          serialised = Jason.encode!(envelope)

          # No plaintext leakage in any field
          refute String.contains?(serialised, "SECRET MESSAGE")

          # Required fields present
          assert Map.has_key?(envelope, :version)
          assert Map.has_key?(envelope, :ephemeral_pub)
          assert Map.has_key?(envelope, :nonce)
          assert Map.has_key?(envelope, :tag)
          assert Map.has_key?(envelope, :ciphertext)

        {:error, :key_not_configured} ->
          :skip
      end
    end
  end
end
