module Intake
  module Intelligence
    # Free, deterministic gap analysis. No AI request and no free-form guesses.
    class ClarificationPlanner
      MAX_QUESTIONS = 3

      def initialize(project_type:, answers:)
        @project_type = project_type.to_s
        @answers = answers.index_by { |answer| answer.question_key }
      end

      def call(limit: MAX_QUESTIONS)
        raise ArgumentError, "Invalid clarification limit" unless (1..MAX_QUESTIONS).cover?(limit)

        questions = Intake::AdaptiveQuestionCatalog.for(@project_type, answers: @answers)
        focus = MasterProfile.for(@project_type).fetch("service").fetch("discovery_focus")
        questions.filter_map do |question|
          key = question.fetch(:key)
          answer = @answers[key]
          next if answer && !answer.unsure? && !answer.selected_options.include?("unknown")

          {
            "question_key" => key,
            "section" => question.fetch(:section),
            "title" => question.fetch(:title),
            "reason" => if answer&.unsure?
                          "owner_selected_not_sure"
                        elsif answer&.selected_options&.include?("unknown")
                          "respondent_reported_unknown"
                        else
                          "missing_saved_answer"
                        end,
            "priority" => focus.include?(key) ? "high" : "normal",
            "source" => "catalog:#{Intake::AdaptiveQuestionCatalog::VERSION}:#{key}",
            "status" => "suggested_question_not_sent"
          }
        end.sort_by { |q| [q.fetch("priority") == "high" ? 0 : 1,
                           questions.index { |item| item.fetch(:key) == q.fetch("question_key") }] }
           .first(limit)
      end
    end
  end
end
