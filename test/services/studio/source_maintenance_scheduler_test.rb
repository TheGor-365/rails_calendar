require "test_helper"

class StudioSourceMaintenanceSchedulerTest < ActiveSupport::TestCase
  setup do
    pass = "synthetic-maintenance-runner-password"
    @owner = User.create!(email: "maintenance-owner@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @foreign = User.create!(email: "maintenance-foreign@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic maintenance",
      slug: "maintenance-synthetic")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
  end

  test "same slot is idempotent and result remains immutable" do
    calls = 0
    work = ->(_kind) { calls += 1; 3 }
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: work)
    first = scheduler.tick!(kind: "scan")
    second = scheduler.tick!(kind: "scan")
    assert_equal first.id, second.id
    assert_equal 1, calls
    assert_equal "succeeded", first.reload.state
    assert_equal({ "processed" => 3 }, first.result_summary)
    assert_equal 1, Studio::MaintenanceRun.count
    assert_not first.update(kind: "inventory")
    assert_not first.destroy
  end

  test "failed operation logs only generic error, and never retries within same slot" do
    calls = 0
    s = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_kind) { calls += 1; raise "Sensitive key q/#{ 'f' * 64 }" })
    run = s.tick!(kind: "scan")
    assert_equal "failed", run.reload.state
    assert_equal "operation_failed", run.error_code
    assert_equal({}, run.result_summary)
    assert_equal 1, calls
    s.tick!(kind: "scan")
    assert_equal 1, calls
    assert_not_includes run.reload.attributes.to_json, "q/#{"f" * 64}"
  end

  test "crashed earlier running slot blocks later slot instead of unsafe replay" do
    calls = 0
    s = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_) { calls += 1; 0 })
    slot = Time.current.to_i / 300
    @ws.studio_maintenance_runs.create!(kind: "scan", slot: slot, started_at: 20.minutes.ago)
    assert_nil s.tick!(kind: "scan", now: 10.minutes.from_now)
    assert_equal 0, calls
    assert_equal 1, Studio::MaintenanceRun.count
  end

  test "health run persists aggregate booleans and counts, never raw secrets" do
    health = {
      queue: { due: 2 }, storage_metadata: { overdue_expiry_1h: 1 },
      clamav: { connectivity_and_db_timestamp: "unavailable" }
    }
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_) { health })
    run = scheduler.tick!(kind: "health")
    assert_equal "succeeded", run.state
    assert_equal({"queue_due" => 2, "retention_overdue" => 1, "clamav_ready" => false}, run.reload.result_summary)
  end

  test "retention requires distinct local opt-in and inventory requires S3" do
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_) { 2 })
    assert_raises(Studio::SourceMaintenanceScheduler::Disabled) do
      scheduler.tick!(kind: "retention", allow_retention: true)
    end
    assert_raises(Studio::SourceMaintenanceScheduler::Disabled) do
      scheduler.tick!(kind: "inventory")
    end
    assert_equal 0, Studio::MaintenanceRun.count
    assert_raises(ArgumentError) { scheduler.tick!(kind: "unknown") }
  end

  test "revoked membership or foreign owner cannot execute scheduled operations" do
    assert_raises(SecurityError) do
      Studio::SourceMaintenanceScheduler.new(actor: @foreign, workspace: @ws)
    end
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_) { 1 })
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { scheduler.tick!(kind: "scan") }
    assert_equal 0, Studio::MaintenanceRun.count
  end

  test "database uniqueness forbids duplicate maintenance slot" do
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @ws,
      executor: ->(_) { 1 })
    run = scheduler.tick!(kind: "scan")
    assert_raises(ActiveRecord::RecordNotUnique) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::MaintenanceRun.insert_all!([{
          workspace_id: @ws.id, kind: "scan", slot: run.slot,
          state: "running", started_at: Time.current,
          result_summary: {}, created_at: Time.current, updated_at: Time.current
        }])
      end
    end
  end
end
