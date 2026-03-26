.PHONY: setup dev test test-all test-coverage test-vision2030 compile check clean doctor format format-check help logs debug profile status

# Colors
BOLD  := \033[1m
RESET := \033[0m
GREEN := \033[32m
CYAN  := \033[36m
YELLOW := \033[33m
RED := \033[31m

.DEFAULT_GOAL := help

help: ## Show this help message
	@printf '$(BOLD)OSA — Optimal System Agent$(RESET)\n\n'
	@printf '$(YELLOW)Setup:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) First-time setup: deps.get + ecto.setup\n' 'setup'
	@printf '\n$(YELLOW)Development:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Start OSA server (:8089, ReAct loop, tools)\n' 'dev'
	@printf '\n$(YELLOW)Testing:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Run unit tests (no app boot, fast)\n' 'test'
	@printf '  $(CYAN)%-20s$(RESET) Run all tests (with app + ETS + GenServers)\n' 'test-all'
	@printf '  $(CYAN)%-20s$(RESET) Run coverage report on optimal_system_agent\n' 'test-coverage'
	@printf '  $(CYAN)%-20s$(RESET) Run Vision 2030 tests (healing + hooks + process + commerce + verification)\n' 'test-vision2030'
	@printf '\n$(YELLOW)Quality & Checking:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Compile with zero-tolerance warnings\n' 'compile'
	@printf '  $(CYAN)%-20s$(RESET) Run compile + test (full quality gate)\n' 'check'
	@printf '  $(CYAN)%-20s$(RESET) Format code with mix format\n' 'format'
	@printf '  $(CYAN)%-20s$(RESET) Check formatting without modifying\n' 'format-check'
	@printf '\n$(YELLOW)Logs & Debugging:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Follow server logs (OSA running at :8089)\n' 'logs'
	@printf '  $(CYAN)%-20s$(RESET) Open interactive shell with app running\n' 'debug'
	@printf '  $(CYAN)%-20s$(RESET) Show memory/CPU usage of OSA process\n' 'profile'
	@printf '  $(CYAN)%-20s$(RESET) Check OSA server health\n' 'status'
	@printf '\n$(YELLOW)Environment:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Check prerequisites and environment\n' 'doctor'
	@printf '\n$(YELLOW)Cleanup:$(RESET)\n'
	@printf '  $(CYAN)%-20s$(RESET) Clean all build artifacts\n' 'clean'
	@printf '\n'

# ── Setup ──────────────────────────────────────────────────────────────────

setup: ## First-time setup: deps.get + ecto.setup
	@printf '$(BOLD)Running mix setup...$(RESET)\n'
	mix setup

# ── Development ────────────────────────────────────────────────────────────

dev: ## Start OSA server (:8089, ReAct loop, tools)
	@printf '$(BOLD)Starting OSA server...$(RESET)\n'
	@printf '$(GREEN)Listening on :8089$(RESET)\n'
	mix osa.serve

# ── Testing ────────────────────────────────────────────────────────────────

test: ## Run unit tests (no app boot, fast)
	@printf '$(BOLD)Running unit tests (--no-start)...$(RESET)\n'
	mix test --no-start

test-all: ## Run all tests (with app + ETS + GenServers)
	@printf '$(BOLD)Running all tests (including integration)...$(RESET)\n'
	mix test

test-coverage: ## Run coverage report on optimal_system_agent
	@printf '$(BOLD)Generating coverage report...$(RESET)\n'
	mix test --coverage --cover-filter=optimal_system_agent
	@printf '\n$(GREEN)✓ Coverage report generated$(RESET)\n'

test-vision2030: ## Run Vision 2030 tests (healing + hooks + process + commerce + verification)
	@printf '$(BOLD)Running Vision 2030 integration tests...$(RESET)\n'
	mix test test/optimal_system_agent/healing/ test/optimal_system_agent/hooks/ test/optimal_system_agent/process/ test/optimal_system_agent/commerce/ test/optimal_system_agent/verification/

# ── Quality & Checking ─────────────────────────────────────────────────────

compile: ## Compile with zero-tolerance warnings
	@printf '$(BOLD)Compiling with --warnings-as-errors...$(RESET)\n'
	mix compile --warnings-as-errors --parallel --max-concurrency 8
	@printf '$(GREEN)✓ Compilation successful$(RESET)\n'

check: compile test ## Run compile + test (full quality gate)
	@printf '$(GREEN)✓ All checks passed$(RESET)\n'

format: ## Format code with mix format
	@printf '$(BOLD)Formatting code...$(RESET)\n'
	mix format
	@printf '$(GREEN)Code formatted$(RESET)\n'

format-check: ## Check formatting without modifying
	@printf '$(BOLD)Checking format...$(RESET)\n'
	mix format --check-formatted

# ── Logs & Debugging ───────────────────────────────────────────────────────

logs: ## Follow server logs (OSA running at :8089)
	@printf '$(BOLD)Following OSA server logs...$(RESET)\n'
	mix osa.serve 2>&1 | tee /tmp/osa.log

debug: ## Open interactive shell with app running
	@printf '$(BOLD)Opening interactive shell...$(RESET)\n'
	@printf '$(CYAN)Type:$(RESET) $(GREEN)exit()$(RESET) to quit\n'
	iex -S mix osa.serve

profile: ## Show memory/CPU usage of OSA process
	@printf '$(BOLD)OSA Process Information:$(RESET)\n'
	@ps aux 2>/dev/null | grep -E "mix osa.serve|iex" | grep -v grep | awk '{printf "  PID: %6s | MEM: %6sKB | CPU: %5s%%\n", $$2, $$6, $$3}' || echo "  (OSA not running)"

status: ## Check OSA server health
	@printf '$(BOLD)OSA Server Status:$(RESET)\n'
	@curl -s http://localhost:8089/health >/dev/null 2>&1 && printf "  $(GREEN)Server: UP$(RESET) (:8089)\n" || printf "  $(RED)Server: DOWN$(RESET) (:8089)\n"

# ── Cleanup ────────────────────────────────────────────────────────────────

clean: ## Clean all build artifacts
	@printf '$(BOLD)Cleaning build artifacts...$(RESET)\n'
	mix clean
	@printf '$(GREEN)Cleaned$(RESET)\n'

# ── Environment ────────────────────────────────────────────────────────────

doctor: ## Check prerequisites and environment
	@printf '$(BOLD)OSA Environment Check$(RESET)\n\n'
	@printf '$(YELLOW)Prerequisites:$(RESET)\n'
	@command -v elixir >/dev/null 2>&1 && printf "  $(GREEN)Elixir:$(RESET) $$(elixir --version | head -1)\n" || printf "  $(RED)Elixir: MISSING$(RESET)\n"
	@command -v mix >/dev/null 2>&1 && printf "  $(GREEN)Mix:$(RESET) OK\n" || printf "  $(RED)Mix: MISSING$(RESET)\n"
	@command -v erl >/dev/null 2>&1 && printf "  $(GREEN)Erlang:$(RESET) $$(erl -version 2>&1 | head -1)\n" || printf "  $(RED)Erlang: MISSING$(RESET)\n"
	@printf '\n$(YELLOW)Compilation Check:$(RESET)\n'
	@mix compile --warnings-as-errors 2>&1 | tail -1
	@printf '\n$(YELLOW)Format Check:$(RESET)\n'
	@mix format --check-formatted 2>&1 | tail -1
	@printf '\n$(YELLOW)Port Availability:$(RESET)\n'
	@lsof -ti:8089 >/dev/null 2>&1 && printf "  $(GREEN)8089:$(RESET) IN USE (OSA)\n" || printf "  8089: free\n"
	@printf '\n'
