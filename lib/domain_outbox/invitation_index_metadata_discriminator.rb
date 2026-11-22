# frozen_string_literal: true

require_relative "invitation_index_metadata_triage"

module DomainOutbox
  # Pure, bounded discriminator. Reuses the prior pg_catalog metadata validator.
  class InvitationIndexMetadataDiscriminator
    PROBE = InvitationIndexMetadataTriage
    VARIANTS = %w[
      EXPECTED_NAME_DEFINITION_DRIFT ALTERNATE_NAME_VALID_READY
      ALTERNATE_NAME_INVALID_OR_NOT_READY MULTIPLE_ALTERNATE_MATCHES
    ].freeze
    DIFFERENCES = %w[KEYS METHOD INCLUDED_COUNT PREDICATE EXPRESSION NAME NONE].freeze

    def self.evaluate(doc)
      return nil unless PROBE.classify(doc) == "INDEX_NAME_OR_DEFINITION_DRIFT"

      indexes = doc.fetch("indexes")
      named = indexes.find { |item| item.fetch("name") == PROBE::EXPECTED_INDEX }
      if named
        differences = []
        differences << "KEYS" unless named["keys"] == PROBE::EXPECTED_KEYS
        differences << "METHOD" unless named["method"] == "btree"
        differences << "INCLUDED_COUNT" unless named["included_count"] == 0
        differences << "PREDICATE" unless named["has_predicate"] == false
        differences << "EXPRESSION" unless named["has_expression"] == false
        return nil if differences.empty?
        return { variant: "EXPECTED_NAME_DEFINITION_DRIFT",
                 name: PROBE::EXPECTED_INDEX, delta: differences.join(",") }.freeze
      end

      alternates = indexes.select do |item|
        !item["unique"] && item["keys"] == PROBE::EXPECTED_KEYS &&
          item["method"] == "btree" && item["included_count"] == 0 &&
          item["has_predicate"] == false && item["has_expression"] == false
      end
      return nil if alternates.empty?
      return { variant: "MULTIPLE_ALTERNATE_MATCHES",
               name: "MULTIPLE_NOT_EXPOSED", delta: "NONE" }.freeze if alternates.length > 1

      alternate = alternates.first
      variant = if alternate["valid"] && alternate["ready"]
        "ALTERNATE_NAME_VALID_READY"
      else
        "ALTERNATE_NAME_INVALID_OR_NOT_READY"
      end
      { variant: variant, name: alternate.fetch("name"), delta: "NAME" }.freeze
    end
  end
end
