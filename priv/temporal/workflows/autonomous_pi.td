{
  "name": "autonomous_pi",
  "description": "Autonomous Process Improvement workflow with 5 stages",
  "version": "1.0.0",
  "stages": [
    {
      "name": "discovery",
      "description": "OCPM finds inefficiencies from event logs",
      "activities": [
        "collect_event_logs",
        "run_alpha_miner",
        "detect_bottlenecks",
        "identify_improvement_opportunities"
      ],
      "timeout_seconds": 3600
    },
    {
      "name": "planning",
      "description": "Agent fleet designs improvement proposal",
      "activities": [
        "analyze_findings",
        "design_improvement",
        "create_proposal",
        "estimate_impact"
      ],
      "timeout_seconds": 7200
    },
    {
      "name": "execution",
      "description": "Multi-agent BFT consensus on proposal",
      "activities": [
        "initiate_bft_vote",
        "collect_votes",
        "verify_consensus",
        "execute_improvement"
      ],
      "timeout_seconds": 14400
    },
    {
      "name": "validation",
      "description": "Signal Theory quality gates verify results",
      "activities": [
        "measure_s_n_ratio",
        "verify_quality_gates",
        "assess_improvement",
        "generate_report"
      ],
      "timeout_seconds": 3600
    },
    {
      "name": "iteration",
      "description": "Continuous improvement loop",
      "activities": [
        "evaluate_results",
        "decide_next_iteration",
        "update_process_model",
        "archive_findings"
      ],
      "timeout_seconds": 1800
    }
  ],
  "retry_policy": {
    "max_attempts": 3,
    "initial_interval": "1s",
    "max_interval": "60s",
    "backoff_coefficient": 2.0
  },
  "signals": [
    {
      "name": "pause",
      "description": "Pause workflow for manual intervention"
    },
    {
      "name": "skip_stage",
      "description": "Skip to next stage"
    },
    {
      "name": "abort",
      "description": "Abort workflow execution"
    }
  ]
}
