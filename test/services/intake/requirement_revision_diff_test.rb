require "test_helper"

class IntakeRequirementRevisionDiffTest < ActiveSupport::TestCase
  def row(id:, statement:, status: "suggested", criteria: [], section: "business_goal", revision: 11)
    {
      "id" => id,
      "source" => { "type" => "intake_scope_revision", "revision_id" => revision, "section" => section },
      "statement" => statement,
      "status" => status,
      "acceptance_criteria" => criteria
    }
  end

  def snapshot(version:, rows:, intake_id: 77)
    IntakeRequirementSet.new(project_intake_id: intake_id, version: version, requirements: rows)
  end

  test "compares by stable ID, not array position, and reports edited fields" do
    earlier = snapshot(version: 1, rows: [
      row(id: "R-002", statement: "Capture requests"),
      row(id: "R-001", statement: "Show the form")
    ])
    current = snapshot(version: 2, rows: [
      row(id: "R-001", statement: "Show accessible form", criteria: ["Keyboard works"]),
      row(id: "R-003", statement: "Send confirmation")
    ])

    changes = Intake::RequirementRevisionDiff.new(previous: earlier, current: current).changes
    assert_equal %w[R-001 R-002 R-003], changes.pluck(:id)
    assert_equal %i[changed removed added], changes.pluck(:kind)
    assert_equal %w[statement acceptance_criteria], changes.first.fetch(:fields)
    assert_equal "Show the form", changes.first.dig(:before, "statement")
    assert_equal "Show accessible form", changes.first.dig(:after, "statement")
    assert_nil changes.second.fetch(:after)
    assert_nil changes.third.fetch(:before)
    assert_equal "Show the form", earlier.requirements.last.fetch("statement")
  end

  test "first revision is additions; unchanged or reordered revisions have no diff" do
    original = snapshot(version: 1, rows: [
      row(id: "R-010", statement: "Export"),
      row(id: "R-002", statement: "Upload")
    ])
    first = Intake::RequirementRevisionDiff.new(previous: nil, current: original).changes
    assert_equal %w[R-002 R-010], first.pluck(:id)
    assert first.all? { |change| change.fetch(:kind) == :added }

    reordered = snapshot(version: 2, rows: original.requirements.reverse)
    assert_empty Intake::RequirementRevisionDiff.new(previous: original, current: reordered).changes
  end

  test "tracks provenance and status changes without modifying originals" do
    earlier = snapshot(version: 1, rows: [row(id: "R-001", statement: "Draft")])
    newer = snapshot(version: 2, rows: [
      row(id: "R-001", statement: "Draft", status: "excluded", revision: 16)
    ])
    changes = Intake::RequirementRevisionDiff.new(previous: earlier, current: newer).changes
    assert_equal %w[status source], changes.first.fetch(:fields)
    changes.first.fetch(:after)["statement"] = "Mutated outside model"
    assert_equal "Draft", newer.requirements.first.fetch("statement")
  end

  test "rejects comparisons across tenants or in reverse version order" do
    a = snapshot(version: 2, rows: [row(id: "R-001", statement: "A")], intake_id: 12)
    other = snapshot(version: 3, rows: [row(id: "R-001", statement: "B")], intake_id: 13)
    assert_raises(ArgumentError) { Intake::RequirementRevisionDiff.new(previous: a, current: other) }
    assert_raises(ArgumentError) { Intake::RequirementRevisionDiff.new(previous: other, current: a) }
    assert_raises(ArgumentError) { Intake::RequirementRevisionDiff.new(previous: a, current: a) }
  end
end
