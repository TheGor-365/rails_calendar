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
      when IntakeRequirementSet
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
