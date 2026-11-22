require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxSupervisedReplayTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("supervised-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("supervised-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("supervised-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @empty_owner = make_test_owner("supervised-empty-#{SecureRandom.hex(6)}@example.test")
    @now = Time.zone.parse("2026-11-22 14:00:00")
    @token = "a" * 64
  end

  def invoke(owner: @owner, token: @token, limit: 5, confirmed: true, now: @now)
    DomainOutbox::SupervisedReplay.run!(
      owner: owner, request_token: token, limit: limit, confirmed: confirmed, now: now
    )
  end

  test "C2.3b6c2.2 rejects unverified owner, unsafe limits, tokens and missing consent before writes" do
    assert_no_difference([
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      [nil, @client, @empty_owner].each do |actor|
        assert_raises(ArgumentError) { invoke(owner: actor) }
      end
      [false, nil, "yes"].each do |flag|
        assert_raises(ArgumentError) { invoke(confirmed: flag) }
      end
      [0, 2, 50, "5", nil].each do |invalid|
        assert_raises(ArgumentError) { invoke(limit: invalid) }
      end
      ["short", "z" * 64, "A" * 64, nil, 123].each do |invalid|
        assert_raises(ArgumentError) { invoke(token: invalid) }
      end
    end
  end

  test "C2.3b6c2.2 single owner command is journaled, duplicate never invokes replayer twice" do
    calls = []
    runner = ->(workspace:, limit:, now:) do
      calls << [workspace.id, limit, now]
      { attempted: 2, delivered: 1, failed: 1 }
    end

    assert_no_difference([
      "DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      DomainOutbox::Replayer.stub(:run!, runner) do
        assert_equal({ status: "succeeded", attempted: 2, delivered: 1, failed: 1 },
          invoke)
        assert_equal({ status: "duplicate", attempted: 0, delivered: 0, failed: 0 },
          invoke)
        assert_equal({ status: "cooldown", attempted: 0, delivered: 0, failed: 0 },
          invoke(token: "b" * 64, now: @now + 30.seconds))
      end
    end
    assert_equal [[@workspace.id, 5, @now]], calls
    assert_equal 1, OwnerOutboxReplayRun.count
    run = OwnerOutboxReplayRun.first
    assert_equal @owner.id, run.owner_user_id
    assert_equal @workspace.id, run.workspace_id
    assert_equal "succeeded", run.state
    assert_equal [2, 1, 1],
      [run.attempted_count, run.delivered_count, run.failed_count]
    assert_equal 64, run.request_digest.length
    assert_not_equal @token, run.request_digest
    assert_not_includes run.attributes.values.map(&:to_s), @token
    assert_nil run.error_code
  end

  test "C2.3b6c2.2 running invocation blocks distinct request until human recovery" do
    record = OwnerOutboxReplayRun.create!(
      workspace: @workspace, owner_user: @owner, request_digest: "b" * 64,
      requested_limit: 5, state: "running", started_at: @now - 1.hour
    )
    assert_no_difference(["OwnerOutboxReplayRun.count", "AiSpendEntry.count"]) do
      assert_equal "busy", invoke[:status]
      assert_equal "busy", invoke(token: "c" * 64, now: @now + 1.year)[:status]
    end
    assert_equal "running", record.reload.state
    assert_nil record.finished_at
    assert_equal 0, record.attempted_count
  end

  test "C2.3b6c2.2 failed execution records class code without exposing payloads or retrying" do
    runner = ->(workspace:, limit:, now:) { raise DomainOutbox::Replayer::SourceUnavailable, "private client contents" }
    DomainOutbox::Replayer.stub(:run!, runner) do
      assert_equal "failed", invoke[:status]
      assert_equal "duplicate", invoke[:status]
    end

    run = OwnerOutboxReplayRun.sole
    assert_equal "failed", run.state
    assert_equal "DomainOutbox::Replayer::SourceUnavailable", run.error_code
    assert_nil run.request_digest.match(/private client/)
    assert_not_includes run.attributes.values.map(&:to_s), "private client contents"
    assert run.finished_at.present?
  end

  test "C2.3b6c2.2 separate workspaces do not share request keys or cooldown" do
    attempts = []
    runner = ->(workspace:, limit:, now:) do
      attempts << workspace.id
      { attempted: 0, delivered: 0, failed: 0 }
    end
    DomainOutbox::Replayer.stub(:run!, runner) do
      assert_equal "succeeded", invoke[:status]
      assert_equal "succeeded", invoke(owner: @other)[:status]
    end
    assert_equal [@workspace.id, @other_workspace.id], attempts
    assert_equal 2, OwnerOutboxReplayRun.count
    assert_equal 2, OwnerOutboxReplayRun.distinct.count(:workspace_id)
  end

  test "C2.3b6c2.2 rejects malformed replayer summary and preserves fail-closed ledger" do
    DomainOutbox::Replayer.stub(:run!, ->(workspace:, limit:, now:) {
      { attempted: limit + 1, delivered: 999, failed: 0 }
    }) do
      assert_equal "failed", invoke[:status]
    end
    record = OwnerOutboxReplayRun.sole
    assert_equal "DomainOutbox::SupervisedReplay::InvalidSummary", record.error_code
    assert_equal "failed", record.state
    assert_equal 0, record.attempted_count
    assert_equal 0, record.delivered_count
  end
end
