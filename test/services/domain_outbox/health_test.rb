require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxHealthTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-health-own-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-health-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-health-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @now = Time.zone.parse("2026-11-21 17:00:00")
    @sequence = 80_000
  end

  def envelope(workspace: @workspace, state: "pending", attempts: 0,
               occurred_at: @now - 120.seconds, next_attempt_at: nil)
    @sequence += 1
    DomainOutboxEvent.create!(
      workspace: workspace, source_type: "ProjectIntake",
      source_id: @sequence, source_version: 1,
      kind: "intake_created", state: state, attempts: attempts,
      occurred_at: occurred_at, next_attempt_at: next_attempt_at,
      delivered_at: state == "delivered" ? @now : nil
    )
  end

  test "C2.3b6a empty owner queue has zero counters and preview is read only" do
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal({
        total: 0,
        states: { "pending" => 0, "delivered" => 0, "failed" => 0 },
        due: 0, exhausted: 0, attempts_total: 0,
        oldest_undelivered_age_seconds: nil
      }, DomainOutbox::Health.snapshot(owner: @owner, now: @now))
      assert_equal [], DomainOutbox::Health.preview(owner: @owner, now: @now)
    end
  end

  test "C2.3b6a counts due retries exhausted records and age without crossing workspaces" do
    envelope(state: "pending", occurred_at: @now - 120.seconds)
    envelope(state: "failed", attempts: 2, occurred_at: @now - 300.seconds,
      next_attempt_at: @now - 1.second)
    envelope(state: "failed", attempts: 2, occurred_at: @now - 500.seconds,
      next_attempt_at: @now + 60.seconds)
    envelope(state: "failed", attempts: 5, occurred_at: @now - 900.seconds)
    envelope(state: "delivered", attempts: 1, occurred_at: @now - 1800.seconds)
    envelope(workspace: @other_workspace, state: "pending",
      occurred_at: @now - 48.hours)

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal({
        total: 5,
        states: { "pending" => 1, "delivered" => 1, "failed" => 3 },
        due: 2, exhausted: 1, attempts_total: 10,
        oldest_undelivered_age_seconds: 900
      }, DomainOutbox::Health.snapshot(owner: @owner, now: @now))
      assert_equal 1, DomainOutbox::Health.snapshot(owner: @other, now: @now)[:due]
    end
  end

  test "C2.3b6a dry-run is bounded, idempotent and never returns identifiers or source bodies" do
    first = envelope(occurred_at: @now - 50.seconds)
    second = envelope(state: "failed", attempts: 1,
      occurred_at: @now - 20.seconds, next_attempt_at: @now - 1.second)
    envelope(state: "failed", attempts: 1, occurred_at: @now - 3600.seconds,
      next_attempt_at: @now + 1.hour)
    envelope(workspace: @other_workspace)

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      expected = [
        { source_type: "ProjectIntake", kind: "intake_created",
          source_version: 1, attempts: 0, age_seconds: 50 },
        { source_type: "ProjectIntake", kind: "intake_created",
          source_version: 1, attempts: 1, age_seconds: 20 }
      ]
      assert_equal expected, DomainOutbox::Health.preview(owner: @owner, now: @now)
      assert_equal [expected.first], DomainOutbox::Health.preview(
        owner: @owner, limit: 1, now: @now
      )
      assert_equal expected, DomainOutbox::Health.preview(owner: @owner, now: @now)
      assert_not DomainOutboxEvent.where(id: [first.id, second.id], state: "delivered").exists?
      assert_not_includes DomainOutbox::Health.preview(owner: @owner, now: @now).to_json,
        first.source_id.to_s
      assert_not_includes DomainOutbox::Health.preview(owner: @owner, now: @now).to_json,
        @other_workspace.id.to_s + ":workspace"
    end
  end

  test "C2.3b6a rejects client, nil workspace owner and unbounded preview" do
    owner_without_workspace = make_test_owner("outbox-health-empty-#{SecureRandom.hex(6)}@example.test")
    [@client, owner_without_workspace, nil].each do |actor|
      assert_raises(ArgumentError) { DomainOutbox::Health.snapshot(owner: actor, now: @now) }
      assert_raises(ArgumentError) { DomainOutbox::Health.preview(owner: actor, now: @now) }
    end
    [0, 101, -1, "10", nil].each do |invalid|
      assert_raises(ArgumentError) { DomainOutbox::Health.preview(owner: @owner, limit: invalid, now: @now) }
    end
  end
end
