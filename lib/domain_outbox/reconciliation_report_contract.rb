# frozen_string_literal: true

module DomainOutbox
  # C2.3b7h: OFFLINE, pure-Ruby contract for redacted, aggregate-only
  # observation reports. No ActiveRecord, disk, network, side effects,
  # writer approval or assertion of restored/snapshot-consistent data.
  class ReconciliationReportContract
    FAMILIES = %w[
      ProjectIntake IntakeScopeRevision IntakeRequirementSet
      ClientRequestInvitation ServiceOfferingPublication OwnerAiMessage
    ].freeze
    COUNTS = %w[
      already_indexed projection_only envelope_only missing_both
      inconsistent_records ineligible_sources unexpected_artifacts
      manual_review_required expected_transitions
    ].freeze
    PRIMARY = %w[
      already_indexed projection_only envelope_only missing_both
      inconsistent_records
    ].freeze
    HEADER = %w[
      schema_version phase environment code_sha cohort_digest
      run_reference scan_finished families
    ].freeze
    ROW = (%w[source_type inspected budget_exhausted] + COUNTS).freeze
    SHA = /\A[0-9a-f]{40}\z/
    DIGEST = /\A[0-9a-f]{64}\z/
    RUN_REFERENCE = /\A[a-z][a-z0-9_-]{5,63}\z/

    def self.validate!(snapshot, phase:)
      fields!(snapshot, HEADER, "snapshot")
      unless snapshot["schema_version"] == 1 &&
          snapshot["phase"] == phase &&
          %w[offline_synthetic isolated_sandbox].include?(snapshot["environment"]) &&
          snapshot["code_sha"].is_a?(String) && snapshot["code_sha"].match?(SHA) &&
          snapshot["cohort_digest"].is_a?(String) && snapshot["cohort_digest"].match?(DIGEST) &&
          snapshot["run_reference"].is_a?(String) &&
          snapshot["run_reference"].match?(RUN_REFERENCE) &&
          [true, false].include?(snapshot["scan_finished"]) &&
          snapshot["families"].is_a?(Array) &&
          snapshot["families"].length == FAMILIES.length
        raise ArgumentError, "invalid offline reconciliation snapshot"
      end

      snapshot["families"].each_with_index do |row, i|
        fields!(row, ROW, "family")
        unless row["source_type"] == FAMILIES.fetch(i) &&
            [true, false].include?(row["budget_exhausted"]) &&
            row["inspected"].instance_of?(Integer) &&
            row["inspected"].between?(0, 250) &&
            COUNTS.all? { |key| row[key].instance_of?(Integer) && row[key] >= 0 }
          raise ArgumentError, "invalid reconciliation family"
        end

        if row["source_type"] == "ClientRequestInvitation"
          unless row["expected_transitions"] <= 4 * row["inspected"] &&
              row["ineligible_sources"] <= row["inspected"] &&
              PRIMARY.sum { |key| row[key] } == row["expected_transitions"]
            raise ArgumentError, "invalid invitation transition totals"
          end
        elsif row["expected_transitions"] != 0 ||
              PRIMARY.sum { |key| row[key] } + row["ineligible_sources"] != row["inspected"]
          raise ArgumentError, "invalid reconciliation source totals"
        end

        if row["source_type"] != "OwnerAiMessage" && row["manual_review_required"] != 0
          raise ArgumentError, "unsupported manual-review count"
        end
        if row["source_type"] == "OwnerAiMessage" &&
           row["manual_review_required"] > row["missing_both"] + row["inconsistent_records"]
          raise ArgumentError, "invalid AI manual-review total"
        end
        if row["budget_exhausted"] && row["inspected"] != 250
          raise ArgumentError, "budget exhaustion without full family scan"
        end
      end
      snapshot
    end

    # Mathematical before/after DIFFERENCE only. Even a zero-anomaly report
    # is never evidence of owner authorization, DB backup/restore parity,
    # immutable cohort equivalence, or production readiness.
    def self.compare!(before:, after:)
      validate!(before, phase: "before")
      validate!(after, phase: "after")
      %w[environment code_sha cohort_digest].each do |key|
        raise ArgumentError, "non-comparable #{key}" unless before.fetch(key) == after.fetch(key)
      end
      unless before.fetch("scan_finished") && after.fetch("scan_finished") &&
          (before.fetch("families") + after.fetch("families")).none? { |row| row.fetch("budget_exhausted") }
        raise ArgumentError, "incomplete or budget-limited reconciliation observations"
      end

      rows = before.fetch("families").zip(after.fetch("families")).map do |initial, final|
        unless initial.fetch("inspected") == final.fetch("inspected") &&
            initial.fetch("expected_transitions") == final.fetch("expected_transitions")
          raise ArgumentError, "source cohort cardinality changed; independent review required"
        end
        {
          source_type: initial.fetch("source_type"),
          inspected: initial.fetch("inspected"),
          delta: COUNTS.to_h { |key| [key.to_sym, final.fetch(key) - initial.fetch(key)] },
          remaining_anomalies: %w[missing_both inconsistent_records ineligible_sources
            unexpected_artifacts manual_review_required].to_h do |key|
            [key.to_sym, final.fetch(key)]
          end
        }
      end
      {
        verdict: "OBSERVATIONAL_DELTA_ONLY",
        release_approved: false,
        writer_authorized: false,
        independently_verified_cohort: false,
        independently_verified_backup_restore: false,
        # This is an OPERATOR-SUPPLIED matching reference, not cryptographic
        # proof that both scans saw identical canonical row identities.
        cohort_reference_verified: false,
        manual_review_required: rows.any? do |row|
          row[:remaining_anomalies].values.any?(&:positive?) ||
            row[:delta][:already_indexed].negative?
        end,
        families: rows
      }
    end

    def self.fields!(value, expected, label)
      unless value.is_a?(Hash) && value.keys.all? { |key| key.is_a?(String) } &&
          value.keys.sort == expected.sort
        raise ArgumentError, "invalid #{label} fields"
      end
    end
    private_class_method :fields!
  end
end
