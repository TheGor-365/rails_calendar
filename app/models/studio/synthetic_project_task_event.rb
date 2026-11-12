module Studio
  # Audit receipts cannot approve work, and must be appended by the owner-
  # scoped lifecycle workflow in the same transaction as the state update.
  class SyntheticProjectTaskEvent < ApplicationRecord
    self.table_name = "studio_synthetic_project_task_events"

    belongs_to :synthetic_project_task, class_name: "Studio::SyntheticProjectTask",
               foreign_key: :studio_synthetic_project_task_id
    belongs_to :actor_user, class_name: "User"
    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake

    attr_accessor :lifecycle_actor

    validates :sequence, numericality: { only_integer: true, greater_than: 0 }
    validates :event_type, inclusion: { in: %w[transition priority_change] }
    validates :from_state, :to_state, inclusion: { in: SyntheticProjectTask::STATES }
    validates :from_priority, :to_priority, inclusion: { in: SyntheticProjectTask::PRIORITIES }
    validates :recorded_at, presence: true
    validate :owner_scope_and_event_shape
    before_update :deny_mutation
    before_destroy :deny_mutation

    private

    def owner_scope_and_event_shape
      task = synthetic_project_task
      permitted = if event_type == "transition"
        SyntheticProjectTaskLifecycle::TRANSITIONS.fetch(from_state, []).include?(to_state) &&
          from_priority == to_priority
      elsif event_type == "priority_change"
        from_state == to_state && from_state != "completed" &&
          from_priority != to_priority
      else
        false
      end
      unless Rails.env.test? && !Rails.env.production? &&
             lifecycle_actor&.id == actor_user_id &&
             task&.created_by_id == actor_user_id &&
             workspace&.owner_access?(lifecycle_actor) &&
             task&.workspace_id == workspace_id &&
             task&.client_id == client_id &&
             task&.project_intake_id == project_intake_id && permitted
        errors.add(:base, "Only exact-scope synthetic owner lifecycle events are allowed")
      end
    end

    def deny_mutation
      errors.add(:base, "Fictional task lifecycle events are immutable")
      throw :abort
    end
  end
end
