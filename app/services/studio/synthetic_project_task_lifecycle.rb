module Studio
  # RC-039 Slice G. Simulates workflow over fictional fixed-key task metadata.
  # No HTTP, customer tasks, real execution, billing, approvals or dates.
  class SyntheticProjectTaskLifecycle
    class Denied < StandardError; end
    class Conflict < StandardError; end

    TRANSITIONS = {
      "proposed" => %w[ready],
      "ready" => %w[in_progress],
      "in_progress" => %w[blocked completed],
      "blocked" => %w[in_progress],
      "completed" => []
    }.freeze

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def transition!(client:, intake:, task_id:, expected_state:, expected_version:,
                    to_state:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      validate_expectations!(task_id, expected_state, expected_version)
      unless TRANSITIONS.fetch(expected_state, []).include?(to_state)
        raise Denied, "Unsupported fictional task transition"
      end

      scoped.with_lock do
        check_access!(client, explicit_synthetic)
        task = scoped_task!(scoped, task_id)
        verify_version!(task, expected_state, expected_version)
        require_completed_prerequisites!(scoped, task) if %w[ready in_progress completed].include?(to_state)

        before = task.state
        task.lifecycle_actor = @actor
        task.update!(state: to_state)
        append_event!(task, kind: "transition", from_state: before,
                      from_priority: task.priority)
        receipt(task)
      end
    end

    def reprioritize!(client:, intake:, task_id:, expected_state:, expected_version:,
                      priority:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      validate_expectations!(task_id, expected_state, expected_version)
      unless SyntheticProjectTask::PRIORITIES.include?(priority)
        raise Denied, "Only numeric fictional priorities 1..5 are permitted"
      end

      scoped.with_lock do
        check_access!(client, explicit_synthetic)
        task = scoped_task!(scoped, task_id)
        verify_version!(task, expected_state, expected_version)
        if task.state == "completed" || task.priority == priority
          raise Denied, "Completed tasks and duplicate priority changes are forbidden"
        end

        previous_priority = task.priority
        task.lifecycle_actor = @actor
        task.update!(priority: priority)
        append_event!(task, kind: "priority_change", from_state: task.state,
                      from_priority: previous_priority)
        receipt(task)
      end
    end

    def history(client:, intake:, task_id:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      task = scoped_task!(scoped, task_id)
      Studio::SyntheticProjectTaskEvent.where(
        workspace_id: @workspace.id, client_id: client.id,
        project_intake_id: scoped.id, studio_synthetic_project_task_id: task.id
      ).order(:sequence).map do |event|
        {
          "sequence" => event.sequence, "event_type" => event.event_type,
          "from_state" => event.from_state, "to_state" => event.to_state,
          "from_priority" => event.from_priority, "to_priority" => event.to_priority,
          "classification" => "FICTIONAL_OWNER_ONLY_EVENT",
          "client_confirmed" => false, "task_execution_authorized" => false
        }
      end
    end

    private

    def check_access!(client, explicit_synthetic)
      @access.assert_owner!
      @access.assert_client!(client)
      unless Rails.env.test? && !Rails.env.production? && explicit_synthetic == true
        raise Denied, "Only isolated fictional task lifecycle operations are allowed"
      end
    end

    def checked_intake!(client, intake, explicit_synthetic)
      check_access!(client, explicit_synthetic)
      unless intake.is_a?(ProjectIntake) && intake.persisted?
        raise Denied, "Exact fictional project required"
      end
      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Fictional project scope not found"
    end

    def scoped_task!(scoped, id)
      unless id.is_a?(Integer) && id.positive?
        raise Denied, "Exact fictional task ID required"
      end
      Studio::SyntheticProjectTask.where(
        workspace_id: @workspace.id, client_id: scoped.client_id,
        project_intake_id: scoped.id
      ).find(id)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Task outside selected fictional project"
    end

    def validate_expectations!(task_id, expected_state, version)
      unless task_id.is_a?(Integer) && task_id.positive? &&
             TRANSITIONS.key?(expected_state) &&
             version.is_a?(Integer) && version >= 0
        raise Denied, "Exact fictional state and optimistic version required"
      end
    end

    def verify_version!(task, state, version)
      if task.state != state || task.lock_version != version
        raise Conflict, "Fictional task was updated since this version"
      end
    end

    def require_completed_prerequisites!(scoped, task)
      prerequisite_ids = Studio::SyntheticProjectTaskDependency.where(
        workspace_id: @workspace.id, client_id: scoped.client_id,
        project_intake_id: scoped.id, dependent_task_id: task.id
      ).pluck(:prerequisite_task_id)
      completed = Studio::SyntheticProjectTask.where(
        workspace_id: @workspace.id, client_id: scoped.client_id,
        project_intake_id: scoped.id, id: prerequisite_ids, state: "completed"
      ).count
      unless completed == prerequisite_ids.size
        raise Denied, "Complete every fictional prerequisite before progressing"
      end
    end

    def append_event!(task, kind:, from_state:, from_priority:)
      Studio::SyntheticProjectTaskEvent.create!(
        synthetic_project_task: task,
        workspace_id: @workspace.id, client_id: task.client_id,
        project_intake_id: task.project_intake_id,
        actor_user: @actor, lifecycle_actor: @actor,
        sequence: task.lock_version, event_type: kind,
        from_state: from_state, to_state: task.state,
        from_priority: from_priority, to_priority: task.priority,
        recorded_at: Time.current
      )
    end

    def receipt(task)
      {
        "task_id" => task.id, "task_key" => task.task_key,
        "workflow_state" => task.state, "priority" => task.priority,
        "version" => task.lock_version,
        "classification" => "FICTIONAL_OWNER_ONLY_TASK",
        "client_confirmed" => false, "task_execution_authorized" => false,
        "approved" => false, "external_calls" => 0, "billable_usd" => 0
      }
    end
  end
end
