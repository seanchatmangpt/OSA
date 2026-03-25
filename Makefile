.PHONY: setup dev test compile check clean doctor

# Development
setup:
	mix setup

dev:
	mix osa.serve

# Testing
test:
	mix test --no-start

test-all:
	mix test

test-coverage:
	mix test --coverage --cover-filter=optimal_system_agent

test-vision2030:
	mix test test/optimal_system_agent/healing/ test/optimal_system_agent/hooks/ test/optimal_system_agent/process/ test/optimal_system_agent/commerce/ test/optimal_system_agent/verification/

# Quality
compile:
	mix compile --warnings-as-errors

check: compile test
	@echo "All checks passed"

format:
	mix format

format-check:
	mix format --check-formatted

# Cleanup
clean:
	mix clean

doctor:
	@echo "OSA Doctor Checklist"
	@echo "===================="
	@which elixir && elixir --version
	@which mix && mix --version
	@echo ""
	@echo "Checking compilation..."
	@mix compile --warnings-as-errors 2>&1 | tail -1
	@echo ""
	@echo "Checking format..."
	@mix format --check-formatted 2>&1 | tail -1
