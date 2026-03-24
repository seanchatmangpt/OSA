defmodule YawlService.Web.Handlers.Verify do
  @moduledoc """
  Verification endpoint handlers.
  """

  import Plug.Conn

  @doc """
  Handle single workflow verification request.
  """
  def handle(conn, %{"workflow" => workflow}) do
    # 1. Parse workflow
    case YawlService.Verification.Parser.parse(workflow) do
      {:ok, yawl_net} ->
        # 2. Verify soundness
        result = YawlService.Verification.Analyzer.verify(yawl_net)

        # 3. Generate certificate
        verification_id = generate_id()
        certificate = YawlService.Verification.Certificate.generate(
          verification_id,
          result
        )

        # 4. Store verification
        :verification_registry
        |> :ets.insert(verification_id, %{
          result: result,
          certificate: certificate,
          status: "complete"
        })

        # 5. Return response
        response = %{
          verification_id: verification_id,
          status: "complete",
          result: result,
          certificate: certificate
        }

        send_resp(conn, 200, Jason.encode!(response))

      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{
          error: "Parse error",
          reason: reason
        }))
    end
  end

  def handle(conn, _params) do
    send_resp(conn, 400, Jason.encode!(%{error: "Missing workflow parameter"}))
  end

  @doc """
  Handle batch workflow verification request.
  """
  def handle_batch(conn, %{"workflows" => workflows}) when is_list(workflows) do
    batch_id = generate_id()
    verification_ids = []

    # Process each workflow
    verification_ids = Enum.map(workflows, fn workflow ->
      {:ok, yawl_net} = YawlService.Verification.Parser.parse(workflow)
      result = YawlService.Verification.Analyzer.verify(yawl_net)
      verification_id = generate_id()
      certificate = YawlService.Verification.Certificate.generate(verification_id, result)

      :verification_registry
      |> :ets.insert(verification_id, %{
        result: result,
        certificate: certificate,
        status: "complete",
        batch_id: batch_id
      })

      verification_id
    end)

    response = %{
      batch_id: batch_id,
      status: "complete",
      verification_ids: verification_ids,
      completed: length(verification_ids),
      total: length(workflows)
    }

    send_resp(conn, 200, Jason.encode!(response))
  end

  def handle_batch(conn, _params) do
    send_resp(conn, 400, Jason.encode!(%{error: "Missing workflows array"}))
  end

  @doc """
  Get verification status.
  """
  def status(conn, id) do
    case :ets.lookup(:verification_registry, id) do
      [{^id, data}] ->
        send_resp(conn, 200, Jason.encode!(%{
          verification_id: id,
          status: data.status,
          result: data.result
        }))

      [] ->
        send_resp(conn, 404, Jason.encode!(%{error: "Verification not found"}))
    end
  end

  # Generate unique verification ID
  defp generate_id do
    :crypto.strong_rand_bytes(12)
    |> Base.encode16(case: :lower)
    |> then(&:binary_part(&1, 0, 12))
    |> then<>("ver-" <> &1)
  end
end
