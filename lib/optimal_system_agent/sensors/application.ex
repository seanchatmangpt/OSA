defmodule OptimalSystemAgent.Sensors.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {OptimalSystemAgent.Sensors.SensorRegistry, []}
    ]

    opts = [strategy: :one_for_one, name: OptimalSystemAgent.Sensors.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
