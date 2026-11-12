require "test_helper"

class StudioSyntheticProjectTaskGraphTest < ActiveSupport::TestCase
  setup do
    tag = SecureRandom.hex(5)
    pass = "rc039-fictional-task-graph-password"
    @owner = User.create!(email: "task-owner-#{tag}@example.test",
      password: pass, password_confirmation: pass, role: "owner")
    @other_owner = User.create!(email: "task-outsider-#{tag}@example.test",
      password: pass, password_confirmation: pass, role: "owner")
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Fictional engineering roadmap", slug: "task-graph-#{tag}")
    @other_workspace = Workspace.create!(owner_user: @other_owner,
      name: "Foreign fictional roadmap", slug: "foreign-graph-#{tag}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @other_workspace, user: @other_owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Hidden fictional client")
    @other_client = @workspace.clients.create!(display_name: "Second hidden client")
    @foreign_client = @other_workspace.clients.create!(display_name: "Foreign hidden client")
    @intake = make_intake(@workspace, @client)
    @other_intake = make_intake(@workspace, @client)
    @wrong_client_intake = make_intake(@workspace, @other_client)
    @foreign_intake = make_intake(@other_workspace, @foreign_client)
    @graph = Studio::SyntheticProjectTaskGraph.new(
      actor: @owner, workspace: @workspace)
  end

  test "fictional task metadata is idempotent and separate from document cards" do
    existing = [Studio::SyntheticProjectCard.count, ClientFact.count,
                ProjectMilestone.count, Consultation.count, ProjectSource.count]
    first = task("scope_review")
    assert_equal first, task("scope_review")
    assert_equal 1, Studio::SyntheticProjectTask.count
    assert_equal 0, Studio::SyntheticProjectTaskDependency.count
    assert_equal existing, [Studio::SyntheticProjectCard.count, ClientFact.count,
                            ProjectMilestone.count, Consultation.count, ProjectSource.count]
    assert_equal "discovery", first.fetch("phase")
    assert_equal "proposed_unverified", first.fetch("state")
    assert_nil first.fetch("due_on")
    assert_nil first.fetch("assigned_user_id")
    assert_equal false, first.fetch("approved")
    assert_equal false, first.fetch("client_confirmed")
    snapshot = graph_snapshot
    assert_equal [first], snapshot.fetch("tasks")
    assert_equal ["scope_review"], snapshot.fetch("topological_task_keys")
    assert_equal 0, snapshot.fetch("dependency_count")
    assert_equal [], snapshot.fetch("scheduled_items")
    assert_equal false, snapshot.fetch("critical_path_verified")
    assert_equal false, snapshot.fetch("task_execution_authorized")
    assert_equal false, snapshot.fetch("document_generation_allowed")
    assert_equal 0, snapshot.fetch("external_calls")
    assert_equal 0, snapshot.fetch("billable_usd")
    refute_includes snapshot.to_json, @intake.title
    refute_includes snapshot.to_json, @intake.goal
    refute_includes snapshot.to_json, @client.display_name
  end

  test "deterministic six-step DAG generates stable prerequisite-first roadmap" do
    baseline = [ProjectMilestone.count, Consultation.count]
    scope = task("scope_review")
    design = task("solution_design")
    backend = task("rails_implementation")
    frontend = task("interface_implementation")
    quality = task("quality_verification")
    handoff = task("handoff_preparation")

    edge(design, scope)
    edge(backend, design)
    edge(frontend, design)
    edge(quality, backend)
    edge(quality, frontend)
    edge(handoff, quality)

    first = graph_snapshot
    assert_equal first, graph_snapshot
    assert_equal 6, first.fetch("task_count")
    assert_equal 6, first.fetch("dependency_count")
    assert_equal %w[scope_review solution_design interface_implementation rails_implementation quality_verification handoff_preparation],
      first.fetch("topological_task_keys")
    assert_equal false, first.fetch("cyclic_dependencies_allowed")
    assert_equal false, first.fetch("critical_path_verified")
    assert first.fetch("dependencies").all? { |link|
      link.fetch("state") == "proposed_unverified" &&
        first.fetch("tasks").any? { |t| t.fetch("task_key") == link.fetch("dependent_task_key") } &&
        first.fetch("tasks").any? { |t| t.fetch("task_key") == link.fetch("prerequisite_task_key") }
    }
    assert_equal baseline, [ProjectMilestone.count, Consultation.count]
  end

  test "self reference, cycle, missing task and duplicates cannot corrupt the graph" do
    a = task("scope_review")
    b = task("solution_design")
    c = task("rails_implementation")
    first = edge(b, a)
    edge(c, b)
    assert_equal first, edge(b, a)
    assert_equal 2, Studio::SyntheticProjectTaskDependency.count

    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) { edge(a, c) }
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) { edge(a, a) }
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      @graph.add_dependency!(client: @client, intake: @intake,
        dependent_task_id: 999999999, prerequisite_task_id: a.fetch("task_id"),
        explicit_synthetic: true)
    end
    assert_equal 2, Studio::SyntheticProjectTaskDependency.count
    assert_equal %w[scope_review solution_design rails_implementation],
      graph_snapshot.fetch("topological_task_keys")
  end

  test "swapped clients cross-intake and foreign owners cannot inspect or link tasks" do
    task_a = task("scope_review")
    same_key_other_intake = @graph.create_task!(
      client: @client, intake: @other_intake, task_key: "scope_review",
      explicit_synthetic: true)
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      @graph.add_dependency!(client: @client, intake: @intake,
        dependent_task_id: task_a.fetch("task_id"),
        prerequisite_task_id: same_key_other_intake.fetch("task_id"),
        explicit_synthetic: true)
    end
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      @graph.snapshot(client: @other_client, intake: @intake, explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      @graph.snapshot(client: @foreign_client, intake: @foreign_intake,
        explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticProjectTaskGraph.new(actor: @other_owner,
        workspace: @workspace)
    end
    assert_equal 0, Studio::SyntheticProjectTaskDependency.count
  end

  test "revoked membership and non-test or production cannot create or read" do
    task("scope_review")
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      @graph.create_task!(client: @client, intake: @intake, task_key: "solution_design")
    end
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      @graph.create_task!(client: @client, intake: @intake,
        task_key: "unknown_user_task", explicit_synthetic: true)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticProjectTaskGraph::Denied) { graph_snapshot }
    end
    Rails.env.stub(:test?, false) do
      assert_raises(Studio::SyntheticProjectTaskGraph::Denied) { graph_snapshot }
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { graph_snapshot }
    assert_equal 1, Studio::SyntheticProjectTask.count
    assert_equal 0, Studio::SyntheticProjectTaskDependency.count
  end

  test "model blocks task edits, deletion and direct unsupervised dependencies" do
    a = task("scope_review")
    b = task("solution_design")
    row = Studio::SyntheticProjectTask.find(a.fetch("task_id"))
    assert_not row.update(task_key: "quality_verification")
    assert_equal "scope_review", row.reload.task_key
    assert_not row.destroy
    assert Studio::SyntheticProjectTask.exists?(row.id)

    assert_raises(ActiveRecord::RecordInvalid) do
      Studio::SyntheticProjectTaskDependency.create!(
        dependent_task_id: b.fetch("task_id"),
        prerequisite_task_id: a.fetch("task_id"),
        workspace_id: @workspace.id, client_id: @client.id,
        project_intake_id: @intake.id, created_by: @owner)
    end
    assert_equal 0, Studio::SyntheticProjectTaskDependency.count
    edge(b, a)
    receipt = Studio::SyntheticProjectTaskDependency.first
    assert_not receipt.update(prerequisite_task_id: b.fetch("task_id"))
    assert_not receipt.destroy
    assert_equal 1, Studio::SyntheticProjectTaskDependency.count
  end

  test "database composite constraints deny mismatched tenants and tasks" do
    a = task("scope_review")
    b = task("solution_design")
    foreign = @graph.create_task!(client: @client, intake: @other_intake,
      task_key: "interface_implementation", explicit_synthetic: true)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::SyntheticProjectTask.transaction(requires_new: true) do
        Studio::SyntheticProjectTask.insert_all!([{
          workspace_id: @other_workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, created_by_id: @owner.id,
          task_key: "handoff_preparation", created_at: Time.current,
          updated_at: Time.current
        }])
      end
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::SyntheticProjectTaskDependency.transaction(requires_new: true) do
        Studio::SyntheticProjectTaskDependency.insert_all!([{
          workspace_id: @workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, created_by_id: @owner.id,
          dependent_task_id: a.fetch("task_id"),
          prerequisite_task_id: foreign.fetch("task_id"),
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectTaskDependency.transaction(requires_new: true) do
        Studio::SyntheticProjectTaskDependency.insert_all!([{
          workspace_id: @workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, created_by_id: @owner.id,
          dependent_task_id: b.fetch("task_id"),
          prerequisite_task_id: b.fetch("task_id"),
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_equal 0, Studio::SyntheticProjectTaskDependency.count
  end

  private

  def make_intake(workspace, client)
    workspace.project_intakes.create!(client: client,
      title: "Hidden fictional plan", project_type: "website",
      goal: "Only invented process steps without any real project content.",
      demo_consent_at: Time.current)
  end

  def task(task_key)
    @graph.create_task!(client: @client, intake: @intake,
      task_key: task_key, explicit_synthetic: true)
  end

  def edge(dependent, prerequisite)
    @graph.add_dependency!(client: @client, intake: @intake,
      dependent_task_id: dependent.fetch("task_id"),
      prerequisite_task_id: prerequisite.fetch("task_id"),
      explicit_synthetic: true)
  end

  def graph_snapshot
    @graph.snapshot(client: @client, intake: @intake, explicit_synthetic: true)
  end
end
