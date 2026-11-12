require "test_helper"

class StudioSyntheticProjectTaskLifecycleTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(5)
    password = "rc039-lifecycle-fictional-only-password"
    @owner = User.create!(email: "rc039-lifecycle-owner-#{suffix}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @other_owner = User.create!(email: "rc039-lifecycle-other-#{suffix}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Fictional workflow", slug: "rc039-lifecycle-#{suffix}")
    @other_workspace = Workspace.create!(owner_user: @other_owner,
      name: "Different fictional workflow", slug: "rc039-lifecycle-other-#{suffix}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @other_workspace, user: @other_owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Synthetic private client")
    @wrong_client = @workspace.clients.create!(display_name: "Unrelated synthetic client")
    @other_client = @other_workspace.clients.create!(display_name: "Foreign synthetic client")
    @intake = intake(@workspace, @client)
    @wrong_intake = intake(@workspace, @wrong_client)
    @foreign_intake = intake(@other_workspace, @other_client)
    @graph = Studio::SyntheticProjectTaskGraph.new(
      actor: @owner, workspace: @workspace)
    @workflow = Studio::SyntheticProjectTaskLifecycle.new(
      actor: @owner, workspace: @workspace)
  end

  test "fixed fictional lifecycle has terminal completion and monotonic immutable audit" do
    baseline = [ProjectMilestone.count, Consultation.count, Studio::SyntheticProjectCard.count]
    t = task("scope_review")
    assert_equal "proposed", t.fetch("workflow_state")
    assert_equal "proposed_unverified", t.fetch("state")
    assert_equal 3, t.fetch("priority")
    assert_equal 0, t.fetch("version")

    a = move(t, to: "ready")
    b = move(a, to: "in_progress")
    c = move(b, to: "completed")
    assert_equal ["ready", "in_progress", "completed"],
      [a, b, c].map { |item| item.fetch("workflow_state") }
    assert_equal [1, 2, 3], [a, b, c].map { |item| item.fetch("version") }
    assert_equal 3, Studio::SyntheticProjectTaskEvent.count
    assert_equal [1, 2, 3], history(t).map { |item| item.fetch("sequence") }
    assert_equal %w[proposed ready in_progress], history(t).map { |item| item.fetch("from_state") }
    assert_equal %w[ready in_progress completed], history(t).map { |item| item.fetch("to_state") }
    assert history(t).all? { |entry| entry.fetch("task_execution_authorized") == false }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(c, to: "ready") }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { priority(c, 1) }
    assert_equal baseline, [ProjectMilestone.count, Consultation.count, Studio::SyntheticProjectCard.count]
    assert_equal false, snapshot.fetch("task_execution_authorized")
    assert_equal false, snapshot.fetch("critical_path_verified")
    assert_equal [], snapshot.fetch("scheduled_items")
    assert_equal "completed", snapshot.fetch("tasks").sole.fetch("workflow_state")
    refute_includes snapshot.to_json, @intake.title
    refute_includes snapshot.to_json, @client.display_name
  end

  test "blocked task can resume but cannot skip lifecycle edges" do
    t = task("rails_implementation")
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(t, to: "completed") }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(t, to: "in_progress") }
    ready = move(t, to: "ready")
    progress = move(ready, to: "in_progress")
    blocked = move(progress, to: "blocked")
    assert_equal "blocked", blocked.fetch("workflow_state")
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(blocked, to: "completed") }
    resumed = move(blocked, to: "in_progress")
    assert_equal "completed", move(resumed, to: "completed").fetch("workflow_state")
    assert_equal %w[ready in_progress blocked in_progress completed],
      history(t).map { |event| event.fetch("to_state") }
  end

  test "uncompleted prerequisites block readiness and completion even after SQL edge insertion" do
    prerequisite = task("scope_review")
    dependent = task("solution_design")
    link(dependent, prerequisite)
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(dependent, to: "ready") }
    assert_equal 0, Studio::SyntheticProjectTaskEvent.count
    assert_equal "proposed", Studio::SyntheticProjectTask.find(dependent.fetch("task_id")).state

    finished = move(move(move(prerequisite, to: "ready"), to: "in_progress"), to: "completed")
    assert_equal "completed", finished.fetch("workflow_state")
    ready = move(dependent, to: "ready")
    progress = move(ready, to: "in_progress")
    assert_raises(Studio::SyntheticProjectTaskGraph::Denied) do
      link(dependent, task("quality_verification"))
    end

    # A direct SQL write can bypass application-level rules, but the workflow
    # must still refuse completion when any referenced prerequisite is open.
    other = task("interface_implementation")
    Studio::SyntheticProjectTaskDependency.insert_all!([{
      workspace_id: @workspace.id, client_id: @client.id,
      project_intake_id: @intake.id, created_by_id: @owner.id,
      dependent_task_id: dependent.fetch("task_id"),
      prerequisite_task_id: other.fetch("task_id"),
      created_at: Time.current, updated_at: Time.current
    }])
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(progress, to: "completed") }
    assert_equal "in_progress", Studio::SyntheticProjectTask.find(dependent.fetch("task_id")).state
    assert_equal 0, history(other).size
    other_done = move(move(move(other, to: "ready"), to: "in_progress"), to: "completed")
    assert_equal "completed", other_done.fetch("workflow_state")
    assert_equal "completed", move(progress, to: "completed").fetch("workflow_state")
  end

  test "owner priorities reorder independent tasks but never ignore dependency order" do
    a = task("scope_review")
    b = task("solution_design")
    c = task("rails_implementation")
    pa = priority(a, 5)
    pb = priority(b, 1)
    assert_equal 1, pa.fetch("version")
    assert_equal 1, pb.fetch("version")
    assert_equal %w[solution_design rails_implementation scope_review],
      snapshot.fetch("topological_task_keys")
    link(b, a)
    assert_equal %w[rails_implementation scope_review solution_design],
      snapshot.fetch("topological_task_keys")
    assert_equal 2, Studio::SyntheticProjectTaskEvent.count
    assert history(a).all? { |event|
      event.fetch("event_type") == "priority_change" &&
        event.fetch("from_state") == event.fetch("to_state")
    }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { priority(pa, 5) }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { priority(pa, 0) }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { priority(pa, "1") }
    assert_equal false, snapshot.fetch("client_confirmed")
    assert_equal 0, snapshot.fetch("external_calls")
  end

  test "stale expected state and version never mutate or append audit" do
    t = task("scope_review")
    changed = priority(t, 1)
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Conflict) { priority(t, 2) }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Conflict) { move(t, to: "ready") }
    ready = move(changed, to: "ready")
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Conflict) { move(changed, to: "ready") }
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) do
      @workflow.transition!(client: @client, intake: @intake,
        task_id: t.fetch("task_id"), expected_state: "ready",
        expected_version: "-1", to_state: "in_progress",
        explicit_synthetic: true)
    end
    assert_equal "ready", Studio::SyntheticProjectTask.find(t.fetch("task_id")).state
    assert_equal 2, Studio::SyntheticProjectTaskEvent.count
    assert_equal 2, ready.fetch("version")
  end

  test "revoked, foreign and swapped client cannot view or mutate lifecycle" do
    t = task("scope_review")
    foreign_task = @graph.create_task!(client: @client, intake: @intake,
      task_key: "solution_design", explicit_synthetic: true)
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) do
      @workflow.history(client: @wrong_client, intake: @intake,
        task_id: t.fetch("task_id"), explicit_synthetic: true)
    end
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) do
      @workflow.history(client: @client, intake: @wrong_intake,
        task_id: t.fetch("task_id"), explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticProjectTaskLifecycle.new(actor: @other_owner, workspace: @workspace)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { move(t, to: "ready") }
    assert_raises(SecurityError) { history(foreign_task) }
    assert_equal 0, Studio::SyntheticProjectTaskEvent.count
  end

  test "model rejects direct edits; lifecycle history is append only" do
    t = task("scope_review")
    row = Studio::SyntheticProjectTask.find(t.fetch("task_id"))
    assert_not row.update(state: "ready")
    assert_not row.update(priority: 1)
    assert_not row.destroy
    assert_equal "proposed", row.reload.state
    assert_equal 3, row.priority

    ready = move(t, to: "ready")
    receipt = Studio::SyntheticProjectTaskEvent.first
    assert_not receipt.update(to_state: "completed")
    assert_not receipt.destroy
    assert_equal "ready", row.reload.state
    assert_equal 1, ready.fetch("version")
    assert_equal 1, Studio::SyntheticProjectTaskEvent.count
    assert_raises(ActiveRecord::RecordInvalid) do
      Studio::SyntheticProjectTaskEvent.create!(
        synthetic_project_task: row, actor_user: @owner,
        workspace_id: @workspace.id, client_id: @client.id,
        project_intake_id: @intake.id, sequence: 2,
        event_type: "transition", from_state: "ready", to_state: "completed",
        from_priority: 3, to_priority: 3, recorded_at: Time.current
      )
    end
  end

  test "database enforces state priority audit edge graph and tenant identity" do
    t = task("scope_review")
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectTask.transaction(requires_new: true) do
        Studio::SyntheticProjectTask.where(id: t.fetch("task_id")).update_all(state: "approved")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectTask.transaction(requires_new: true) do
        Studio::SyntheticProjectTask.where(id: t.fetch("task_id")).update_all(priority: 0)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectTaskEvent.transaction(requires_new: true) do
        Studio::SyntheticProjectTaskEvent.insert_all!([{
          studio_synthetic_project_task_id: t.fetch("task_id"),
          workspace_id: @workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, actor_user_id: @owner.id,
          sequence: 1, event_type: "transition",
          from_state: "proposed", to_state: "completed",
          from_priority: 3, to_priority: 3, recorded_at: Time.current,
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::SyntheticProjectTaskEvent.transaction(requires_new: true) do
        Studio::SyntheticProjectTaskEvent.insert_all!([{
          studio_synthetic_project_task_id: t.fetch("task_id"),
          workspace_id: @other_workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, actor_user_id: @owner.id,
          sequence: 1, event_type: "transition",
          from_state: "proposed", to_state: "ready",
          from_priority: 3, to_priority: 3, recorded_at: Time.current,
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_equal "proposed", Studio::SyntheticProjectTask.find(t.fetch("task_id")).state
    assert_equal 0, Studio::SyntheticProjectTaskEvent.count
  end

  test "non-test and production predicates reject all fictional lifecycle operations" do
    t = task("scope_review")
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(t, to: "ready") }
      assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { history(t) }
    end
    Rails.env.stub(:test?, false) do
      assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) { move(t, to: "ready") }
    end
    assert_raises(Studio::SyntheticProjectTaskLifecycle::Denied) do
      @workflow.transition!(client: @client, intake: @intake,
        task_id: t.fetch("task_id"), expected_state: "proposed",
        expected_version: 0, to_state: "ready", explicit_synthetic: false)
    end
    assert_equal 0, Studio::SyntheticProjectTaskEvent.count
    assert_equal "proposed", Studio::SyntheticProjectTask.find(t.fetch("task_id")).state
  end

  private

  def intake(workspace, client)
    workspace.project_intakes.create!(client: client,
      title: "Hidden fictional project title", project_type: "website",
      goal: "Fictional lifecycle does not process real customer information.",
      demo_consent_at: Time.current)
  end

  def task(key)
    @graph.create_task!(client: @client, intake: @intake,
      task_key: key, explicit_synthetic: true)
  end

  def link(dependent, prerequisite)
    @graph.add_dependency!(client: @client, intake: @intake,
      dependent_task_id: dependent.fetch("task_id"),
      prerequisite_task_id: prerequisite.fetch("task_id"),
      explicit_synthetic: true)
  end

  def move(item, to:)
    @workflow.transition!(client: @client, intake: @intake,
      task_id: item.fetch("task_id"), expected_state: item.fetch("workflow_state"),
      expected_version: item.fetch("version"), to_state: to,
      explicit_synthetic: true)
  end

  def priority(item, rank)
    @workflow.reprioritize!(client: @client, intake: @intake,
      task_id: item.fetch("task_id"), expected_state: item.fetch("workflow_state"),
      expected_version: item.fetch("version"), priority: rank,
      explicit_synthetic: true)
  end

  def history(item)
    @workflow.history(client: @client, intake: @intake,
      task_id: item.fetch("task_id"), explicit_synthetic: true)
  end

  def snapshot
    @graph.snapshot(client: @client, intake: @intake, explicit_synthetic: true)
  end
end
