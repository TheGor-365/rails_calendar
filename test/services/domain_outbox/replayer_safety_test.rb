require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxReplayerSafetyTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-reliability-#{SecureRandom.hex(5)}@example.test")
    @other = make_test_owner("outbox-reliability-other-#{SecureRandom.hex(5)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @foreign_workspace, = approved_profile_for(@other)
    @now = Time.zone.parse("2026-11-21 17:00:00")
  end

  def missing_source(workspace: @workspace, source_id: 87_610_219)
    DomainOutboxEvent.create!(
      workspace: workspace, source_type: "ProjectIntake", source_id: source_id,
      source_version: 1, kind: "intake_created", state: "pending",
      occurred_at: @now - 2.minutes
    )
  end

  test "C2.3b6c1 failure retry is bounded, backoff is deterministic and terminal is not rescheduled" do
    row = missing_source
    delays = [2, 4, 8, 16, 32]
    clock = @now

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count",
                          "AiSpendEntry.count", "ProjectIntake.count"]) do
      delays.each_with_index do |delay, index|
        result = DomainOutbox::Replayer.run!(workspace: @workspace, now: clock, limit: 1)
        assert_equal({ attempted: 1, delivered: 0, failed: 1 }, result)
        row.reload
        assert_equal "failed", row.state
        assert_equal index + 1, row.attempts
        assert_equal "DomainOutbox::Replayer::SourceUnavailable", row.last_error_code

        if row.attempts == DomainOutboxEvent::MAX_ATTEMPTS
          assert_nil row.next_attempt_at
        else
          assert_equal clock.to_i + delay, row.next_attempt_at.to_i
          assert_equal({ attempted: 0, delivered: 0, failed: 0 },
            DomainOutbox::Replayer.run!(workspace: @workspace, now: clock + (delay - 1).seconds))
        end
        clock += delay.seconds
      end

      assert_equal({ attempted: 0, delivered: 0, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace, now: clock + 1.year))
      assert_equal 5, row.reload.attempts
      assert_equal 1, DomainOutbox::Health.snapshot(owner: @owner, now: clock)[:exhausted]
      assert_equal [], DomainOutbox::Health.preview(owner: @owner, now: clock)
    end
  end

  test "C2.3b6c1 due queue respects per-invocation limit, workspace, and no extra attempts" do
    first = missing_source(source_id: 87_610_301)
    second = missing_source(source_id: 87_610_302)
    foreign = missing_source(workspace: @foreign_workspace, source_id: 87_610_303)

    assert_raises(ArgumentError) do
      DomainOutbox::Replayer.run!(workspace: @workspace, limit: 101, now: @now)
    end
    assert_raises(ArgumentError) do
      DomainOutbox::Replayer.run!(workspace: @workspace, limit: 0, now: @now)
    end

    assert_no_difference(["AiSpendEntry.count", "ActivityEvent.count"]) do
      assert_equal({ attempted: 1, delivered: 0, failed: 1 },
        DomainOutbox::Replayer.run!(workspace: @workspace, limit: 1, now: @now))
    end
    assert_equal 1, first.reload.attempts
    assert_equal 0, second.reload.attempts
    assert_equal 0, foreign.reload.attempts

    assert_no_difference(["AiSpendEntry.count", "ActivityEvent.count"]) do
      assert_equal({ attempted: 1, delivered: 0, failed: 1 },
        DomainOutbox::Replayer.run!(workspace: @workspace, limit: 1, now: @now))
    end
    assert_equal 1, first.reload.attempts
    assert_equal 1, second.reload.attempts
    assert_equal 0, foreign.reload.attempts
  end
end
