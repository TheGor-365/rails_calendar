require "test_helper"
require "json"

class IntakePaidGrokTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)
  FakeHttp = Struct.new(:response) do
    def request(_request)
      response
    end
  end

  test "paid provider response is structured, charged and reused without a duplicate request" do
    intake = ProjectIntake.create!(
      title: "Synthetic Rails booking failure", project_type: "rails_bugfix",
      goal: "Synthetic POST bookings intermittently returns 500; preserve bookings and add a regression test",
      demo_consent_at: Time.current
    )
    intake.intake_messages.create!(role: "client", body: intake.goal)

    body = {
      "summary" => "Investigate a reproducible Rails 500 without assuming the root cause",
      "goals" => ["Understand the error", "Avoid data loss"],
      "deliverables" => ["Reviewed Rails fix", "Regression test", "Release notes"],
      "acceptance_criteria" => ["Repro no longer fails", "Existing bookings unchanged"],
      "unknowns" => ["Redacted stack trace", "Affected Rails versions"],
      "exclusions" => ["Unapproved changes to payment flows"],
      "milestones" => [
        { "title" => "Diagnose", "description" => "Reproduce and inspect sanitized logs", "suggested_work_days" => 1 }
      ]
    }
    payload = JSON.generate(
      "id" => "resp_synthetic_paid_test", "status" => "completed",
      "output" => [{ "type" => "message", "content" => [
        { "type" => "output_text", "text" => JSON.generate(body) }
      ] }],
      "usage" => { "input_tokens" => 300, "output_tokens" => 120,
                   "cost_in_usd_ticks" => 2_000_000 }
    )
    calls = 0
    fake = ->(*_args, **_kwargs, &block) do
      calls += 1
      block.call(FakeHttp.new(FakeResponse.new("200", payload)))
    end
    previous = %w[RC_GROK_ENABLED XAI_API_KEY].to_h { |key| [key, ENV[key]] }
    ENV["RC_GROK_ENABLED"] = "true"
    ENV["XAI_API_KEY"] = "xai-fixture-not-real-api-secret-123456789"
    Net::HTTP.stub(:start, fake) do
      a, source = Intake::Grok.new(intake).draft_spec
      assert_equal "grok", source
      assert_equal body, a
      b, source2 = Intake::Grok.new(intake).draft_spec
      assert_equal "grok", source2
      assert_equal a, b
    end
    assert_equal 1, calls
    assert_equal 1, IntakeAiQuota.sum(:call_count)
    assert_equal 1, AiSpendEntry.count
    assert_equal 2_000_000, AiSpendEntry.first.charged_ticks
    assert_equal "settled", AiSpendEntry.first.status
  ensure
    previous&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
