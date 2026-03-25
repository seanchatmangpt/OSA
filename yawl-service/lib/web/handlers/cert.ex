defmodule YawlService.Web.Handlers.Cert do
  @moduledoc """
  Certificate retrieval handlers.
  """

  import Plug.Conn

  @doc """
  Retrieve verification certificate.
  """
  def retrieve(conn, id) do
    case :ets.lookup(:verification_registry, id) do
      [{^id, data}] ->
        send_resp(conn, 200, Jason.encode!(%{
          certificate: data.certificate
        }))

      [] ->
        send_resp(conn, 404, Jason.encode!(%{error: "Certificate not found"}))
    end
  end
end
