module Studio
  # Separate from SyntheticProjectCard: a fictional engineering roadmap step,
  # not a document or a production/client-authorized work assignment.
  class SyntheticProjectTask < ApplicationRecord
    self.table_name = "studio_synthetic_project_tasks"

    TASK_KEYS = %w[
      scope_review solution_design rails_implementation
      interface_implementation quality_verification handoff_preparation
    ].freeze

    STATES = %w[proposed ready in_progress blocked completed].freeze
    PRIORITIES = (1..5).freeze
    attr_accessor :lifecycle_actor

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :created_by, class_name: "User"
    has_many :dependencies, class_name: "Studio::SyntheticProjectTaskDependency",
             foreign_key: :dependent_task_id, dependent: :restrict_with_exception
    has_many :blocking_dependencies, class_name: "Studio::SyntheticProjectTaskDependency",
             foreign_key: :prerequisite_task_id, dependent: :restrict_with_exception

    has_many :lifecycle_events, class_name: "Studio::SyntheticProjectTaskEvent",
             foreign_key: :studio_synthetic_project_task_id,
             dependent: :restrict_with_exception

    validates :task_key, inclusion: { in: TASK_KEYS }
    validates :state, inclusion: { in: STATES }
    validates :priority, inclusion: { in: PRIORITIES }
    validates :lock_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :fictional_owner_scope
    before_update :authorized_lifecycle_only
    before_destroy :deny_mutation

    private

    def fictional_owner_scope
      unless Rails.env.test? && !Rails.env.production? &&
             workspace&.owner_access?(created_by) &&
             client&.workspace_id == workspace_id &&
             project_intake&.workspace_id == workspace_id &&
             project_intake&.client_id == client_id
        errors.add(:base, "Only exact-scope fictional owner tasks are permitted")
      end
    end

    def authorized_lifecycle_only
      state_changed = will_save_change_to_state?
      priority_changed = will_save_change_to_priority?
      allowed_columns = %w[state priority lock_version updated_at]
      unless lifecycle_actor&.id == created_by_id &&
             workspace&.owner_access?(lifecycle_actor) &&
             (state_changed != priority_changed) &&
             (changes_to_save.keys - allowed_columns).empty?
        errors.add(:base, "Use owner-scoped synthetic task lifecycle workflow")
        throw :abort
      end
    end

    def deny_mutation
      errors.add(:base, "Fictional task metadata is immutable")
      throw :abort
    end
  end
end
