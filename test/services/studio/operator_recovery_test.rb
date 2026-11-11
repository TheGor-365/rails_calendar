require "test_helper"

class StudioOperatorRecoveryTest < ActiveSupport::TestCase
  setup do
    password = "synthetic-operator-review-password"
    @owner = User.create!(email: "recovery-owner@example.test", role: "owner",
                          password: password, password_confirmation: password)
    @other = User.create!(email: "recovery-other@example.test", role: "owner",
                          password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner,
                                   name: "Synthetic operator recovery", slug: "operator-recovery")
    @foreign = Workspace.create!(owner_user: @other,
                                 name: "Foreign recovery", slug: "foreign-recovery")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other, role: "owner", status: "active")
    @run = @workspace.studio_maintenance_runs.create!(
      kind: "scan", slot: Time.current.to_i / 300,
      state: "running", started_at: 45.minutes.ago
    )
  end

  test "explicit owner review atomically closes abandoned run without replay" do
    scheduler_calls = 0
    scheduler = Studio::SourceMaintenanceScheduler.new(actor: @owner, workspace: @workspace,
      executor: ->(_) { scheduler_calls += 1; 2 })
    assert_nil scheduler.tick!(kind: "scan", now: 10.minutes.from_now)
    assert_equal 0, scheduler_calls

    receipt = nil
    assert_difference "Studio::OperatorReview.count", 1 do
      receipt = Studio::OperatorRecovery.new(actor: @owner, workspace: @workspace)
        .close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                          confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    assert_equal @owner.id, receipt.reviewed_by_id
    assert_equal "scan_tasks_inspected", receipt.reason_code
    assert_equal "failed", @run.reload.state
    assert_equal "operation_failed", @run.error_code
    assert_equal({}, @run.result_summary)
    assert_not receipt.update(reason_code: "health_inspected")
    assert_not receipt.destroy

    next_run = scheduler.tick!(kind: "scan", now: 10.minutes.from_now)
    assert_equal "succeeded", next_run.state
    assert_equal 1, scheduler_calls
    assert_not_equal @run.id, next_run.id
  end

  test "wrong confirmation, wrong review reason, young run and duplicate receipt are refused" do
    recovery = Studio::OperatorRecovery.new(actor: @owner, workspace: @workspace)
    assert_raises(Studio::OperatorRecovery::Denied) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                                confirmation: "NO")
    end
    assert_raises(Studio::OperatorRecovery::Denied) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "retention_objects_inspected",
                                confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    @run.update_columns(started_at: 5.minutes.ago)
    assert_raises(Studio::OperatorRecovery::Denied) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                                confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    assert_equal "running", @run.reload.state
    assert_equal 0, Studio::OperatorReview.count

    @run.update_columns(started_at: 2.hours.ago)
    recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                              confirmation: "REVIEWED-RUN-#{@run.id}")
    assert_raises(Studio::OperatorRecovery::Denied) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                                confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    assert_equal 1, Studio::OperatorReview.count
  end

  test "review of physical retention requires distinct evidence code, but never deletes files" do
    @run.update_columns(kind: "retention", slot: Time.current.to_i / 3600)
    recovery = Studio::OperatorRecovery.new(actor: @owner, workspace: @workspace)
    assert_raises(Studio::OperatorRecovery::Denied) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                                confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    receipt = recovery.close_abandoned!(run_id: @run.id,
      reason_code: "retention_objects_inspected",
      confirmation: "REVIEWED-RUN-#{@run.id}")
    assert_equal "retention_objects_inspected", receipt.reason_code
    assert_equal "failed", @run.reload.state
    assert_equal 1, Studio::OperatorReview.count
  end

  test "foreign tenant, revoked membership and disabled environment fail closed" do
    assert_raises(SecurityError) do
      Studio::OperatorRecovery.new(actor: @other, workspace: @workspace)
    end
    recovery = Studio::OperatorRecovery.new(actor: @owner, workspace: @workspace)
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      recovery.close_abandoned!(run_id: @run.id, reason_code: "scan_tasks_inspected",
                                confirmation: "REVIEWED-RUN-#{@run.id}")
    end
    Studio::OperatorRecovery.stub(:enabled?, false) do
      assert_raises(Studio::OperatorRecovery::Denied) do
        Studio::OperatorRecovery.new(actor: @other, workspace: @foreign)
      end
    end
    assert_equal 0, Studio::OperatorReview.count
  end

  test "composite foreign key denies forged run tenant despite raw SQL insert" do
    now = Time.current
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::OperatorReview.insert_all!([{
          workspace_id: @foreign.id, studio_maintenance_run_id: @run.id,
          reviewed_by_id: @other.id, reason_code: "scan_tasks_inspected",
          reviewed_at: now, created_at: now, updated_at: now
        }])
      end
    end
  end
end
