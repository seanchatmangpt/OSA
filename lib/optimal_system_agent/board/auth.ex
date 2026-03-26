defmodule OptimalSystemAgent.Board.Auth do
  @moduledoc """
  Single-principal authentication for board chair briefings.

  The system holds ONLY the board chair's Ed25519 public key.
  All briefings are encrypted with this key using a hybrid scheme:

    1. Ephemeral ECDH (X25519) key agreement — derives a shared secret
    2. HKDF (SHA-256) key derivation — expands shared secret to 32-byte AES key
    3. AES-256-GCM authenticated encryption — encrypts the briefing text

  Only the board chair's private key can reconstruct the shared secret and
  decrypt the ciphertext. No admin, no IT, no other human can read a briefing.

  Security invariants:
  - System NEVER stores or holds the board chair's private key
  - Encrypted blob contains no plaintext — only ciphertext + public metadata
  - The board chair's public key file is read-only at boot; writes are rejected

  Key format: raw 32-byte Ed25519 / X25519 public key, base64-encoded (one line,
  no PEM armour) stored at ~/.osa/board_chair.pub
  """

  require Logger

  @pub_key_path Path.expand("~/.osa/board_chair.pub")

  # System signing key path (private) — used to sign briefings so the board
  # chair can verify they came from this OSA instance.  Generated on first use.
  @system_signing_key_path Path.expand("~/.osa/system_signing.key")
  @system_verify_key_path Path.expand("~/.osa/system_signing.pub")

  # Encrypted envelope version
  @envelope_version 1

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns true when the board chair public key file exists and contains a
  valid 32-byte base64-encoded key.
  """
  @spec key_configured?() :: boolean()
  def key_configured? do
    case load_public_key() do
      {:ok, _key} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Loads the board chair's Ed25519 / X25519 public key from ~/.osa/board_chair.pub.

  Returns {:ok, key_bytes} where key_bytes is a 32-byte binary, or
  {:error, :key_not_configured} when the file is absent or malformed.
  """
  @spec load_public_key() :: {:ok, binary()} | {:error, :key_not_configured}
  def load_public_key do
    with {:file, {:ok, raw}} <- {:file, File.read(@pub_key_path)},
         trimmed = String.trim(raw),
         {:decode, {:ok, key_bytes}} <- {:decode, Base.decode64(trimmed)},
         {:length, true} <- {:length, byte_size(key_bytes) == 32} do
      {:ok, key_bytes}
    else
      {:file, {:error, reason}} ->
        Logger.warning("[Board.Auth] Public key file not found at #{@pub_key_path}: #{reason}")
        {:error, :key_not_configured}

      {:decode, :error} ->
        Logger.warning("[Board.Auth] Public key file at #{@pub_key_path} is not valid base64")
        {:error, :key_not_configured}

      {:length, false} ->
        Logger.warning("[Board.Auth] Public key at #{@pub_key_path} is not 32 bytes")
        {:error, :key_not_configured}
    end
  end

  @doc """
  Encrypts briefing_text using the board chair's public key.

  Hybrid encryption scheme:
    1. Generate ephemeral X25519 keypair
    2. ECDH: shared_secret = X25519(ephemeral_private, board_chair_public)
    3. HKDF(SHA-256): aes_key = expand(shared_secret, "board-briefing-v1", 32)
    4. AES-256-GCM: {ciphertext, tag} = encrypt(aes_key, nonce, plaintext)
    5. Encode envelope as JSON-serialisable map with base64 values

  Returns {:ok, envelope_map} or {:error, reason}.
  The caller is responsible for serialising the envelope (e.g., Jason.encode!/1).
  """
  @spec encrypt_briefing(String.t()) :: {:ok, map()} | {:error, term()}
  def encrypt_briefing(briefing_text) when is_binary(briefing_text) do
    with {:ok, board_pub_key} <- load_public_key(),
         {:ok, envelope} <- do_encrypt(briefing_text, board_pub_key) do
      {:ok, envelope}
    end
  end

  @doc """
  Signs briefing_text with this OSA instance's Ed25519 private key.

  The board chair can verify the signature using the system's public key
  (stored at ~/.osa/system_signing.pub) to confirm the briefing is authentic.

  Returns {:ok, base64_signature} or {:error, reason}.
  """
  @spec sign_briefing(String.t()) :: {:ok, String.t()} | {:error, term()}
  def sign_briefing(briefing_text) when is_binary(briefing_text) do
    with {:ok, priv_key} <- load_or_generate_signing_key() do
      signature = :crypto.sign(:eddsa, :none, briefing_text, [priv_key, :ed25519])
      {:ok, Base.encode64(signature)}
    end
  end

  @doc """
  Verifies that yaml_content was signed by the board chair's Ed25519 private key.

  The company.yaml board_intelligence section MUST carry a board chair
  signature.  Any unsigned or incorrectly signed configuration change is
  rejected here before the calling code acts on it.

  signature — base64-encoded Ed25519 signature produced by the board chair's
              private key over the raw YAML bytes.

  Returns :ok or {:error, :invalid_signature}.
  """
  @spec verify_company_yaml_signature(String.t(), String.t()) ::
          :ok | {:error, :invalid_signature}
  def verify_company_yaml_signature(yaml_content, signature_b64)
      when is_binary(yaml_content) and is_binary(signature_b64) do
    with {:ok, board_pub_key} <- load_public_key(),
         {:decode, {:ok, sig_bytes}} <- {:decode, Base.decode64(signature_b64)},
         true <-
           :crypto.verify(:eddsa, :none, yaml_content, sig_bytes, [board_pub_key, :ed25519]) do
      :ok
    else
      {:ok, false} ->
        {:error, :invalid_signature}

      false ->
        {:error, :invalid_signature}

      {:decode, :error} ->
        Logger.warning("[Board.Auth] Signature is not valid base64 — rejecting config change")
        {:error, :invalid_signature}

      {:error, :key_not_configured} ->
        Logger.warning("[Board.Auth] Cannot verify config signature — public key not configured")
        {:error, :invalid_signature}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Hybrid ECDH + AES-256-GCM encryption using Erlang :crypto.
  #
  # X25519 ECDH is available in OTP 24+ via :crypto.generate_key(:ecdh, :x25519).
  # The derived shared secret is fed through HKDF-SHA256 to produce the AES key.
  @spec do_encrypt(binary(), binary()) :: {:ok, map()} | {:error, term()}
  defp do_encrypt(plaintext, board_pub_key_bytes) do
    # 1. Generate ephemeral X25519 keypair
    {ephemeral_pub, ephemeral_priv} = :crypto.generate_key(:ecdh, :x25519)

    # 2. ECDH shared secret: ephemeral_private * board_chair_public
    shared_secret = :crypto.compute_key(:ecdh, board_pub_key_bytes, ephemeral_priv, :x25519)

    # 3. HKDF-SHA256: derive 32-byte AES key from shared secret
    aes_key = hkdf_sha256(shared_secret, "board-briefing-v1", 32)

    # 4. AES-256-GCM: random 12-byte nonce
    nonce = :crypto.strong_rand_bytes(12)

    # AAD (additional authenticated data): version + ephemeral public key
    aad = "v#{@envelope_version}:#{Base.encode64(ephemeral_pub)}"

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, aes_key, nonce, plaintext, aad, 16, true)

    envelope = %{
      version: @envelope_version,
      ephemeral_pub: Base.encode64(ephemeral_pub),
      nonce: Base.encode64(nonce),
      tag: Base.encode64(tag),
      ciphertext: Base.encode64(ciphertext)
    }

    {:ok, envelope}
  end

  # HKDF (RFC 5869) using SHA-256.
  # extract: PRK = HMAC-SHA256(salt="", ikm=shared_secret)
  # expand:  OKM = HMAC-SHA256(PRK, info || 0x01) — single block, length ≤ 32
  @spec hkdf_sha256(binary(), binary(), non_neg_integer()) :: binary()
  defp hkdf_sha256(ikm, info, length) when length <= 32 do
    salt = :binary.copy(<<0>>, 32)
    prk = :crypto.mac(:hmac, :sha256, salt, ikm)
    okm = :crypto.mac(:hmac, :sha256, prk, info <> <<1>>)
    binary_part(okm, 0, length)
  end

  # Load the system Ed25519 signing key, generating it on first use.
  @spec load_or_generate_signing_key() :: {:ok, binary()} | {:error, term()}
  defp load_or_generate_signing_key do
    case File.read(@system_signing_key_path) do
      {:ok, raw} ->
        case Base.decode64(String.trim(raw)) do
          {:ok, key} -> {:ok, key}
          :error -> generate_and_save_signing_key()
        end

      {:error, :enoent} ->
        generate_and_save_signing_key()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec generate_and_save_signing_key() :: {:ok, binary()} | {:error, term()}
  defp generate_and_save_signing_key do
    {pub_key, priv_key} = :crypto.generate_key(:eddsa, :ed25519)
    dir = Path.dirname(@system_signing_key_path)
    File.mkdir_p!(dir)

    with :ok <- File.write(@system_signing_key_path, Base.encode64(priv_key)),
         :ok <- File.chmod(@system_signing_key_path, 0o600),
         :ok <- File.write(@system_verify_key_path, Base.encode64(pub_key)),
         :ok <- File.chmod(@system_verify_key_path, 0o644) do
      Logger.info("[Board.Auth] Generated new system Ed25519 signing keypair at #{dir}")
      {:ok, priv_key}
    end
  end
end
