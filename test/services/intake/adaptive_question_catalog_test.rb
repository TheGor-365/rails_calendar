require "test_helper"

class AdaptiveQuestionCatalogTest < ActiveSupport::TestCase
  test "all current intake types have deterministic B-G questions without AI calls" do
    ProjectIntake::TYPES.each do |project_type|
      questions = Intake::AdaptiveQuestionCatalog.for(project_type)
      assert questions.any?
      assert_equal %w[B C D F G], questions.map { |q| q[:section] }.uniq - %w[E]
      assert_equal questions.map { |q| q[:key] }.uniq, questions.map { |q| q[:key] }
      assert questions.all? { |q| %i[single multi].include?(q[:mode]) }
      assert questions.all? { |q| q[:options].size.between?(1, 10) }
    end
  end

  test "rails bugfix never receives the website brand/logo question" do
    questions = Intake::AdaptiveQuestionCatalog.for("rails_bugfix")
    refute questions.any? { |q| q[:section] == "E" }
    refute questions.any? { |q| q[:title].match?(/logo|brand|design materials/i) }
    assert questions.any? { |q| q[:key] == "bug_repro" }
  end

  test "website catalogue follow-up appears only after catalogue selection" do
    questions = Intake::AdaptiveQuestionCatalog.for("website")
    refute_includes questions.map { |q| q[:key] }, "website_checkout"

    selected = Intake::AdaptiveQuestionCatalog.for("website", answers: { "website_pages" => ["catalogue", "booking"] })
    assert_includes selected.map { |q| q[:key] }, "website_checkout"

    changed = Intake::AdaptiveQuestionCatalog.for("website", answers: { "website_pages" => ["landing"] })
    refute_includes changed.map { |q| q[:key] }, "website_checkout"
  end

  test "API webhook follow-up accepts persisted answer payload" do
    answers = { "api_mechanism" => { "selected_options" => ["rest", "webhook"] } }
    assert Intake::AdaptiveQuestionCatalog.question("api_integration", "api_webhook_recovery", answers: answers)
    refute Intake::AdaptiveQuestionCatalog.question("api_integration", "api_webhook_recovery", answers: {})
  end

  test "unknown type stays on a safe generic track and invalid type has no questions" do
    unknown = Intake::AdaptiveQuestionCatalog.for("unknown")
    assert_equal %w[B C D F G], unknown.map { |q| q[:section] }.uniq
    assert_empty Intake::AdaptiveQuestionCatalog.for("surprise")
  end

  test "caller cannot mutate the catalogue through a returned options hash" do
    first = Intake::AdaptiveQuestionCatalog.for("website").first
    first[:options]["leads"] = "changed"
    assert_equal "More enquiries", Intake::AdaptiveQuestionCatalog.for("website").first[:options]["leads"]
  end
end
