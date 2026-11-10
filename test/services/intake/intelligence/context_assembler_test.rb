require "test_helper"

class IntakeIntelligenceContextAssemblerTest < ActiveSupport::TestCase
  setup do
    @password = "synthetic-intelligence-owner-password-123"
    @owner = User.create!(email: "offline-context-owner@example.test",
                          role: "owner", password: @password,
                          password_confirmation: @password)
    @intake = ProjectIntake.create!(
      title: "Synthetic website brief", project_type: "website",
      goal: "Create a synthetic product catalogue for demo enquiries",
      demo_consent_at: Time.current
    )
    @other = ProjectIntake.create!(
      title: "Unrelated synthetic project", project_type: "rails_bugfix",
      goal: "Fix reproducible validation problems in an unrelated test system",
      demo_consent_at: Time.current
    )
  end

  test "owner gets scoped facts, master abilities and an on-demand history index" do
    save_answer(@intake, "website_pages", ["catalogue"], revision: 1)
    save_answer(@intake, "website_checkout", ["checkout"], revision: 1)
    save_answer(@other, "bug_symptoms", ["forms"], revision: 1)
    result = assembler.build(task: "clarification")
    assert_equal "OWNER_INTERNAL_ONLY_DO_NOT_SEND_TO_PROVIDER", result["classification"]
    assert_equal false, result["is_provider_ready"]
    assert_equal @intake.id, result["source_intake_id"]
    assert_equal "master.v1", result.dig("master", "profile_version")
    assert_includes result.dig("master", "service", "feasible_slices"), "Basic catalogue"
    assert result["reported_facts"].any? { |fact| fact["question_key"] == "website_checkout" }
    refute result["reported_facts"].any? { |fact| fact["question_key"] == "bug_symptoms" }
    assert_equal %w[website_checkout website_pages], result["history_index"].map { |entry| entry["question_key"] }
    assert_equal 1, assembler.history_for(question_key: "website_checkout").size
    assert_empty assembler.history_for(question_key: "business_goals")
  end

  test "respondent evidence is not upgraded to an approved specification" do
    save_answer(@intake, "business_goals", ["leads"], revision: 1)
    fact = assembler.build.fetch("reported_facts").find { |r| r["question_key"] == "business_goals" }
    assert_equal "reported_by_respondent", fact.fetch("status")
    assert_match(/intake_answer:\d+:revision:1/, fact.fetch("source"))
    assert_equal "clarification.v1", Intake::Intelligence::PromptContract::VERSION
    assert_match(/Never request passwords/, Intake::Intelligence::PromptContract::SYSTEM_INSTRUCTIONS)
  end

  test "previous revisions are preserved and can be retrieved without dumping all history" do
    row = save_answer(@intake, "website_pages", ["catalogue"], revision: 1)
    row.update!(selected_options: ["landing"], revision: 2)
    row.intake_answer_revisions.create!(revision: 2, snapshot: row.snapshot)
    packet = assembler.build
    assert_equal 2, packet.fetch("history_index").first.fetch("snapshot_count")
    assert_equal [1, 2], assembler.history_for(question_key: "website_pages").map { |r| r.fetch("revision") }
    refute packet.fetch("reported_facts").to_json.include?("catalogue")
  end

  test "restricted actors and provider access are rejected" do
    assert_raises(SecurityError) do
      Intake::Intelligence::ContextAssembler.new(intake: @intake, actor: nil)
    end
    assert_raises(SecurityError) { assembler.provider_payload }
    assert_raises(ArgumentError) { assembler.history_for(question_key: "random_key") }
    assert_raises(ArgumentError) { assembler.build(char_budget: 10) }
  end

  test "bounded context has honest omission markers and deterministic gaps" do
    save_answer(@intake, "business_goals", ["leads"], revision: 1, comment: "X" * 500)
    save_answer(@intake, "audiences", ["customers"], revision: 1, comment: "Y" * 500)
    save_answer(@intake, "scope", ["frontend"], revision: 1, comment: "Z" * 500)
    result = assembler.build(char_budget: 1_000)
    assert result["reported_facts"].size < 3
    assert result["omitted_fact_keys"].any?
    assert result["estimated_fact_tokens"] <= 250
    assert result["clarifying_questions"].size <= 3
    refute result["clarifying_questions"].any? { |q| q["question_key"] == "business_goals" }
  end

  test "clarification questions are sourced, relevant, and skip hidden branches" do
    save_answer(@intake, "website_pages", ["landing"], revision: 1)
    q = assembler.build.fetch("clarifying_questions")
    assert q.all? { |item| item.fetch("status") == "suggested_question_not_sent" }
    refute q.any? { |item| item.fetch("question_key") == "website_checkout" }
    refute q.any? { |item| item.fetch("question_key") == "website_pages" }
    assert q.any? { |item| item.fetch("question_key") == "business_goals" }
  end

  private

  def assembler
    Intake::Intelligence::ContextAssembler.new(intake: @intake, actor: @owner)
  end

  def save_answer(intake, key, options, revision:, comment: "")
    record = intake.intake_answers.create!(
      question_key: key, selected_options: options, comment: comment, revision: revision
    )
    record.intake_answer_revisions.create!(revision: revision, snapshot: record.snapshot)
    record
  end
end
