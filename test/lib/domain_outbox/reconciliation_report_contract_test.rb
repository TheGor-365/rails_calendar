require "test_helper"
require_relative "../../../lib/domain_outbox/reconciliation_report_contract"

class DomainOutboxReconciliationReportContractTest < ActiveSupport::TestCase
  CONTRACT = DomainOutbox::ReconciliationReportContract

  def fixture(phase: "before")
    {
      "schema_version" => 1,
      "phase" => phase,
      "environment" => "offline_synthetic",
      "code_sha" => "a" * 40,
      "cohort_digest" => "b" * 64,
      "run_reference" => "synthetic_audit_20261122",
      "scan_finished" => true,
      "families" => CONTRACT::FAMILIES.map do |type|
        row = {
          "source_type" => type, "inspected" => 2, "budget_exhausted" => false
        }
        CONTRACT::COUNTS.each { |key| row[key] = 0 }
        row["already_indexed"] = 2
        if type == "ClientRequestInvitation"
          row["expected_transitions"] = 3
          row["already_indexed"] = 3
        end
        row
      end
    }
  end

  test "C2.3b7h offline comparator exposes mathematical deltas but never approval" do
    before = fixture
    after = fixture(phase: "after")
    after["families"][0]["already_indexed"] = 1
    after["families"][0]["missing_both"] = 1

    result = CONTRACT.compare!(before: before, after: after)
    assert_equal "OBSERVATIONAL_DELTA_ONLY", result[:verdict]
    assert_equal false, result[:writer_authorized]
    assert_equal false, result[:release_approved]
    assert_equal false, result[:independently_verified_backup_restore]
    assert_equal false, result[:independently_verified_cohort]
    assert_equal false, result[:cohort_reference_verified]
    assert_equal true, result[:manual_review_required]
    assert_equal(-1, result[:families][0][:delta][:already_indexed])
    assert_equal 1, result[:families][0][:remaining_anomalies][:missing_both]
    assert_not result.key?(:source_id)
    assert_not result.to_json.include?("body")
  end

  test "C2.3b7h rejects added IDs, prompts or secret-like fields in public aggregates" do
    before = fixture
    before["owner_id"] = 42
    assert_raises(ArgumentError) { CONTRACT.validate!(before, phase: "before") }
    before.delete("owner_id")
    before["families"][0]["client_text"] = "fictional private text"
    assert_raises(ArgumentError) { CONTRACT.validate!(before, phase: "before") }
  end

  test "C2.3b7h refuses mismatched code, cohort and scope coverage" do
    before = fixture
    after = fixture(phase: "after")
    after["code_sha"] = "c" * 40
    assert_raises(ArgumentError) { CONTRACT.compare!(before: before, after: after) }
    after["code_sha"] = before["code_sha"]
    after["cohort_digest"] = "d" * 64
    assert_raises(ArgumentError) { CONTRACT.compare!(before: before, after: after) }
    after["cohort_digest"] = before["cohort_digest"]
    after["families"][1]["inspected"] = 3
    after["families"][1]["already_indexed"] = 3
    assert_raises(ArgumentError) { CONTRACT.compare!(before: before, after: after) }
  end

  test "C2.3b7h invitation transition arithmetic is distinct from source count" do
    before = fixture
    assert_equal 2, before["families"][3]["inspected"]
    assert_equal 3, before["families"][3]["expected_transitions"]
    assert_equal before, CONTRACT.validate!(before, phase: "before")
    before["families"][3]["expected_transitions"] = 2
    assert_raises(ArgumentError) { CONTRACT.validate!(before, phase: "before") }
  end

  test "C2.3b7h refuses truncated or budget-exhausted observations" do
    before = fixture
    after = fixture(phase: "after")
    before["scan_finished"] = false
    assert_raises(ArgumentError) { CONTRACT.compare!(before: before, after: after) }
    before["scan_finished"] = true
    after["families"][0]["budget_exhausted"] = true
    assert_raises(ArgumentError) { CONTRACT.validate!(after, phase: "after") }
  end

  test "C2.3b7h enforces AI manual-review consistency and signed integer counts" do
    before = fixture
    before["families"][5]["manual_review_required"] = 1
    assert_raises(ArgumentError) { CONTRACT.validate!(before, phase: "before") }
    before["families"][5]["manual_review_required"] = 0
    before["families"][0]["already_indexed"] = 1
    before["families"][0]["ineligible_sources"] = -1
    assert_raises(ArgumentError) { CONTRACT.validate!(before, phase: "before") }
  end
end
