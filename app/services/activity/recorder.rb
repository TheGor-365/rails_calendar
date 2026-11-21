module Activity
  # An immutable, owner-scoped index of canonical source records.
  # Legacy events keep the original type:id:kind key; repeated source changes
  # may use a positive revision for distinct, idempotent type:id:kind:vN keys.
  # Never forwards prompts/files to a model, makes charges or publishes records.
  class Recorder
    SAFE_METADATA_KEYS = %w[operation status version].freeze

    def self.record!(workspace:, subject:, kind:, title:, metadata: {}, occurred_at: Time.current, revision: nil)
      return unless workspace&.persisted? && subject&.persisted?
      return unless ActivityEvent::KINDS.include?(kind)
      return unless authorized_source?(workspace: workspace, subject: subject)
      return unless revision.nil? || (revision.is_a?(Integer) && revision.between?(1, 1_000_000))
      return unless metadata.is_a?(Hash) && (metadata.keys - SAFE_METADATA_KEYS).empty? &&
        metadata.to_json.bytesize <= 512

      key = "#{subject.class.name}:#{subject.id}:#{kind}"
      key += ":v#{revision}" if revision
      return if key.length > 180

      # ON CONFLICT guarantees retries do not create duplicate notifications
      # and does not overwrite the original event/time on replay.
      ActivityEvent.insert_all(
        [{
          workspace_id: workspace.id, event_key: key, kind: kind,
          subject_type: subject.class.name, subject_id: subject.id,
          title: title.to_s.truncate(180),
          occurred_at: occurred_at, metadata: metadata,
          created_at: Time.current
        }],
        unique_by: :idx_activity_events_workspace_key
      )
    end

    def self.authorized_source?(workspace:, subject:)
      source_workspace_id = case subject
      when ClientRequestInvitation, ProjectIntake, OwnerAiConversation
        subject.workspace_id
      when OwnerAiMessage
        subject.owner_ai_conversation&.workspace_id if subject.role == "assistant" &&
          subject.state == "settled" && subject.ai_spend_entry&.status == "settled" &&
          subject.ai_spend_entry.professional_profile&.workspace_id ==
            subject.owner_ai_conversation&.workspace_id
      when ServiceOfferingPublication
        offering = subject.service_offering
        if offering&.workspace_id == workspace.id &&
            subject.owner_user_id == workspace.owner_user_id &&
            (subject.event == "unpublish" ||
             (subject.event == "publish" && subject.service_offering_version&.approved?))
          offering.workspace_id
        end
      when IntakeScopeRevision, IntakeRequirementSet
        subject.project_intake&.workspace_id
      when AiSpendEntry
        subject.activity_workspace&.id
      else
        return false
      end
      source_workspace_id == workspace.id
    end
    private_class_method :authorized_source?
  end
end
