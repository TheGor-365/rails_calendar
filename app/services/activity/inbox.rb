module Activity
  # One source of truth for notification counters. No separate copied payload.
  # A receipt can only hide an event from the owner's unread queue.
  class Inbox
    def self.unread_for(owner:)
      workspace = owner&.owner_workspace
      return ActivityEvent.none unless owner&.role == "owner" && workspace

      workspace.activity_events.where.not(id:
        ActivityEventRead.where(owner_user_id: owner.id).select(:activity_event_id))
    end

    def self.mark_read!(owner:, event:)
      raise ActiveRecord::RecordNotFound unless owner&.role == "owner" &&
        event.workspace.owner_user_id == owner.id

      ActivityEventRead.insert_all(
        [{ owner_user_id: owner.id, activity_event_id: event.id,
           read_at: Time.current }],
        unique_by: :idx_activity_event_reads_owner_event
      )
    end

    def self.mark_all_read!(owner:)
      raise ActiveRecord::RecordNotFound unless owner&.role == "owner" &&
        owner.owner_workspace

      # Work in bounded batches to avoid an enormous SQL VALUES statement.
      unread_for(owner: owner).in_batches(of: 500) do |batch|
        now = Time.current
        rows = batch.pluck(:id).map do |id|
          { owner_user_id: owner.id, activity_event_id: id, read_at: now }
        end
        ActivityEventRead.insert_all(rows,
          unique_by: :idx_activity_event_reads_owner_event) if rows.any?
      end
    end
  end
end
