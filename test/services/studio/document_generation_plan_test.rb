require "test_helper"

class StudioDocumentGenerationPlanTest < ActiveSupport::TestCase
  setup { @planner = Studio::DocumentGenerationPlan.new }

  test "nothing can be generated without its evidence" do
    result = @planner.call(evidence: {})
    assert_equal 0, result.fetch("ai_calls")
    assert_equal "document-plan.v1", result.fetch("schema_version")
    assert result.fetch("artifacts").all? { |artifact| artifact.fetch("status") == "blocked" }
    finance = result.fetch("artifacts").find { |item| item.fetch("key") == "financial_scenarios" }
    assert_equal %w[roadmap_reviewed rates_confirmed costs_confirmed], finance.fetch("missing_evidence")
  end

  test "source inspection unlocks only deterministic previews, never approval or finance" do
    result = @planner.call(evidence: { "source_inspected" => true })
    ready = result.fetch("artifacts").select { |item| item.fetch("status") == "ready_to_propose" }
    assert_equal %w[discovery_brief clarification_questions], ready.map { |item| item.fetch("key") }
    assert ready.all? { |item| item.fetch("requires_human_review") }
    assert_equal 0, result.fetch("ai_calls")
  end

  test "industrial roadmap and finance stay blocked pending confirmed inputs" do
    data = { "requirements_reviewed" => true, "priorities_confirmed" => true }
    result = @planner.call(evidence: data)
    roadmap = result.fetch("artifacts").find { |item| item.fetch("key") == "full_roadmap" }
    assert_equal "ready_to_propose", roadmap.fetch("status")
    finance = result.fetch("artifacts").find { |item| item.fetch("key") == "financial_scenarios" }
    assert_equal "blocked", finance.fetch("status")
    assert_includes finance.fetch("missing_evidence"), "rates_confirmed"
  end

  test "unknown or nonboolean evidence rejected instead of silently enabling a workflow" do
    assert_raises(ArgumentError) { @planner.call(evidence: { "untrusted" => true }) }
    assert_raises(ArgumentError) { @planner.call(evidence: { "source_inspected" => "yes" }) }
    assert_raises(ArgumentError) { @planner.call(evidence: { source_inspected: true }) }
  end
end
