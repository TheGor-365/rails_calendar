module Studio
  # Each edge means dependent_task needs prerequisite_task. The only supported
  # creation path is SyntheticProjectTaskGraph, which locks the project row
  # and rejects cycles before inserting the edge.
  class SyntheticProjectTaskDependency < ApplicationRecord
    self.table_name = "studio_synthetic_project_task_dependencies"

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :created_by, class_name: "User"
    belongs_to :dependent_task, class_name: "Studio::SyntheticProjectTask"
    belongs_to :prerequisite_task, class_name: "Studio::SyntheticProjectTask"

    attr_accessor :graph_actor

    validate :fictional_owner_and_exact_scope
    before_update :deny_mutation
    before_destroy :deny_mutation

    private

    def fictional_owner_and_exact_scope
      tasks = [dependent_task, prerequisite_task]
      unless Rails.env.test? && !Rails.env.production? &&
             graph_actor&.id == created_by_id &&
             workspace&.owner_access?(graph_actor) &&
             tasks.all? { |task|
               task && task.workspace_id == workspace_id &&
                 task.client_id == client_id &&
                 task.project_intake_id == project_intake_id
             } && dependent_task_id != prerequisite_task_id
        errors.add(:base, "Only exact-scope owner-directed fictional dependencies are permitted")
      end
    end

    def deny_mutation
      errors.add(:base, "Fictional dependency history is immutable")
      throw :abort
    end
  end
end
