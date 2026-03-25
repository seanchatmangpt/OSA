defmodule YawlService.Application do
  @moduledoc """
  YAWL Verification Service Application

  Formal correctness as a service for workflow verification.
  """

  use Application

  def start(_type, _args) do
    children = [
      {YawlService.Web.Router, []},
      {YawlService.Verification.Registry, name: :verification_registry}
    ]

    opts = [strategy: :one_for_one, name: YawlService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
