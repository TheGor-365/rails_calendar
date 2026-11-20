module Activity
  # Source records remain authoritative. Event keys make callback retries safe.
  # This service never calls an AI provider or sends external notifications.
  class Recorder
    def self.record!(workspace:, subject:, kind:, title:, metadata: {}, occurred_at: Time.current)
      return unless workspace&.persisted? && subject&.persisted?

      key = "#{subject.class.name}:#{subject.id}:#{kind}"
      return unless ActivityEvent::KINDS.include?(kind)

      # Uniqueness is enforced in PostgreSQL; ON CONFLICT avoids double entries
      # after concurrent updates or retries without overwriting old history.
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
  end
end
