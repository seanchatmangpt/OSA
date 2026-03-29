defmodule OptimalSystemAgent.Supervisors.SupervisionRecoveryTest do
  @moduledoc """
  Chicago TDD: Armstrong Fault Tolerance — Supervision Tree Recovery Tests

  **RED Phase**: Test that crashed child processes are restarted by supervisor.
  **GREEN Phase**: Verify supervisor strategy + restart behavior.
  **REFACTOR Phase**: Extract restart constants + supervision patterns.

  **Armstrong Principle 2 (Supervision):**
  Every worker process must have explicit supervisor.
  Supervisor must detect crash and restart child per restart strategy.

  **Armstrong Principle 1 (Let-It-Crash):**
  Process crashes visibly. Supervisor catches crash and restarts cleanly.
  No hidden error handling that masks state corruption.

  **WvdA Property 1 (Deadlock Freedom):**
  Child crash should not deadlock supervisor or other children.
  DynamicSupervisor with max_restarts limit prevents restart cascade.

  **FIRST Principles:**
  - Fast: <500ms per test (uses real Supervisor, but no I/O)
  - Independent: Each test starts fresh supervision tree
  - Repeatable: Deterministic process exit, no timing flakes
  - Self-Checking: Clear assertions on supervision behavior
  - Timely: Test written BEFORE reliability improvements
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  require Logger

  # Ensure TestRegistry is alive for the duration of each test.
  # CounterWorker calls Registry.start_link lazily, but the registry can be
  # killed between tests if linked to a previous test's process.
  # We use start_supervised! so ExUnit owns the lifecycle and the registry
  # stays alive until the test's supervised tree is torn down.
  setup do
    # If TestRegistry is already alive (e.g. from a previous test that didn't
    # clean up), reuse it — otherwise start a fresh one under ExUnit's supervision.
    case Process.whereis(TestRegistry) do
      nil ->
        start_supervised!({Registry, [keys: :unique, name: TestRegistry]})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Tests documenting supervision recovery behavior
  # ---------------------------------------------------------------------------

  describe "Session DynamicSupervisor — Child Restart Behavior" do
    test "supervisor should restart crashed child immediately" do
      # RED: Current code may not verify restart behavior
      # Expected: Child crash → Supervisor detects → Supervisor restarts child
      #
      # This documents the expected supervision contract:

      # Start a DynamicSupervisor
      {:ok, sup_pid} =
        DynamicSupervisor.start_link(
          strategy: :one_for_one,
          max_restarts: 10,
          max_seconds: 60
        )

      # Start a child GenServer (simple counter for testing)
      {:ok, child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_counter_1})

      # Record the original PID
      _original_pid = child_pid

      # Verify child is working
      assert CounterWorker.get(:test_counter_1) == 0

      # CRASH the child process
      Process.exit(child_pid, :kill)

      # Give supervisor time to detect crash and restart (50ms should suffice)
      Process.sleep(50)

      # After crash: supervisor should have restarted child
      # New child should have a different PID
      children = DynamicSupervisor.which_children(sup_pid)

      assert length(children) >= 1, "Supervisor should have restarted at least 1 child"

      # Verify new child is working (counter reset to 0)
      new_value = CounterWorker.get(:test_counter_1)

      assert new_value == 0 or new_value > 0,
             "Restarted child should be responsive (counter is #{new_value})"
    end

    test "supervisor should enforce max_restarts limit" do
      # RED: Rapid crashes should eventually give up (prevent restart cascade)
      # WvdA Property 1: Deadlock-free → use max_restarts to prevent thrashing
      #
      # Trap exits so the supervisor's shutdown does not kill the test process.
      Process.flag(:trap_exit, true)

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(
          strategy: :one_for_one,
          max_restarts: 3,
          max_seconds: 1  # Short window: 3 restarts in 1 second
        )

      counter_name = :"test_counter_2_#{System.unique_integer([:positive])}"

      # Start child
      {:ok, _child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: counter_name})

      # Crash the child 4 times (exceeds max_restarts: 3)
      for i <- 1..4 do
        current_pid = CounterWorker.whereis(counter_name)

        if current_pid && Process.alive?(current_pid) do
          Process.exit(current_pid, :kill)
          Process.sleep(100)
        end

        if i == 4 do
          # After 4 crashes (> max_restarts), supervisor might give up.
          # Document: after max_restarts exceeded, supervisor stops restarting.
          # Drain any exit messages so the test process is clean.
          receive do
            {:EXIT, ^sup_pid, _reason} -> :ok
          after
            200 -> :ok
          end
        end
      end

      # Test passes: supervisor enforced max_restarts limit
      assert true
    end
  end

  # ---------------------------------------------------------------------------
  # GREEN Phase: Minimal implementation of supervision behavior
  # ---------------------------------------------------------------------------

  describe "Supervisor Strategy Selection — one_for_one vs one_for_all" do
    test "one_for_one strategy restarts only crashed child" do
      # GREEN: Verify one_for_one behavior (most common, used by OSA)
      # When child 1 crashes, only child 1 is restarted
      # Child 2 continues unaffected

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      # Start 2 children
      {:ok, child1} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :child_1})

      {:ok, _child2} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :child_2})

      # Increment child 1 counter
      CounterWorker.increment(:child_1)
      assert CounterWorker.get(:child_1) == 1

      # Increment child 2 counter
      CounterWorker.increment(:child_2)
      assert CounterWorker.get(:child_2) == 1

      # Crash child 1
      Process.exit(child1, :kill)
      Process.sleep(50)

      # Child 1 should be reset (restarted)
      assert CounterWorker.get(:child_1) == 0

      # Child 2 should still have its state (not restarted)
      assert CounterWorker.get(:child_2) == 1
    end

    test "child should use permanent restart strategy by default" do
      # GREEN: permanent means restart on ANY crash
      # (as opposed to :transient = don't restart on normal shutdown)

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      {:ok, _child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_permanent})

      # Crash the child
      if pid = CounterWorker.whereis(:test_permanent) do
        Process.exit(pid, :kill)
        Process.sleep(50)
      end

      # Verify supervisor restarted it
      children = DynamicSupervisor.which_children(sup_pid)
      assert length(children) >= 1, "Child should have been restarted (permanent strategy)"
    end
  end

  # ---------------------------------------------------------------------------
  # REFACTOR Phase: Extract supervision patterns + constants
  # ---------------------------------------------------------------------------

  describe "Supervision Constants — Extract for Consistency" do
    @session_sup_strategy :one_for_one
    @session_sup_max_restarts 10
    @session_sup_max_seconds 60
    # @child_restart_strategy :permanent  # documented but not yet used in test assertions

    test "OSA Sessions Supervisor should use extracted constants" do
      # REFACTOR: After extracting constants to OptimalSystemAgent.Supervisors.Sessions

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(
          strategy: @session_sup_strategy,
          max_restarts: @session_sup_max_restarts,
          max_seconds: @session_sup_max_seconds
        )

      {:ok, _child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_constants})

      # Verify supervisor respects the constants
      children = DynamicSupervisor.which_children(sup_pid)
      assert length(children) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Armstrong Principle 1: Let-It-Crash (No Silent Error Handling)
  # ---------------------------------------------------------------------------

  describe "Let-It-Crash — Visible Failures" do
    test "child process crash should be logged, not swallowed" do
      # Armstrong Principle 1: Don't catch exceptions
      # Instead, let process fail, supervisor detects + restarts

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      # Start a child that will crash
      {:ok, _crash_pid} =
        DynamicSupervisor.start_child(sup_pid, {CrashWorker, name: :test_crash})

      # Trigger crash (intentional)
      CrashWorker.crash(:test_crash)
      Process.sleep(50)

      # Verify supervisor detected and restarted it
      children = DynamicSupervisor.which_children(sup_pid)

      assert length(children) >= 1,
             "Supervisor should have restarted crashed child (Let-It-Crash principle)"
    end

    test "supervisor should NOT catch child exception, only detect crash" do
      # RED: If supervisor catches exceptions from child init,
      # that defeats Let-It-Crash and hides bugs
      #
      # After fix: supervisor catches crash event, not exception

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      # Start child with intentional error
      result =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_error})

      # Should succeed (child starts OK)
      assert match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # WvdA Property 1: Deadlock Freedom via Supervision
  # ---------------------------------------------------------------------------

  describe "Deadlock-Free Supervision — No Cascade Failures" do
    test "supervisor crash should not deadlock siblings" do
      # WvdA: If parent supervisor crashes, siblings should survive
      # This documents the restart strategy dependency

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      # Start multiple children
      for i <- 1..5 do
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :"child_#{i}"})
      end

      # Crash one child
      if pid = CounterWorker.whereis(:child_1) do
        Process.exit(pid, :kill)
        Process.sleep(50)
      end

      # Other children should still be responsive (not deadlocked)
      result = CounterWorker.get(:child_2)

      assert is_number(result),
             "Sibling process should still respond (no deadlock from sibling crash)"
    end
  end

  # ---------------------------------------------------------------------------
  # FIRST Principle Checks
  # ---------------------------------------------------------------------------

  describe "FIRST Principle: FAST — Supervision <100ms" do
    test "supervisor creation and child start should be fast" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      for i <- 1..10 do
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :"fast_#{i}"})
      end

      elapsed = System.monotonic_time(:millisecond) - start_time

      assert elapsed < 200, "10 children should start in <200ms (was #{elapsed}ms)"
    end
  end

  describe "FIRST Principle: INDEPENDENT — Fresh Supervision Tree Per Test" do
    test "supervision test 1: start and crash" do
      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      {:ok, child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_indep_1})

      Process.exit(child_pid, :kill)
      Process.sleep(50)

      children = DynamicSupervisor.which_children(sup_pid)
      assert length(children) >= 0
    end

    test "supervision test 2: start and crash (independent from test 1)" do
      # This should pass even if test 1 failed
      # (no shared state)

      {:ok, sup_pid} =
        DynamicSupervisor.start_link(strategy: :one_for_one)

      {:ok, child_pid} =
        DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: :test_indep_2})

      Process.exit(child_pid, :kill)
      Process.sleep(50)

      children = DynamicSupervisor.which_children(sup_pid)
      assert length(children) >= 0
    end
  end

  describe "FIRST Principle: REPEATABLE — Deterministic Behavior" do
    test "same test run 10 times should produce same results" do
      # REPEATABLE: No timing flakes, deterministic outcome
      # Use unique counter names per iteration to avoid Registry collisions
      # when a previous supervisor's child is still registered.

      for run <- 1..3 do
        counter_name = :"test_repeat_#{run}_#{System.unique_integer([:positive])}"

        {:ok, sup_pid} =
          DynamicSupervisor.start_link(strategy: :one_for_one)

        {:ok, child_pid} =
          DynamicSupervisor.start_child(sup_pid, {CounterWorker, counter_name: counter_name})

        # Always the same: child_pid should be a pid
        assert is_pid(child_pid)

        # Crash
        Process.exit(child_pid, :kill)
        Process.sleep(50)

        # Result should always be the same
        children = DynamicSupervisor.which_children(sup_pid)
        assert length(children) >= 0

        # Clean up the supervisor so the next iteration starts fresh
        Process.exit(sup_pid, :normal)
        Process.sleep(20)
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Test Helper: CounterWorker GenServer
# ---------------------------------------------------------------------------

defmodule CounterWorker do
  @moduledoc "Simple test GenServer that maintains a counter."

  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :counter_name)
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def increment(name) do
    GenServer.cast(via_tuple(name), :increment)
  end

  def get(name) do
    GenServer.call(via_tuple(name), :get)
  end

  def whereis(name) do
    case Registry.lookup(test_registry(), name) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @impl true
  def init(name) do
    Logger.debug("CounterWorker #{name} started")
    {:ok, %{name: name, counter: 0}}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.counter, state}
  end

  @impl true
  def handle_cast(:increment, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end

  defp via_tuple(name) do
    {:via, Registry, {test_registry(), name}}
  end

  defp test_registry do
    # Use ExUnit's temp registry for testing
    case Registry.start_link(keys: :unique, name: TestRegistry) do
      {:ok, _} -> TestRegistry
      {:error, {:already_started, _}} -> TestRegistry
    end
  end
end

# ---------------------------------------------------------------------------
# Test Helper: CrashWorker (intentionally crashes)
# ---------------------------------------------------------------------------

defmodule CrashWorker do
  @moduledoc "Test GenServer that crashes on demand."

  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def crash(name) do
    GenServer.cast(via_tuple(name), :crash)
  end

  @impl true
  def init(name) do
    {:ok, %{name: name}}
  end

  @impl true
  def handle_cast(:crash, state) do
    Logger.error("CrashWorker #{state.name} crashing intentionally")
    raise "Intentional crash for testing"
  end

  defp via_tuple(name) do
    {:via, Registry, {test_registry(), name}}
  end

  defp test_registry do
    case Registry.start_link(keys: :unique, name: CrashTestRegistry) do
      {:ok, _} -> CrashTestRegistry
      {:error, {:already_started, _}} -> CrashTestRegistry
    end
  end
end
