# Auto-detect if the OTP application has been started
app_started =
  Application.started_applications()
  |> Enum.any?(fn {app, _, _} -> app == :optimal_system_agent end)

exclude = [:integration, :requires_llm, :sparql_benchmark] ++ if(app_started, do: [], else: [:requires_application])
ExUnit.start(exclude: exclude)
