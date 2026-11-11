require "digest"
require "json"

module Studio
  # RC-039 Slice A: a fictional, read-only Project Hub board contract.
  # It maps the existing closed document-planning prerequisites onto cards,
  # rather than persisting real work items or making scope decisions.
  class SyntheticProjectHubBoardPreview
    VERSION = "rc039-synthetic-project-board.v1".freeze
    class Denied < StandardError; end

    LANES = [
      { key: "discovery", label: "Discovery", artifacts: %w[discovery_brief clarification_questions] },
      { key: "definition", label: "Definition", artifacts: %w[requirements_spec architecture qa_plan] },
      { key: "planning", label: "Planning", artifacts: %w[full_roadmap financial_scenarios pitch_deck] },
      { key: "handoff", label: "Handoff", artifacts: %w[handoff_bundle] }
    ].freeze

    def initialize(actor:, workspace:)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def call(client:, intake:, explicit_synthetic: false)
      @access.assert_owner!
      @access.assert_client!(client)
      # Intentionally test-only. There is no development or production board
      # exposure while consent, identity and project permissions are pending.
      unless Rails.env.test? && !Rails.env.production? && explicit_synthetic == true
        raise Denied, "Test-only fictional Project Hub preview required"
      end
      unless intake.is_a?(ProjectIntake) && intake.persisted?
        raise Denied, "Scoped fictional project required"
      end
      project = @workspace.project_intakes.where(client_id: client.id).find(intake.id)

      # Never infer client confirmation, approved scope or legitimate source
      # evidence from project metadata or earlier synthetic review receipts.
      planned = DocumentGenerationPlan.new.call(evidence: {}).fetch("artifacts")
      expected = LANES.flat_map { |lane| lane.fetch(:artifacts) }
      unless planned.map { |item| item.fetch("key") }.sort == expected.sort &&
             planned.all? { |item| item.fetch("status") == "blocked" }
        raise Denied, "Board cannot bypass document generation prerequisites"
      end

      lane_by_key = LANES.each_with_object({}) do |lane, map|
        lane.fetch(:artifacts).each { |key| map[key] = lane.fetch(:key) }
      end
      cards = planned.map do |item|
        key = item.fetch("key")
        {
          "key" => key,
          "lane_key" => lane_by_key.fetch(key),
          "status" => "blocked_unverified",
          "generation_status" => "blocked",
          "prerequisites" => item.fetch("missing_evidence"),
          "requires_owner_review" => true,
          "requires_client_confirmation" => true,
          "assignments_verified" => false,
          "timeline_scheduled" => false,
          "artifact_created" => false
        }
      end
      edges = cards.flat_map do |card|
        card.fetch("prerequisites").map do |required|
          { "from_evidence" => required, "to_card" => card.fetch("key"),
            "relationship" => "unmet_prerequisite" }
        end
      end
      {
        "schema_version" => VERSION,
        "classification" => "FICTIONAL_READ_ONLY_PROJECT_HUB",
        "board_id" => "board-#{Digest::SHA256.hexdigest(
          JSON.generate([VERSION, @workspace.id, client.id, project.id])
        ).first(24)}",
        "lanes" => LANES.map do |lane|
          { "key" => lane.fetch(:key), "label" => lane.fetch(:label),
            "card_keys" => lane.fetch(:artifacts) }
        end,
        "cards" => cards,
        "dependency_edges" => edges,
        "card_count" => cards.length,
        "blocked_card_count" => cards.length,
        "project_calendar" => { "independent_of_consultations" => true,
                                 "scheduled_items" => [], "writes_allowed" => false },
        "drag_and_drop_allowed" => false,
        "client_access_allowed" => false,
        "scope_approved" => false,
        "client_confirmed" => false,
        "document_generation_allowed" => false,
        "automatic_task_transitions" => false,
        "persisted" => false,
        "source_content_stored" => false,
        "external_calls" => 0,
        "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release]
      }
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped fictional project not found"
    end
  end
end
