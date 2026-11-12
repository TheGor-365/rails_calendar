module Studio
  # Separate from SyntheticProjectCard: a fictional engineering roadmap step,
  # not a document or a production/client-authorized work assignment.
  class SyntheticProjectTask < ApplicationRecord
    self.table_name = "studio_synthetic_project_tasks"

    TASK_KEYS = %w[
      scope_review solution_design rails_implementation
      interface_implementation quality_verification handoff_preparation
    ].freeze

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :created_by, class_name: "User"
    has_many :dependencies, class_name: "Studio::SyntheticProjectTaskDependency",
             foreign_key: :dependent_task_id, dependent: :restrict_with_exception
    has_many :blocking_dependencies, class_name: "Studio::SyntheticProjectTaskDependency",
             foreign_key: :prerequisite_task_id, dependent: :restrict_with_exception

    validates :task_key, inclusion: { in: TASK_KEYS }
    validate :fictional_owner_scope
    before_update :deny_mutation
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

    def deny_mutation
      errors.add(:base, "Fictional task metadata is immutable")
      throw :abort
    end
  end
end
