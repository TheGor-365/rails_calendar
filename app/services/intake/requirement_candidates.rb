module Intake
  # Evidence-preserving extraction. It intentionally DOES NOT hallucinate
  # atomic stories or acceptance tests from ambiguous free text.
  # Each filled domain produces one candidate requiring owner decomposition.
  class RequirementCandidates
    MAX_ROWS = 12

    def initialize(scope_revision:, previous_set: nil)
      @scope_revision = scope_revision
      @previous_set = previous_set
    end

    def build
      prior_ids = @previous_set ? @previous_set.requirements.to_h { |r| [r.dig("source", "section"), r["id"]] } : {}
      next_id = @previous_set ? @previous_set.requirements.filter_map { |r| r["id"].split("-").last.to_i }.max.to_i : 0

      IntakeScopeSections::KEYS.each_with_object([]) do |section, output|
        answer = @scope_revision.answers[section]
        next unless answer
        next unless IntakeScopeSections::KEYS.include?(section)
        text = answer.fetch("text", "").to_s.strip
        next if text.empty?

        id = prior_ids.fetch(section) do
          next_id += 1
          format("R-%03d", next_id)
        end
        output << {
          "id" => id,
          "source" => {
            "type" => "intake_scope_revision",
            "revision_id" => @scope_revision.id,
            "section" => section
          },
          "statement" => text,
          # A client marking a section confirmed is not mutual scope approval.
          "status" => answer["status"] == "excluded" ? "excluded" : "suggested",
          "acceptance_criteria" => []
        }
      end.take(MAX_ROWS)
    end
  end
end
