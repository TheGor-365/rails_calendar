require "test_helper"

class StudioSourceOperatorDashboardTest < ActiveSupport::TestCase
  class FakeReadiness
    def readiness!
      true
    end
  end

  setup do
    suffix = SecureRandom.hex(5)
    pass = "synthetic-operator-only-test-password"
    @owner = User.create!(email: "operator-#{suffix}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @other = User.create!(email: "other-operator-#{suffix}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic operator A", slug: "operator-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
  end

  test "reports abandoned runs and incomplete checkpoints, without mutation or secrets" do
    @ws.studio_maintenance_runs.create!(kind: "scan", state: "running",
      started_at: 31.minutes.ago, slot: 1)
    @ws.studio_maintenance_runs.create!(kind: "health", state: "running",
      started_at: 2.minutes.ago, slot: 2)
    checkpoint = @ws.studio_inventory_checkpoints.create!(
      state: "listing", config_digest: "a" * 64, expires_at: 5.hours.from_now,
      pages_scanned: 0, last_db_blob_id: 0, db_target_max_id: 0,
      counts: {}, seen_cursor_digests: [])
    checkpoint.update_columns(encrypted_cursor: "secret-synthetic-cursor")
    report = dashboard.call
    assert_equal 1, report.dig(:maintenance, :abandoned_over_30m_by_kind, "scan")
    assert_equal 0, report.dig(:maintenance, :abandoned_over_30m_by_kind, "health")
    assert_equal true, report.dig(:maintenance, :manual_review_required)
    assert_equal false, report.dig(:maintenance, :replay_permitted)
    assert_equal 1, report.dig(:inventory_checkpoints, :incomplete)
    assert_equal false, report.dig(:inventory_checkpoints, :orphan_deletion_permitted)
    assert_equal false, report.dig(:inventory_checkpoints, :snapshot_consistent)
    assert_equal true, report[:read_only]
    assert_equal "running", @ws.studio_maintenance_runs.find_by!(kind: "scan").reload.state
    assert_equal "listing", checkpoint.reload.state
    refute_includes report.to_json, "secret-synthetic-cursor"
    refute_includes report.to_json, @owner.email
    refute_includes report.to_json, "q/#{"f" * 64}"
  end

  test "wrong owner, revoked membership and disabled synthetic gate fail closed" do
    assert_raises(SecurityError) do
      Studio::SourceOperatorDashboard.new(actor: @other, workspace: @ws)
    end
    active = dashboard
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { active.call }
    assert_raises(SecurityError) { dashboard }
  end

  private

  def dashboard
    Studio::SourceOperatorDashboard.new(actor: @owner, workspace: @ws, scanner: FakeReadiness.new)
  end
end
