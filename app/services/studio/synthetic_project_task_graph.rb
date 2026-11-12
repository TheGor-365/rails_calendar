module Studio
  # RC-039 F: test-only metadata DAG of proposed engineering steps.
  # The project intake row lock serializes all edge writes in this service;
  # there are no HTTP routes, client grants, due dates, tasks from client text,
  # AI requests, calendar events, completion or production admission.
  class SyntheticProjectTaskGraph
    class Denied < StandardError; end

    PHASE_BY_TASK = {
      "scope_review" => "discovery",
      "solution_design" => "definition",
      "rails_implementation" => "implementation",
      "interface_implementation" => "implementation",
      "quality_verification" => "verification",
      "handoff_preparation" => "handoff"
    }.freeze

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def create_task!(client:, intake:, task_key:, explicit_synthetic: false)
      scoped = scoped_intake!(client, intake, explicit_synthetic)
      raise Denied, "Unknown fictional roadmap step" unless PHASE_BY_TASK.key?(task_key)

      scoped.with_lock do
        check_access!(client, explicit_synthetic)
        task = tasks(scoped).find_or_create_by!(task_key: task_key) do |row|
          row.created_by = @actor
        end
        task_receipt(task)
      end
    end

    def add_dependency!(client:, intake:, dependent_task_id:,
                        prerequisite_task_id:, explicit_synthetic: false)
      scoped = scoped_intake!(client, intake, explicit_synthetic)
      unless [dependent_task_id, prerequisite_task_id].all? { |id|
        id.is_a?(Integer) && id.positive?
      } && dependent_task_id != prerequisite_task_id
        raise Denied, "Distinct scoped fictional tasks required"
      end

      scoped.with_lock do
        check_access!(client, explicit_synthetic)
        dependent = tasks(scoped).find(dependent_task_id)
        prerequisite = tasks(scoped).find(prerequisite_task_id)
        edges = dependencies(scoped).to_a

        existing = edges.find { |edge|
          edge.dependent_task_id == dependent.id &&
            edge.prerequisite_task_id == prerequisite.id
        }
        return edge_receipt(existing, dependent, prerequisite) if existing

        if reaches_prerequisite?(prerequisite.id, dependent.id, edges)
          raise Denied, "Cycle in fictional dependency graph"
        end

        edge = dependencies(scoped).create!(
          dependent_task: dependent, prerequisite_task: prerequisite,
          created_by: @actor
        ) { |row| row.graph_actor = @actor }
        edge_receipt(edge, dependent, prerequisite)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Only tasks from the same fictional project are allowed"
    end

    def snapshot(client:, intake:, explicit_synthetic: false)
      scoped = scoped_intake!(client, intake, explicit_synthetic)
      nodes = tasks(scoped).order(:task_key).to_a
      links = dependencies(scoped).order(:dependent_task_id, :prerequisite_task_id).to_a
      topological_ids = topological_order!(nodes, links)
      by_id = nodes.index_by(&:id)

      {
        "schema_version" => "rc039-synthetic-task-dag.v1",
        "classification" => "FICTIONAL_OWNER_ONLY_ROADMAP",
        "tasks" => nodes.map { |task| task_receipt(task) },
        "dependencies" => links.map { |link|
          edge_receipt(link, by_id.fetch(link.dependent_task_id),
                       by_id.fetch(link.prerequisite_task_id))
        },
        "topological_task_keys" => topological_ids.map { |id|
          by_id.fetch(id).task_key
        },
        "task_count" => nodes.length,
        "dependency_count" => links.length,
        "cyclic_dependencies_allowed" => false,
        "critical_path_verified" => false,
        "scheduled_items" => [],
        "project_calendar_independent" => true,
        "owner_proposed_only" => true,
        "client_confirmed" => false,
        "task_execution_authorized" => false,
        "document_generation_allowed" => false,
        "source_content_stored" => false,
        "external_calls" => 0,
        "billable_usd" => 0
      }
    end

    private

    def check_access!(client, explicit_synthetic)
      @access.assert_owner!
      @access.assert_client!(client)
      unless Rails.env.test? && !Rails.env.production? && explicit_synthetic == true
        raise Denied, "Test-only fictional project task graph required"
      end
    end

    def scoped_intake!(client, intake, explicit_synthetic)
      check_access!(client, explicit_synthetic)
      unless intake.is_a?(ProjectIntake) && intake.persisted?
        raise Denied, "Scoped fictional intake required"
      end
      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Fictional project scope not found"
    end

    def tasks(scoped)
      Studio::SyntheticProjectTask.where(
        workspace_id: @workspace.id, client_id: scoped.client_id,
        project_intake_id: scoped.id
      )
    end

    def dependencies(scoped)
      Studio::SyntheticProjectTaskDependency.where(
        workspace_id: @workspace.id, client_id: scoped.client_id,
        project_intake_id: scoped.id
      )
    end

    def reaches_prerequisite?(start_id, target_id, edges)
      graph = edges.group_by(&:dependent_task_id)
      visited = {}
      pending = [start_id]
      until pending.empty?
        current = pending.pop
        return true if current == target_id
        next if visited[current]

        visited[current] = true
        graph.fetch(current, []).each { |edge| pending << edge.prerequisite_task_id }
      end
      false
    end

    def topological_order!(nodes, links)
      indegree = nodes.index_with { 0 }.transform_keys(&:id)
      followers = Hash.new { |hash, id| hash[id] = [] }
      links.each do |edge|
        indegree[edge.dependent_task_id] += 1
        followers[edge.prerequisite_task_id] << edge.dependent_task_id
      end
      name_by_id = nodes.to_h { |task| [task.id, task.task_key] }
      ready = nodes.select { |task| indegree.fetch(task.id).zero? }.map(&:id)
      ordered = []
      until ready.empty?
        ready.sort_by! { |id| name_by_id.fetch(id) }
        id = ready.shift
        ordered << id
        followers[id].each do |dependent_id|
          indegree[dependent_id] -= 1
          ready << dependent_id if indegree[dependent_id].zero?
        end
      end
      raise Denied, "Fictional dependency graph failed integrity check" if ordered.length != nodes.length

      ordered
    end

    def task_receipt(task)
      {
        "task_id" => task.id,
        "task_key" => task.task_key,
        "phase" => PHASE_BY_TASK.fetch(task.task_key),
        "state" => "proposed_unverified",
        "assigned_user_id" => nil,
        "due_on" => nil,
        "approved" => false,
        "client_confirmed" => false
      }
    end

    def edge_receipt(edge, dependent, prerequisite)
      {
        "dependency_id" => edge.id,
        "dependent_task_key" => dependent.task_key,
        "prerequisite_task_key" => prerequisite.task_key,
        "state" => "proposed_unverified"
      }
    end
  end
end
