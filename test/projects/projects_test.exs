defmodule OptimalSystemAgent.ProjectsTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Projects
  alias OptimalSystemAgent.Projects.{Project, Goal}
  alias OptimalSystemAgent.Store.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "projects" do
    test "create_project/1 with valid attrs" do
      assert {:ok, %Project{} = project} = Projects.create_project(%{name: "Test Project"})
      assert project.name == "Test Project"
      assert project.status == "active"
      assert project.slug == "test-project"
    end

    test "create_project/1 fails without name" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_project(%{})
    end

    test "create_project/1 generates slug from name" do
      {:ok, p} = Projects.create_project(%{name: "My Cool Project!!!"})
      assert p.slug == "my-cool-project"
    end

    test "list_projects/0 returns all projects" do
      {:ok, _} = Projects.create_project(%{name: "P1"})
      {:ok, _} = Projects.create_project(%{name: "P2"})
      assert length(Projects.list_projects()) == 2
    end

    test "list_projects/1 filters by status" do
      {:ok, _} = Projects.create_project(%{name: "Active"})
      {:ok, p2} = Projects.create_project(%{name: "Archived"})
      Projects.archive_project(p2)
      assert length(Projects.list_projects(status: "active")) == 1
      assert length(Projects.list_projects(status: "archived")) == 1
    end

    test "get_project/1 returns {:ok, project}" do
      {:ok, project} = Projects.create_project(%{name: "Find Me"})
      assert {:ok, found} = Projects.get_project(project.id)
      assert found.id == project.id
    end

    test "get_project/1 returns {:error, :not_found}" do
      assert {:error, :not_found} = Projects.get_project(999_999)
    end

    test "update_project/2 changes fields" do
      {:ok, project} = Projects.create_project(%{name: "Old"})
      assert {:ok, updated} = Projects.update_project(project, %{name: "New"})
      assert updated.name == "New"
      assert updated.slug == "new"
    end

    test "archive_project/1 sets status to archived" do
      {:ok, project} = Projects.create_project(%{name: "Soon Gone"})
      assert {:ok, archived} = Projects.archive_project(project)
      assert archived.status == "archived"
    end

    test "get_project_with_stats/1 includes task_count" do
      {:ok, project} = Projects.create_project(%{name: "Stats"})
      Projects.link_task(project.id, "t1")
      Projects.link_task(project.id, "t2")
      assert {:ok, result} = Projects.get_project_with_stats(project.id)
      assert Map.get(result, :task_count) == 2
    end
  end

  describe "goals" do
    setup do
      {:ok, project} = Projects.create_project(%{name: "Goal Project"})
      %{project: project}
    end

    test "create_goal/1 with valid attrs", %{project: project} do
      assert {:ok, %Goal{} = goal} = Projects.create_goal(%{title: "Ship v1", project_id: project.id})
      assert goal.title == "Ship v1"
      assert goal.status == "active"
      assert goal.priority == "medium"
    end

    test "create_goal/1 fails without title", %{project: project} do
      assert {:error, %Ecto.Changeset{}} = Projects.create_goal(%{project_id: project.id})
    end

    test "create_goal/1 fails without project_id" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_goal(%{title: "Orphan"})
    end

    test "list_goals/1 returns goals for project", %{project: project} do
      {:ok, _} = Projects.create_goal(%{title: "G1", project_id: project.id})
      {:ok, _} = Projects.create_goal(%{title: "G2", project_id: project.id})
      assert length(Projects.list_goals(project.id)) == 2
    end

    test "update_goal/2 changes fields", %{project: project} do
      {:ok, goal} = Projects.create_goal(%{title: "Old", project_id: project.id})
      assert {:ok, updated} = Projects.update_goal(goal, %{title: "New", priority: "high"})
      assert updated.title == "New"
      assert updated.priority == "high"
    end

    test "delete_goal/1 removes goal", %{project: project} do
      {:ok, goal} = Projects.create_goal(%{title: "Delete Me", project_id: project.id})
      assert {:ok, _} = Projects.delete_goal(goal)
      assert {:error, :not_found} = Projects.get_goal(goal.id)
    end

    test "goal_tree/1 builds nested structure", %{project: project} do
      {:ok, parent} = Projects.create_goal(%{title: "Parent", project_id: project.id})
      {:ok, _child} = Projects.create_goal(%{title: "Child", project_id: project.id, parent_id: parent.id})
      tree = Projects.goal_tree(project.id)
      assert length(tree) == 1
      node = hd(tree)
      assert node.goal.title == "Parent"
      assert length(node.children) == 1
      assert hd(node.children).goal.title == "Child"
    end

    test "goal_tree/1 handles deep nesting", %{project: project} do
      {:ok, root} = Projects.create_goal(%{title: "Root", project_id: project.id})
      {:ok, mid} = Projects.create_goal(%{title: "Mid", project_id: project.id, parent_id: root.id})
      {:ok, _leaf} = Projects.create_goal(%{title: "Leaf", project_id: project.id, parent_id: mid.id})
      tree = Projects.goal_tree(project.id)
      assert length(tree) == 1
      assert hd(hd(hd(tree).children).children).goal.title == "Leaf"
    end

    test "goal_ancestry/1 returns chain from root to leaf", %{project: project} do
      {:ok, root} = Projects.create_goal(%{title: "Root", project_id: project.id})
      {:ok, mid} = Projects.create_goal(%{title: "Mid", project_id: project.id, parent_id: root.id})
      {:ok, leaf} = Projects.create_goal(%{title: "Leaf", project_id: project.id, parent_id: mid.id})
      ancestry = Projects.goal_ancestry(leaf.id)
      assert length(ancestry) == 3
      assert hd(ancestry).title == "Root"
      assert List.last(ancestry).title == "Leaf"
    end

    test "goal_ancestry/1 returns single element for root", %{project: project} do
      {:ok, root} = Projects.create_goal(%{title: "Root", project_id: project.id})
      ancestry = Projects.goal_ancestry(root.id)
      assert length(ancestry) == 1
      assert hd(ancestry).id == root.id
    end

    test "goal_ancestry/1 returns empty for nonexistent id" do
      assert Projects.goal_ancestry(999_999) == []
    end
  end

  describe "task linking" do
    setup do
      {:ok, project} = Projects.create_project(%{name: "Task Project"})
      {:ok, goal} = Projects.create_goal(%{title: "Goal", project_id: project.id})
      %{project: project, goal: goal}
    end

    test "link_task/3 creates association", %{project: project, goal: goal} do
      assert {:ok, _} = Projects.link_task(project.id, "task_abc", goal_id: goal.id)
      tasks = Projects.list_project_tasks(project.id)
      assert length(tasks) == 1
      assert hd(tasks).task_id == "task_abc"
      assert hd(tasks).goal_id == goal.id
    end

    test "link_task/2 works without goal", %{project: project} do
      assert {:ok, _} = Projects.link_task(project.id, "task_no_goal")
      tasks = Projects.list_project_tasks(project.id)
      assert hd(tasks).goal_id == nil
    end

    test "link_task/3 is idempotent", %{project: project} do
      assert {:ok, _} = Projects.link_task(project.id, "task_dup")
      assert {:ok, _} = Projects.link_task(project.id, "task_dup")
      assert length(Projects.list_project_tasks(project.id)) == 1
    end

    test "unlink_task/2 removes association", %{project: project} do
      {:ok, _} = Projects.link_task(project.id, "task_rm")
      assert {1, _} = Projects.unlink_task(project.id, "task_rm")
      assert Projects.list_project_tasks(project.id) == []
    end

    test "list_project_tasks/1 preloads goal", %{project: project, goal: goal} do
      Projects.link_task(project.id, "task_preload", goal_id: goal.id)
      tasks = Projects.list_project_tasks(project.id)
      assert hd(tasks).goal.title == "Goal"
    end
  end
end
