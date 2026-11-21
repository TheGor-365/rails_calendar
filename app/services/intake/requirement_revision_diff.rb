module Intake
  # Read-only comparison of immutable requirement snapshots, keyed by stable R-ID.
  # Never merges client data across different requests or changes saved records.
  class RequirementRevisionDiff
    FIELDS = %w[statement status acceptance_criteria source].freeze

    def initialize(previous:, current:)
      raise ArgumentError, "current requirement set required" unless current.is_a?(IntakeRequirementSet)
      if previous && (!previous.is_a?(IntakeRequirementSet) ||
                      previous.project_intake_id != current.project_intake_id ||
                      previous.version >= current.version)
        raise ArgumentError, "requirement revisions must belong to one intake and be ordered"
      end

      @previous = previous
      @current = current
    end

    def changes
      before = (@previous&.requirements || []).index_by { |row| row.fetch("id") }
      after = @current.requirements.index_by { |row| row.fetch("id") }

      (before.keys | after.keys).sort_by { |id| id.split("-").last.to_i }.filter_map do |id|
        old_row = before[id]
        new_row = after[id]
        next if old_row == new_row

        kind = old_row.nil? ? :added : new_row.nil? ? :removed : :changed
        fields = kind == :changed ? FIELDS.select { |field| old_row[field] != new_row[field] } : FIELDS

        {
          id: id,
          kind: kind,
          fields: fields,
          before: old_row&.deep_dup,
          after: new_row&.deep_dup
        }
      end
    end
  end
end
