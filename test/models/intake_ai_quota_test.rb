require "test_helper"

class IntakeAiQuotaTest < ActiveSupport::TestCase
  test "PostgreSQL quota reserves no more than twelve calls per UTC day" do
    12.times { assert IntakeAiQuota.reserve_call! }
    assert_not IntakeAiQuota.reserve_call!
    assert_equal 12, IntakeAiQuota.find_by!(usage_day: Date.current).call_count
  end

  test "fallback questionnaire and draft need no model secret or usage" do
    intake = ProjectIntake.create!(
      title: "Synthetic website",
      project_type: "website",
      goal: "Visitors browse a demo catalog and submit a fictional estimate request",
      demo_consent_at: Time.current
    )
    old = ENV["RC_GROK_ENABLED"]
    ENV["RC_GROK_ENABLED"] = "false"
    begin
      text, source = Intake::Grok.new(intake).interview_question
      assert_equal "template", source
      assert text.present?

      spec, spec_source = Intake::Grok.new(intake).draft_spec
      assert_equal "template", spec_source
      assert spec["milestones"].all? { |row| row["suggested_work_days"] >= 1 }
      assert_equal 0, IntakeAiQuota.count
    ensure
      ENV["RC_GROK_ENABLED"] = old
    end
  end
end
