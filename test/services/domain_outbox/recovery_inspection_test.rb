require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxRecoveryInspectionTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-recovery-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-recovery-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-recovery-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @no_workspace = make_test_owner("outbox-recovery-empty-#{SecureRandom.hex(6)}@example.test")
    @now = Time.zone.parse("2026-11-22 15:30:00")
  end

  def inspect_for(owner: @owner, now: @now)
    DomainOutbox::RecoveryInspection.snapshot(owner: owner, now: now)
  end

  def running_record(started_at:)
    OwnerOutboxReplayRun.create!(
      workspace: @workspace, owner_user: @owner,
      request_digest: "a" * 64, requested_limit: 5,
      state: "running", started_at: started_at
    )
  end

  test "C2.3b6c2.3 no run is not a claim that replay is authorized" do
    assert_equal({ status: "no_running_command", manual_review_required: false },
      inspect_for)
  end

  test "C2.3b6c2.3 marks old or clock-anomalous running rows for human review only" do
    record = running_record(started_at: @now - 14.minutes)
    baseline = [
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]

    assert_no_difference(baseline) do
      assert_equal({ status: "in_progress", manual_review_required: false },
        inspect_for)
      assert_equal({ status: "manual_review_required", manual_review_required: true },
        inspect_for(now: @now + 1.minute))
      assert_equal({ status: "manual_review_required", manual_review_required: true },
        inspect_for(now: @now + 30.days))
      assert_equal({ status: "manual_review_required", manual_review_required: true },
        inspect_for(now: @now - 1.hour))
    end
    assert_equal "running", record.reload.state
    assert_nil record.finished_at
  end

  test "C2.3b6c2.3 denies guest, client, and owner lacking a workspace" do
    [nil, @client, @no_workspace, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { inspect_for(owner: actor) }
    end
    assert_raises(ArgumentError) { inspect_for(now: "2026-11-22") }
  end

  test "C2.3b6c2.3 other workspace receives no run metadata or actor IDs" do
    running_record(started_at: @now - 2.hours)
    assert_equal({ status: "no_running_command", manual_review_required: false },
      inspect_for(owner: @other))
    snapshot = inspect_for
    assert_equal "manual_review_required", snapshot[:status]
    assert_equal %i[manual_review_required status], snapshot.keys.sort
    assert_not snapshot.key?(:owner_user_id)
    assert_not snapshot.key?(:request_digest)
    assert_not snapshot.key?(:workspace_id)
  end
end
