module Intake
  module Intelligence
    # Owner-scoped offline view. A provider/export method is deliberately absent.
    # The raw goal/comments may contain PII and MUST NOT be forwarded to any AI.
    class ContextAssembler
      VERSION = "context.v1".freeze
      MAX_CHARS = 12_000
      MIN_CHARS = 1_000
      TASK_ORDER = {
        "clarification" => %w[B D F C G E],
        "estimate" => %w[D F G B C E],
        "specification" => %w[B C D E F G]
      }.freeze

      def initialize(intake:, actor:)
        raise SecurityError, "Owner session required" unless actor.is_a?(User) &&
          actor.persisted? && actor.role == "owner"
        raise ArgumentError, "Intake must be persisted" unless intake.is_a?(ProjectIntake) &&
          intake.persisted?

        @intake = intake
      end

      def build(task: "clarification", char_budget: 5_000)
        raise ArgumentError, "Unknown task" unless TASK_ORDER.key?(task)
        raise ArgumentError, "Context budget out of range" unless (MIN_CHARS..MAX_CHARS).cover?(char_budget)

        rows = @intake.intake_answers.includes(:intake_answer_revisions).to_a
        by_key = rows.index_by(&:question_key)
        visible = Intake::AdaptiveQuestionCatalog.for(@intake.project_type, answers: by_key)
        visible_keys = visible.map { |question| question.fetch(:key) }
        order = TASK_ORDER.fetch(task)
        candidates = visible.filter_map do |question|
          answer = by_key[question.fetch(:key)]
          next unless answer

          {
            "question_key" => answer.question_key,
            "section" => question.fetch(:section),
            "selected_options" => answer.selected_options,
            "selected_labels" => answer.selected_options.map { |key| question.fetch(:options).fetch(key, key) },
            "feature_priorities" => answer.feature_priorities,
            "other_text" => answer.other_text.to_s,
            "comment" => answer.comment.to_s,
            "unsure" => answer.unsure?,
            # A user selection is evidence of a reported preference, NOT proof of a delivered requirement.
            "status" => (answer.unsure? || answer.selected_options.include?("unknown")) ?
              "unknown" : "reported_by_respondent",
            "source" => "intake_answer:#{answer.id}:revision:#{answer.revision}"
          }
        end
        candidates.sort_by! { |fact| [order.index(fact.fetch("section")) || 99,
                                     visible_keys.index(fact.fetch("question_key")) || 99] }

        # Keep the compact packet bounded. History is indexed, not copied into every turn.
        selected = []
        omitted = []
        used = 0
        candidates.each do |fact|
          size = fact.to_json.bytesize
          if used + size <= char_budget
            selected << fact
            used += size
          else
            omitted << fact.fetch("question_key")
          end
        end
        history_index = rows.map do |row|
          {
            "question_key" => row.question_key,
            "latest_revision" => row.revision,
            "snapshot_count" => row.intake_answer_revisions.size,
            "active" => visible_keys.include?(row.question_key)
          }
        end.sort_by { |entry| entry.fetch("question_key") }

        # Full conversation and specification histories are indexed here. Their
        # raw bodies/documents are never copied into routine clarification packets.
        conversation_index = @intake.intake_messages.order(:created_at, :id).pluck(:id, :role).map do |id, role|
          { "source" => "intake_message:#{id}", "role" => role }
        end
        spec_index = @intake.intake_spec_versions.order(:version, :id)
                            .pluck(:id, :version, :owner_approved_at).map do |id, version, approved|
          { "source" => "intake_spec_version:#{id}", "version" => version,
            "owner_approved" => approved.present? }
        end

        {
          "schema_version" => VERSION,
          "classification" => "OWNER_INTERNAL_ONLY_DO_NOT_SEND_TO_PROVIDER",
          "source_intake_id" => @intake.id,
          "catalog_version" => Intake::AdaptiveQuestionCatalog::VERSION,
          "task" => task,
          "service_type" => @intake.project_type,
          "master" => MasterProfile.for(@intake.project_type),
          "goal" => @intake.goal, # local owner only: potentially sensitive, never provider-ready
          "reported_facts" => selected,
          "omitted_fact_keys" => omitted,
          "history_index" => history_index,
          "conversation_index" => conversation_index,
          "spec_index" => spec_index,
          "fact_budget_bytes" => char_budget,
          "clarifying_questions" => ClarificationPlanner.new(
            project_type: @intake.project_type, answers: rows
          ).call,
          "estimated_fact_tokens" => (used / 4.0).ceil,
          "is_provider_ready" => false
        }
      end

      # Full exact revision snapshots are retrieved on demand for ONE intake,
      # not broadcast as long chat history or shared across customers.
      def history_for(question_key:)
        unless Intake::AdaptiveQuestionCatalog.definition(@intake.project_type, question_key) ||
               Intake::QuizCatalog.question(@intake.project_type, question_key)
          raise ArgumentError, "Unknown question"
        end

        answer = @intake.intake_answers.find_by(question_key: question_key)
        return [] unless answer

        answer.intake_answer_revisions.order(:revision, :id).map do |revision|
          {
            "source" => "intake_answer_revision:#{revision.id}",
            "revision" => revision.revision,
            "recorded_at" => revision.created_at.iso8601,
            "snapshot" => revision.snapshot.deep_dup
          }
        end
      end

      # The owner can inspect exact chronological exchanges when clarification
      # depends on them. Never prepend full chat history to every AI request.
      def conversation_for(limit: 20)
        raise ArgumentError, "Invalid history limit" unless (1..20).cover?(limit)

        @intake.intake_messages.order(:created_at, :id).limit(limit).map do |message|
          {
            "source" => "intake_message:#{message.id}",
            "role" => message.role,
            "recorded_at" => message.created_at.iso8601,
            "body" => message.body
          }
        end
      end

      # Approved status is a real recorded owner action, not an inference.
      def spec_for(version:)
        spec = @intake.intake_spec_versions.find_by!(version: version)
        {
          "source" => "intake_spec_version:#{spec.id}",
          "version" => spec.version,
          "owner_approved" => spec.approved?,
          "document" => spec.document.deep_dup
        }
      end

      def provider_payload
        raise SecurityError, "External AI blocked until RC-036 privacy/ACL and RC-037 budget gates"
      end
    end
  end
end
