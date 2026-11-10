require "test_helper"

class StudioSourceOperationalAuditTest < ActiveSupport::TestCase
  FakeScanner = Struct.new(:healthy) do
    def readiness!
      raise Studio::ClamAvScanner::Unavailable unless healthy
      true
    end
  end

  setup do
    password = "synthetic-ops-owner-password-2026"
    @owner = User.create!(email: "ops-owner@example.test", role: "owner",
      password: password, password_confirmation: password)
    @intruder = User.create!(email: "ops-other@example.test", role: "owner",
      password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic ops",
      slug: "synthetic-ops")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
                                role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Synthetic ops client")
    @intake = @workspace.project_intakes.create!(client: @client,
      title: "Only a fictional project", project_type: "website",
      goal: "Synthetic diagnostics", demo_consent_at: Time.current)
    @storage = Studio::PrivateSourceStorage.new
    @blob = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @workspace,
      storage: @storage).stage!(client: @client, intake: @intake, filename: "ops.md",
      bytes: "# Synthetic operations\n").project_source_blob
  end

  teardown do
    @storage.delete!(key: @blob.object_key)
  end

  test "queue dashboard includes age, failed scans, cleanup lag and no user bytes" do
    queue = Studio::SourceScanQueue.new(actor: @owner, workspace: @workspace,
      storage: @storage)
    task = queue.enqueue!(client: @client, intake: @intake,
      source_id: @blob.project_source_id)
    task.update!(state: "retry_wait", attempts: 1,
                 last_error_code: "scan_denied",
                 next_attempt_at: 35.minutes.ago)
    @blob.update!(scan_state: "failed")

    audit = Studio::SourceOperationalAudit.new(actor: @owner, workspace: @workspace,
      scanner: FakeScanner.new(true))
    report = audit.call
    assert_equal "ready", report.dig(:clamav, :connectivity_and_db_timestamp)
    assert_equal false, report.dig(:clamav, :official_signature_provenance_verified)
    assert_equal 1, report.dig(:queue, :states, "retry_wait")
    assert_equal 1, report.dig(:queue, :due)
    assert_equal 1, report.dig(:queue, :overdue_15m)
    assert_operator report.dig(:queue, :oldest_due_age_seconds), :>=, 35.minutes.to_i
    assert_equal 1, report.dig(:storage_metadata, :failed_scans)
    assert_equal 0, report.dig(:storage_metadata, :expired_not_revoked)
    assert_equal false, report.fetch(:continuous_monitoring_enabled)
    assert_equal false, report.fetch(:production_ready)
    assert_not_includes report.to_json, @blob.object_key
    assert_not_includes report.to_json, @intake.title

    travel 8.days do
      expired = audit.call
      assert_equal 1, expired.dig(:storage_metadata, :expired_not_revoked)
      assert_equal 1, expired.dig(:storage_metadata, :overdue_expiry_1h)
    end
  end

  test "unavailable ClamAV and denied owner access fail closed" do
    audit = Studio::SourceOperationalAudit.new(actor: @owner, workspace: @workspace,
      scanner: FakeScanner.new(false))
    assert_equal "unavailable", audit.call.dig(:clamav, :connectivity_and_db_timestamp)
    assert_raises(SecurityError) do
      Studio::SourceOperationalAudit.new(actor: @intruder, workspace: @workspace)
    end

    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { audit.call }
  end

  test "production-disabled synthetic storage refuses inspection" do
    Studio::PrivateSourceStorage.stub(:enabled?, false) do
      assert_raises(SecurityError) do
        Studio::SourceOperationalAudit.new(actor: @owner, workspace: @workspace)
      end
    end
  end
end
