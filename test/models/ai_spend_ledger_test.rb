require "test_helper"
require "digest"

class AiSpendLedgerTest < ActiveSupport::TestCase
  def setup
    @intake = ProjectIntake.create!(
      title: "Synthetic Rails booking failure", project_type: "rails_bugfix",
      goal: "Synthetic POST bookings gives occasional 500 without real customer data",
      demo_consent_at: Time.current
    )
  end

  def digest_for(n)
    Digest::SHA256.hexdigest("rc051-intake-#{@intake.id}-#{n}")
  end

  test "reserves under a global serializable PostgreSQL lock and rejects budget overflow" do
    5.times do |i|
      entry, fresh = AiSpendLedger.reserve!(
        project_intake: @intake, operation: "intake_question",
        model: "grok-4.3", request_digest: digest_for(i)
      )
      assert fresh
      assert_equal "reserved", entry.status
      assert_equal 1_000_000_000, entry.reserved_ticks
    end

    assert_raises(AiSpendLedger::LimitReached) do
      AiSpendLedger.reserve!(
        project_intake: @intake, operation: "intake_question",
        model: "grok-4.3", request_digest: digest_for(6)
      )
    end
    assert_equal 5, AiSpendEntry.where(project_intake: @intake).count
  end

  test "replays successful identical requests without a second provider call" do
    entry, fresh = AiSpendLedger.reserve!(
      project_intake: @intake, operation: "website_spec_draft",
      model: "grok-4.3", request_digest: digest_for(12)
    )
    assert fresh
    document = { "question" => "Which synthetic logs reproduce this Rails 500?" }
    response = {
      "id" => "resp_fixture_1",
      "usage" => { "cost_in_usd_ticks" => 1_250_000,
                   "input_tokens" => 250, "output_tokens" => 50 }
    }
    assert_equal document, AiSpendLedger.settle!(entry: entry, response: response, result: document)

    cached, new_request = AiSpendLedger.reserve!(
      project_intake: @intake, operation: "website_spec_draft",
      model: "grok-4.3", request_digest: digest_for(12)
    )
    assert_not new_request
    assert_equal entry.id, cached.id
    assert_equal document, cached.result
    assert_equal 1_250_000, cached.charged_ticks
    assert_equal 1, AiSpendEntry.count
  end

  test "unknown billing holds the reservation and blocks automatic retry" do
    entry, = AiSpendLedger.reserve!(
      project_intake: @intake, operation: "intake_question",
      model: "grok-4.3", request_digest: digest_for(13)
    )
    AiSpendLedger.uncertain!(entry: entry)
    assert_equal "uncertain", entry.reload.status

    assert_raises(AiSpendLedger::ReplayBlocked) do
      AiSpendLedger.reserve!(
        project_intake: @intake, operation: "intake_question",
        model: "grok-4.3", request_digest: digest_for(13)
      )
    end
    assert_equal 1_000_000_000, AiSpendLedger.spend_summary.fetch(:held_ticks)
  end
end
