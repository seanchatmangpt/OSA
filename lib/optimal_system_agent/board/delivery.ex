defmodule OptimalSystemAgent.Board.Delivery do
  @moduledoc """
  Push delivery for board chair briefings.

  Primary channel:  PGP-encrypted email via SMTP (using stdlib :gen_tcp / :ssl).
  Secondary channel: CLI-accessible encrypted file at ~/.osa/briefings/<timestamp>.enc

  Delivery sequence:
    1. Encrypt briefing via Auth.encrypt_briefing/1
    2. Attempt send_email/1
    3. On failure: retry up to @max_retries with @retry_delay_ms between attempts
    4. After all retries exhausted: fall back to store_for_cli/1

  Armstrong fault-tolerance:
  - No rescue in send_email/1 — failures propagate up to the retry loop
  - store_for_cli/1 is the last-resort fallback and MUST NOT fail
  - All GenServer calls carry a 5-second timeout

  Environment variables:
    BOARD_CHAIR_EMAIL  — recipient address for the encrypted briefing email
    SMTP_HOST          — SMTP relay hostname (default: localhost)
    SMTP_PORT          — SMTP port (default: 587)
    SMTP_USERNAME      — SMTP auth username (optional)
    SMTP_PASSWORD      — SMTP auth password (optional)
    SMTP_FROM          — sender address (default: osa@localhost)
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Board.Auth

  @max_retries 3
  @retry_delay_ms 5 * 60 * 1_000

  @briefings_dir Path.expand("~/.osa/briefings")

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Encrypts and delivers a briefing to the board chair.

  Tries email first; on failure retries up to @max_retries times.
  After all retries are exhausted the briefing is written to
  ~/.osa/briefings/<timestamp>.enc for CLI pickup.

  Returns {:ok, :delivered} | {:ok, :stored_for_cli} | {:error, reason}.
  """
  @spec deliver(String.t()) :: {:ok, :delivered} | {:ok, :stored_for_cli} | {:error, term()}
  def deliver(briefing_text) when is_binary(briefing_text) do
    GenServer.call(__MODULE__, {:deliver, briefing_text}, 5_000)
  end

  @doc """
  Lists briefings that are pending CLI pickup (stored under ~/.osa/briefings/).
  Returns a list of absolute file paths.
  """
  @spec list_pending_briefings() :: [String.t()]
  def list_pending_briefings do
    GenServer.call(__MODULE__, :list_pending_briefings, 5_000)
  end

  @doc """
  Removes all stored briefings after the board chair confirms receipt.
  Returns :ok.
  """
  @spec clear_delivered_briefings() :: :ok
  def clear_delivered_briefings do
    GenServer.call(__MODULE__, :clear_delivered_briefings, 5_000)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    File.mkdir_p!(@briefings_dir)
    Logger.info("[Board.Delivery] Initialized — briefings dir: #{@briefings_dir}")
    {:ok, %{delivery_count: 0, fallback_count: 0}}
  end

  @impl true
  def handle_call({:deliver, briefing_text}, _from, state) do
    result = do_deliver_with_retry(briefing_text, @max_retries)
    new_state =
      case result do
        {:ok, :delivered} -> %{state | delivery_count: state.delivery_count + 1}
        {:ok, :stored_for_cli} -> %{state | fallback_count: state.fallback_count + 1}
        _ -> state
      end
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:list_pending_briefings, _from, state) do
    files = list_briefing_files()
    {:reply, files, state}
  end

  @impl true
  def handle_call(:clear_delivered_briefings, _from, state) do
    list_briefing_files()
    |> Enum.each(&File.rm/1)

    Logger.info("[Board.Delivery] Cleared all stored briefings")
    {:reply, :ok, state}
  end

  # ---------------------------------------------------------------------------
  # Private — delivery logic
  # ---------------------------------------------------------------------------

  @spec do_deliver_with_retry(String.t(), non_neg_integer()) ::
          {:ok, :delivered} | {:ok, :stored_for_cli} | {:error, term()}
  defp do_deliver_with_retry(briefing_text, retries_remaining) do
    with {:ok, envelope} <- Auth.encrypt_briefing(briefing_text),
         encrypted_blob <- Jason.encode!(envelope) do
      attempt_email(encrypted_blob, retries_remaining)
    else
      {:error, :no_board_chair_configured} ->
        Logger.info(
          "[Board.Delivery] No board chair key configured — storing unencrypted to CLI fallback"
        )
        store_for_cli(briefing_text)
        {:ok, :stored_for_cli}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec attempt_email(String.t(), non_neg_integer()) ::
          {:ok, :delivered} | {:ok, :stored_for_cli} | {:error, term()}
  defp attempt_email(encrypted_blob, retries_remaining) do
    case send_email(encrypted_blob) do
      :ok ->
        Logger.info("[Board.Delivery] Briefing delivered via email")
        {:ok, :delivered}

      {:error, reason} when retries_remaining > 0 ->
        Logger.warning(
          "[Board.Delivery] Email failed (#{reason}), #{retries_remaining} retries remaining — " <>
            "waiting #{div(@retry_delay_ms, 60_000)}m"
        )
        Process.sleep(@retry_delay_ms)
        attempt_email(encrypted_blob, retries_remaining - 1)

      {:error, reason} ->
        Logger.warning(
          "[Board.Delivery] Email failed (#{reason}), all retries exhausted — falling back to CLI store"
        )
        store_for_cli(encrypted_blob)
        {:ok, :stored_for_cli}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — email sending (no rescue — let failures propagate to retry loop)
  # ---------------------------------------------------------------------------

  @spec send_email(String.t()) :: :ok | {:error, term()}
  defp send_email(encrypted_blob) do
    to = recipient_email()
    if is_nil(to) or to == "" do
      {:error, :no_recipient_configured}
    else
      host = smtp_host()
      port = smtp_port()
      from = smtp_from()
      date_str = date_string()
      message = build_smtp_message(from, to, date_str, encrypted_blob)
      send_via_smtp(host, port, from, to, message)
    end
  end

  @spec send_via_smtp(String.t(), non_neg_integer(), String.t(), String.t(), iodata()) ::
          :ok | {:error, term()}
  defp send_via_smtp(host, port, from, to, message) do
    host_charlist = String.to_charlist(host)
    username = System.get_env("SMTP_USERNAME")
    password = System.get_env("SMTP_PASSWORD")

    opts = [
      relay: host_charlist,
      port: port,
      username: username,
      password: password,
      ssl: port == 465,
      tls: if(port == 587, do: :always, else: :never),
      auth: if(username, do: :always, else: :never),
      timeout: 15_000
    ]

    Logger.debug("[Board.Delivery] Sending email to #{to} via #{host}:#{port}")

    case smtp_send(from, to, message, opts) do
      {:ok, _} ->
        :ok

      {:error, reason, _detail} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Thin wrapper so tests can mock the SMTP transport without patching :gen_tcp.
  # In production delegates to :gen_smtp_client if available (via apply to avoid
  # compile-time undefined-module warning), otherwise uses the built-in minimal
  # SMTP client over :gen_tcp / :ssl.
  @spec smtp_send(String.t(), String.t(), iodata(), keyword()) ::
          {:ok, term()} | {:error, term(), term()} | {:error, term()}
  defp smtp_send(from, to, message, opts) do
    if Code.ensure_loaded?(:gen_smtp_client) do
      apply(:gen_smtp_client, :send_blocking, [{from, [to], message}, opts])
    else
      minimal_smtp_send(from, to, message, opts)
    end
  end

  # Minimal RFC 5321 SMTP client using :gen_tcp / :ssl.
  # Handles EHLO, optional STARTTLS, optional AUTH LOGIN, MAIL FROM, RCPT TO,
  # DATA, and QUIT.  No rescue — TCP errors propagate as {:error, reason}.
  @spec minimal_smtp_send(String.t(), String.t(), iodata(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  defp minimal_smtp_send(from, to, message, opts) do
    host = opts[:relay]
    port = opts[:port] || 587
    timeout = opts[:timeout] || 15_000
    use_tls = opts[:tls] == :always
    use_ssl = opts[:ssl] == true

    socket_mod = if use_ssl, do: :ssl, else: :gen_tcp
    tcp_opts = [:binary, active: false, packet: :line]

    with {:ok, sock} <- socket_mod.connect(host, port, tcp_opts, timeout),
         {:ok, _banner} <- smtp_recv(sock, socket_mod),
         :ok <- smtp_send_line(sock, socket_mod, "EHLO osa.local"),
         {:ok, _caps} <- smtp_recv_multi(sock, socket_mod),
         {:ok, sock} <- maybe_starttls(sock, socket_mod, host, use_tls, tcp_opts, timeout),
         :ok <- maybe_auth(sock, socket_mod, opts),
         :ok <- smtp_send_line(sock, socket_mod, "MAIL FROM:<#{from}>"),
         {:ok, _} <- smtp_recv(sock, socket_mod),
         :ok <- smtp_send_line(sock, socket_mod, "RCPT TO:<#{to}>"),
         {:ok, _} <- smtp_recv(sock, socket_mod),
         :ok <- smtp_send_line(sock, socket_mod, "DATA"),
         {:ok, _} <- smtp_recv(sock, socket_mod),
         :ok <- socket_mod.send(sock, [message, "\r\n.\r\n"]),
         {:ok, response} <- smtp_recv(sock, socket_mod),
         :ok <- smtp_send_line(sock, socket_mod, "QUIT"),
         _ <- smtp_recv(sock, socket_mod),
         :ok <- socket_mod.close(sock) do
      {:ok, response}
    end
  end

  defp maybe_starttls(sock, :gen_tcp, host, true, _tcp_opts, timeout) do
    :gen_tcp.send(sock, "STARTTLS\r\n")
    case smtp_recv(sock, :gen_tcp) do
      {:ok, _} ->
        case :ssl.connect(sock, [server_name_indication: host], timeout) do
          {:ok, ssl_sock} ->
            smtp_send_line(ssl_sock, :ssl, "EHLO osa.local")
            smtp_recv_multi(ssl_sock, :ssl)
            {:ok, ssl_sock}
          err -> err
        end
      err -> err
    end
  end
  # Non-STARTTLS path: return the socket unchanged
  defp maybe_starttls(sock, _socket_mod, _host, _tls, _tcp_opts, _timeout), do: {:ok, sock}

  defp maybe_auth(sock, socket_mod, opts) do
    username = opts[:username]
    password = opts[:password]
    if username && password && opts[:auth] == :always do
      smtp_send_line(sock, socket_mod, "AUTH LOGIN")
      smtp_recv(sock, socket_mod)
      smtp_send_line(sock, socket_mod, Base.encode64(username))
      smtp_recv(sock, socket_mod)
      smtp_send_line(sock, socket_mod, Base.encode64(password))
      case smtp_recv(sock, socket_mod) do
        {:ok, "235" <> _} -> :ok
        {:ok, resp} -> {:error, {:auth_failed, resp}}
        err -> err
      end
    else
      :ok
    end
  end

  defp smtp_send_line(sock, mod, line), do: mod.send(sock, line <> "\r\n")

  defp smtp_recv(sock, mod) do
    case mod.recv(sock, 0, 15_000) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  # Read multi-line SMTP response (lines ending in "XXX-..." continue; "XXX " ends)
  defp smtp_recv_multi(sock, mod, acc \\ []) do
    case smtp_recv(sock, mod) do
      {:ok, line} ->
        if line =~ ~r/^\d{3} / do
          {:ok, Enum.reverse([line | acc])}
        else
          smtp_recv_multi(sock, mod, [line | acc])
        end
      err -> err
    end
  end

  defp build_smtp_message(from, to, date_str, encrypted_blob) do
    """
    From: OSA Board Intelligence <#{from}>
    To: #{to}
    Subject: Board Intelligence Briefing — #{date_str}
    MIME-Version: 1.0
    Content-Type: text/plain; charset=utf-8
    Content-Transfer-Encoding: base64
    X-OSA-Encrypted: true
    X-OSA-Version: 1

    #{Base.encode64(encrypted_blob)}
    """
  end

  # ---------------------------------------------------------------------------
  # Private — CLI fallback storage (must never fail)
  # ---------------------------------------------------------------------------

  @spec store_for_cli(String.t()) :: :ok
  defp store_for_cli(encrypted_blob) do
    File.mkdir_p!(@briefings_dir)
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    path = Path.join(@briefings_dir, "#{timestamp}.enc")

    case File.write(path, encrypted_blob) do
      :ok ->
        Logger.info("[Board.Delivery] Briefing stored for CLI at #{path}")
        :ok

      {:error, reason} ->
        # Last resort: log the error but do not raise — delivery must not crash
        Logger.error("[Board.Delivery] CRITICAL: Failed to write briefing to #{path}: #{reason}")
        :ok
    end
  end

  @spec list_briefing_files() :: [String.t()]
  defp list_briefing_files do
    case File.ls(@briefings_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".enc"))
        |> Enum.map(&Path.join(@briefings_dir, &1))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private — config helpers
  # ---------------------------------------------------------------------------

  defp recipient_email, do: System.get_env("BOARD_CHAIR_EMAIL")
  defp smtp_host, do: System.get_env("SMTP_HOST", "localhost")
  defp smtp_port, do: (System.get_env("SMTP_PORT", "587") |> String.to_integer())
  defp smtp_from, do: System.get_env("SMTP_FROM", "osa@localhost")
  defp date_string, do: Date.utc_today() |> Date.to_iso8601()
end
