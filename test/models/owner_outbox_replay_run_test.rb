require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerOutboxReplayRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-run-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-run-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-run-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @foreign_workspace, = approved_profile_for(@other)
    @now = Time.zone.parse("2026-11-22 11:00:00")
  end

  def attrs(workspace: @workspace, owner_user: @owner, hex: "a", limit: 5)
    { workspace: workspace, owner_user: owner_user,
      request_digest: hex * 64, requested_limit: limit,
      state: "running", started_at: @now }
  end

  test "C2.3b6c2.1 records only bounded operator metadata, never executes replay" do
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_difference("OwnerOutboxReplayRun.count", 1) do
        @record = OwnerOutboxReplayRun.create!(attrs)
      end
    end
    assert_equal @owner.id, @record.owner_user_id
    assert_equal @workspace.id, @record.workspace_id
    assert_equal "running", @record.state
    assert_nil @record.finished_at
    assert_equal [0, 0, 0], [@record.attempted_count, @record.delivered_count, @record.failed_count]
    assert_not_includes @record.attributes.keys, "request_token"
    assert_not_includes @record.attributes.keys, "client_body"
  end

  test "C2.3b6c2.1 rejects client foreign owner invalid digest and unbounded limits" do
    assert_not OwnerOutboxReplayRun.new(attrs(owner_user: @client)).valid?
      "client may not be operator"
    assert_not OwnerOutboxReplayRun.new(attrs(owner_user: @other)).valid?
      "another workspace owner may not operate this workspace"
    assert_not OwnerOutboxReplayRun.new(attrs(hex: "x")).valid?
      "digest must be lowercase hexadecimal"
    [0, 2, 26, 100, "10", nil].each do |bad|
      assert_not OwnerOutboxReplayRun.new(attrs(limit: bad)).valid?
    end
    assert_equal 0, OwnerOutboxReplayRun.count
  end

  test "C2.3b6c2.1 one running command per workspace, separate workspaces independent" do
    first = OwnerOutboxReplayRun.create!(attrs)
    assert_raises(ActiveRecord::RecordNotUnique) do
      OwnerOutboxReplayRun.transaction(requires_new: true) do
        OwnerOutboxReplayRun.create!(attrs(hex: "b"))
      end
    end
    assert_equal 1, OwnerOutboxReplayRun.where(workspace: @workspace, state: "running").count

    other = OwnerOutboxReplayRun.create!(attrs(workspace: @foreign_workspace,
      owner_user: @other, hex: "a"))
    assert_equal "running", other.state

    first.update!(state: "succeeded", finished_at: @now + 1.second,
      attempted_count: 1, delivered_count: 1)
    second = OwnerOutboxReplayRun.create!(attrs(hex: "b"))
    assert_equal "running", second.state
    assert_equal 1, OwnerOutboxReplayRun.where(workspace: @workspace, state: "running").count
  end

  test "C2.3b6c2.1 duplicate request digest stays unique even after completed run" do
    first = OwnerOutboxReplayRun.create!(attrs)
    first.update!(state: "failed", finished_at: @now + 1.second,
      attempted_count: 1, failed_count: 1, error_code: "Replay::SourceUnavailable")
    duplicate = OwnerOutboxReplayRun.new(attrs)
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      OwnerOutboxReplayRun.transaction(requires_new: true) do
        OwnerOutboxReplayRun.new(attrs).save!(validate: false)
      end
    end
  end

  test "C2.3b6c2.1 invalid counters and run state are rejected" do
    invalid = OwnerOutboxReplayRun.new(attrs.merge(attempted_count: 6))
    assert_not invalid.valid?
    invalid = OwnerOutboxReplayRun.new(attrs.merge(attempted_count: 1,
      delivered_count: 1, failed_count: 1))
    assert_not invalid.valid?
    invalid = OwnerOutboxReplayRun.new(attrs.merge(state: "succeeded"))
    assert_not invalid.valid?
    invalid = OwnerOutboxReplayRun.new(attrs.merge(finished_at: @now + 1.second))
    assert_not invalid.valid?
    invalid = OwnerOutboxReplayRun.new(attrs.merge(error_code: "client body: secret"))
    assert_not invalid.valid?
  end
end
