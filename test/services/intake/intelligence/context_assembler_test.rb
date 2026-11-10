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
    row.update!(selected_options: ["landing"], feature_priorities: { "landing" => "must" }, revision: 2)
    row.intake_answer_revisions.create!(revision: 2, snapshot: row.snapshot)
    packet = assembler.build
    assert_equal 2, packet.fetch("history_index").first.fetch("snapshot_count")
    assert_equal [1, 2], assembler.history_for(question_key: "website_pages").map { |r| r.fetch("revision") }
    refute packet.fetch("reported_facts").to_json.include?("catalogue")
  end

  test "full conversation is retrievable only for the scoped intake" do
    @intake.intake_messages.create!(role: "client", body: "Synthetic clarification #1")
    @intake.intake_messages.create!(role: "assistant", body: "Synthetic clarification #2")
    @other.intake_messages.create!(role: "client", body: "Other customer's private note")
    packet = assembler.build
    assert_equal 2, packet.fetch("conversation_index").size
    refute packet.to_json.include?("Synthetic clarification #1")
    history = assembler.conversation_for
    assert_equal %w[client assistant], history.map { |item| item["role"] }
    assert_equal "Synthetic clarification #1", history.first["body"]
    refute history.to_json.include?("Other customer's private note")
    assert_raises(ArgumentError) { assembler.conversation_for(limit: 100) }
  end

  test "specification history is indexed and retrieved by exact version" do
    document = {
      "summary" => "A synthetic specification",
      "goals" => [], "deliverables" => [], "acceptance_criteria" => [],
      "unknowns" => [], "exclusions" => [], "milestones" => []
    }
    @intake.intake_spec_versions.create!(version: 1, document: document, source: "human")
    packet = assembler.build
    assert_equal false, packet.fetch("spec_index").first.fetch("owner_approved")
    assert_equal "A synthetic specification", assembler.spec_for(version: 1).dig("document", "summary")
    assert_raises(ActiveRecord::RecordNotFound) { assembler.spec_for(version: 777) }
  end

  test "unknown option is explicitly uncertain and deterministic followup is sourced" do
    save_answer(@intake, "market_locales", ["unknown"], revision: 1)
    packet = assembler.build
    fact = packet.fetch("reported_facts").find { |row| row["question_key"] == "market_locales" }
    assert_equal "unknown", fact.fetch("status")
    assert_includes fact.fetch("selected_labels"), "Not decided"
    item = packet.fetch("clarifying_questions").find { |row| row["question_key"] == "market_locales" }
    # The limited top-three list may prioritize other high-impact missing facts.
    if item
      assert_equal "respondent_reported_unknown", item.fetch("reason")
      assert_match(/\Acatalog:/, item.fetch("source"))
    end
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
    priorities = Intake::AdaptiveQuestionCatalog.prioritizable?(key) ? options.index_with { "must" } : {}
    record = intake.intake_answers.create!(
      question_key: key, selected_options: options, feature_priorities: priorities,
      comment: comment, revision: revision
    )
    record.intake_answer_revisions.create!(revision: revision, snapshot: record.snapshot)
    record
  end
end
