module Intake
  # Pure offline visibility rules; no database, API calls or user supplied code.
  class BranchingEngine
    def self.visible?(question, answers)
      requirements = question.fetch(:requires, {})
      requirements.all? do |question_key, expected_values|
        selected = selected_options(answers[question_key] || answers[question_key.to_sym])
        (selected & expected_values).any?
      end
    end

    def self.selected_options(value)
      payload = if value.is_a?(Hash)
                  value[:selected_options] || value["selected_options"]
                elsif value.respond_to?(:selected_options)
                  # Persisted IntakeAnswer records are used by the owner-only
                  # controller after the transaction-safe database read.
                  value.selected_options
                else
                  value
                end
      Array(payload).grep(String)
    end
  end
end
