defmodule OptimalSystemAgent.Agent.Scheduler.PersistenceRealTest do
  @moduledoc """
  Chicago TDD integration tests for Agent.Scheduler.Persistence.

  NO MOCKS. Tests real file I/O, atomic writes, JSON parsing, validation.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Agent.Scheduler.Persistence

  setup do
    tmp_dir = System.tmp_dir!()
    test_dir = Path.join(tmp_dir, "osa_persistence_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(test_dir)

    original = Application.get_env(:optimal_system_agent, :config_dir)
    Application.put_env(:optimal_system_agent, :config_dir, test_dir)

    on_exit(fn ->
      if original, do: Application.put_env(:optimal_system_agent, :config_dir, original)
      File.rm_rf!(test_dir)
    end)

    {:ok, test_dir: test_dir}
  end

  describe "Persistence — crons_path/0 and triggers_path/0" do
    test "CRASH: crons_path points to config_dir/CRONS.json", %{test_dir: test_dir} do
      assert String.ends_with?(Persistence.crons_path(), "CRONS.json")
      assert String.starts_with?(Persistence.crons_path(), test_dir)
    end

    test "CRASH: triggers_path points to config_dir/TRIGGERS.json", %{test_dir: test_dir} do
      assert String.ends_with?(Persistence.triggers_path(), "TRIGGERS.json")
      assert String.starts_with?(Persistence.triggers_path(), test_dir)
    end
  end

  describe "Persistence.load_crons/1" do
    test "CRASH: returns state unchanged when no file exists" do
      state = %{cron_jobs: []}
      result = Persistence.load_crons(state)
      assert result == state
    end

    test "CRASH: loads valid CRONS.json" do
      jobs = [
        %{"name" => "test-job", "schedule" => "* * * * *", "type" => "command", "command" => "echo hi", "enabled" => true}
      ]

      File.write!(Persistence.crons_path(), Jason.encode!(%{"jobs" => jobs}))

      state = %{cron_jobs: []}
      result = Persistence.load_crons(state)
      assert result.cron_jobs == jobs
    end

    test "CRASH: handles disabled jobs (still loads all)" do
      jobs = [
        %{"name" => "disabled", "schedule" => "* * * * *", "type" => "command", "command" => "echo hi", "enabled" => false}
      ]

      File.write!(Persistence.crons_path(), Jason.encode!(%{"jobs" => jobs}))

      state = %{cron_jobs: []}
      result = Persistence.load_crons(state)
      assert length(result.cron_jobs) == 1
    end

    test "CRASH: returns state unchanged for invalid JSON" do
      File.write!(Persistence.crons_path(), "not json")

      state = %{cron_jobs: []}
      result = Persistence.load_crons(state)
      assert result == state
    end

    test "CRASH: returns state unchanged for unexpected format (no 'jobs' key)" do
      File.write!(Persistence.crons_path(), Jason.encode!(%{"not_jobs" => []}))

      state = %{cron_jobs: []}
      result = Persistence.load_crons(state)
      assert result == state
    end
  end

  describe "Persistence.load_triggers/1" do
    test "CRASH: returns state unchanged when no file exists" do
      state = %{trigger_handlers: %{}, triggers_raw: []}
      result = Persistence.load_triggers(state)
      assert result == state
    end

    test "CRASH: loads valid TRIGGERS.json" do
      triggers = [
        %{"id" => "t1", "name" => "test-trigger", "event" => "file_change", "type" => "command", "command" => "echo", "enabled" => true}
      ]

      File.write!(Persistence.triggers_path(), Jason.encode!(%{"triggers" => triggers}))

      state = %{trigger_handlers: %{}, triggers_raw: []}
      result = Persistence.load_triggers(state)
      assert Map.has_key?(result.trigger_handlers, "t1")
      assert result.triggers_raw == triggers
    end

    test "CRASH: disabled triggers not in handler map" do
      triggers = [
        %{"id" => "t1", "name" => "disabled", "event" => "x", "type" => "command", "command" => "echo", "enabled" => false}
      ]

      File.write!(Persistence.triggers_path(), Jason.encode!(%{"triggers" => triggers}))

      state = %{trigger_handlers: %{}, triggers_raw: []}
      result = Persistence.load_triggers(state)
      assert result.trigger_handlers == %{}
      assert result.triggers_raw == triggers
    end

    test "CRASH: returns state unchanged for invalid JSON" do
      File.write!(Persistence.triggers_path(), "broken")

      state = %{trigger_handlers: %{}, triggers_raw: []}
      result = Persistence.load_triggers(state)
      assert result == state
    end
  end

  describe "Persistence.update_crons/2" do
    test "CRASH: creates new CRONS.json atomically" do
      state = %{cron_jobs: []}

      assert {:ok, _updated} = Persistence.update_crons(state, fn _jobs ->
        [%{"name" => "new", "schedule" => "0 * * * *", "type" => "command", "command" => "ls", "enabled" => true}]
      end)

      assert File.exists?(Persistence.crons_path())

      content = File.read!(Persistence.crons_path())
      assert String.contains?(content, "new")
      assert String.contains?(content, "0 * * * *")
    end

    test "CRASH: no tmp file left after successful write" do
      state = %{cron_jobs: []}

      Persistence.update_crons(state, fn _ -> [] end)

      refute File.exists?(Persistence.crons_path() <> ".tmp")
    end
  end

  describe "Persistence.update_triggers/2" do
    test "CRASH: creates new TRIGGERS.json atomically" do
      state = %{trigger_handlers: %{}, triggers_raw: []}

      assert {:ok, _updated} = Persistence.update_triggers(state, fn _triggers ->
        [%{"id" => "t1", "name" => "trigger1", "event" => "change", "type" => "command", "command" => "echo", "enabled" => true}]
      end)

      assert File.exists?(Persistence.triggers_path())
    end

    test "CRASH: no tmp file left after successful write" do
      state = %{trigger_handlers: %{}, triggers_raw: []}

      Persistence.update_triggers(state, fn _ -> [] end)

      refute File.exists?(Persistence.triggers_path() <> ".tmp")
    end
  end

  describe "Persistence.validate_job/1" do
    test "CRASH: valid command job" do
      job = %{"name" => "test", "schedule" => "* * * * *", "type" => "command", "command" => "ls"}
      assert :ok == Persistence.validate_job(job)
    end

    test "CRASH: valid agent job" do
      job = %{"name" => "test", "schedule" => "0 * * * *", "type" => "agent", "job" => "check logs"}
      assert :ok == Persistence.validate_job(job)
    end

    test "CRASH: valid webhook job" do
      job = %{"name" => "test", "schedule" => "0 9 * * *", "type" => "webhook", "url" => "https://example.com/hook"}
      assert :ok == Persistence.validate_job(job)
    end

    test "CRASH: missing name returns error" do
      job = %{"schedule" => "* * * * *", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: empty name returns error" do
      job = %{"name" => "", "schedule" => "* * * * *", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: missing schedule returns error" do
      job = %{"name" => "test", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: invalid type returns error" do
      job = %{"name" => "test", "schedule" => "* * * * *", "type" => "unknown"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: agent job without 'job' field returns error" do
      job = %{"name" => "test", "schedule" => "* * * * *", "type" => "agent"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: command job without 'command' field returns error" do
      job = %{"name" => "test", "schedule" => "* * * * *", "type" => "command"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: webhook job without 'url' field returns error" do
      job = %{"name" => "test", "schedule" => "* * * * *", "type" => "webhook"}
      assert {:error, _} = Persistence.validate_job(job)
    end

    test "CRASH: invalid cron expression returns error" do
      job = %{"name" => "test", "schedule" => "not cron", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_job(job)
    end
  end

  describe "Persistence.validate_trigger/1" do
    test "CRASH: valid agent trigger" do
      trigger = %{"name" => "test", "event" => "file_change", "type" => "agent", "job" => "run checks"}
      assert :ok == Persistence.validate_trigger(trigger)
    end

    test "CRASH: valid command trigger" do
      trigger = %{"name" => "test", "event" => "file_change", "type" => "command", "command" => "make test"}
      assert :ok == Persistence.validate_trigger(trigger)
    end

    test "CRASH: missing name returns error" do
      trigger = %{"event" => "file_change", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_trigger(trigger)
    end

    test "CRASH: missing event returns error" do
      trigger = %{"name" => "test", "type" => "command", "command" => "ls"}
      assert {:error, _} = Persistence.validate_trigger(trigger)
    end

    test "CRASH: invalid type returns error" do
      trigger = %{"name" => "test", "event" => "change", "type" => "webhook"}
      assert {:error, _} = Persistence.validate_trigger(trigger)
    end

    test "CRASH: agent trigger without 'job' returns error" do
      trigger = %{"name" => "test", "event" => "change", "type" => "agent"}
      assert {:error, _} = Persistence.validate_trigger(trigger)
    end

    test "CRASH: command trigger without 'command' returns error" do
      trigger = %{"name" => "test", "event" => "change", "type" => "command"}
      assert {:error, _} = Persistence.validate_trigger(trigger)
    end
  end
end
