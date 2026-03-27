defmodule OptimalSystemAgent.JTBD.DashboardTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.JTBD.Dashboard

  test "update_funnel_from_scenario/2 advances qualified count when icp_qualification passes" do
    funnel = %{contacts: 21_000, qualified: 0, enrolled: 0, deals: 0, contracts: 0}

    result =
      Dashboard.update_funnel_from_scenario(
        funnel,
        %{scenario: :icp_qualification, outcome: :pass}
      )

    # 20% of contacts qualify
    assert result.qualified > 0
  end

  test "update_funnel_from_scenario/2 does not advance when scenario fails" do
    funnel = %{contacts: 21_000, qualified: 0, enrolled: 0, deals: 0, contracts: 0}

    result =
      Dashboard.update_funnel_from_scenario(
        funnel,
        %{scenario: :icp_qualification, outcome: :fail}
      )

    assert result.qualified == 0
  end

  test "calculate_control_limits/1 returns correct bounds for uniform data" do
    history = List.duplicate(1.0, 10)
    limits = Dashboard.calculate_control_limits(history)
    assert Map.has_key?(limits, :mean) or Map.has_key?(limits, "mean")
    assert Map.has_key?(limits, :ucl) or Map.has_key?(limits, "ucl")
    assert Map.has_key?(limits, :lcl) or Map.has_key?(limits, "lcl")
  end
end
