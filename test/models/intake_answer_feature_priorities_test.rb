require "test_helper"

class IntakeAnswerFeaturePrioritiesTest < ActiveSupport::TestCase
  setup do
    @intake = ProjectIntake.create!(
      title: "Synthetic priority QA", project_type: "website",
      goal: "Collect fictional leads with a simple catalogue",
      demo_consent_at: Time.current
    )
  end

  test "adaptive features require explicit must should or later priorities" do
    answer = @intake.intake_answers.build(
      question_key: "website_pages", selected_options: %w[landing catalogue],
      feature_priorities: { "landing" => "must" }
    )
    assert_not answer.valid?
    assert_includes answer.errors[:feature_priorities].join(" "), "must be set"

    answer.feature_priorities["catalogue"] = "later"
    assert answer.valid?, answer.errors.full_messages.inspect
    answer.save!
    assert_equal({ "landing" => "must", "catalogue" => "later" }, answer.reload.feature_priorities)
    assert_equal answer.feature_priorities, answer.snapshot.fetch("feature_priorities")
  end

  test "invalid values and keys are rejected" do
    answer = @intake.intake_answers.build(
      question_key: "scope", selected_options: ["frontend"],
      feature_priorities: { "frontend" => "urgent" }
    )
    assert_not answer.valid?
    assert_includes answer.errors[:feature_priorities].join(" "), "invalid"

    answer.feature_priorities = { "backend" => "must", "frontend" => "should" }
    assert_not answer.valid?
    answer.feature_priorities = { "frontend" => "should" }
    assert answer.valid?, answer.errors.full_messages.inspect
  end

  test "legacy two question flow is unchanged and old rows can be read without priorities" do
    legacy = @intake.intake_answers.create!(
      question_key: "features", selected_options: %w[contact_form], revision: 1
    )
    assert_equal({}, legacy.feature_priorities)
    assert legacy.valid?

    # Existing v1 answers may not have priorities. Keep the record and its
    # revision untouched; only a new edit must assign missing priorities.
    old = @intake.intake_answers.create!(
      question_key: "website_pages", selected_options: ["landing"],
      feature_priorities: { "landing" => "must" }, revision: 1
    )
    old.intake_answer_revisions.create!(
      revision: 1,
      snapshot: old.snapshot.except("feature_priorities").merge("catalog_version" => "rc035b.v1")
    )
    assert_equal "rc035b.v1", old.intake_answer_revisions.sole.snapshot["catalog_version"]
    assert_equal "rc035b.v2", Intake::AdaptiveQuestionCatalog::VERSION
    assert_includes Intake::AdaptiveQuestionCatalog::SUPPORTED_HISTORY_VERSIONS, "rc035b.v1"
  end
end
