module Studio
  # Test-only owner-scoped synthetic card persistence + serialized transitions.
  # Do not expose from controllers or use with real clients in production.
  class SyntheticProjectCardWorkflow
    class Denied < StandardError; end
    class Conflict < StandardError; end
    ALLOWED = { "backlog" => %w[in_review], "in_review" => %w[backlog on_hold],
                "on_hold" => %w[backlog in_review] }.freeze

    def initialize(actor:, workspace:)
      @actor, @workspace = actor, workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def create!(client:, intake:, artifact_key:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      unless SyntheticProjectCard::ARTIFACT_KEYS.include?(artifact_key)
        raise Denied, "Unknown fictional artifact card"
      end
      scoped.with_lock do
        checked_access!(client, explicit_synthetic)
        card = SyntheticProjectCard.find_or_create_by!(
          workspace_id: @workspace.id, client_id: client.id,
          project_intake_id: scoped.id, artifact_key: artifact_key
        ) do |row|
          row.created_by = @actor
          row.state = "backlog"
        end
        receipt(card)
      end
    end

    def transition!(client:, intake:, card_id:, expected_state:, expected_version:,
                    to_state:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      unless expected_version.is_a?(Integer) && expected_version >= 0 &&
             ALLOWED.fetch(expected_state, []).include?(to_state)
        raise Denied, "Unsupported fictional state transition"
      end
      card = SyntheticProjectCard.where(
        workspace_id: @workspace.id, client_id: client.id,
        project_intake_id: scoped.id
      ).find(card_id)

      card.with_lock do
        checked_access!(client, explicit_synthetic)
        if card.state != expected_state || card.lock_version != expected_version
          raise Conflict, "Synthetic card was updated since it was viewed"
        end

        card.transition_actor = @actor
        card.update!(state: to_state)
        SyntheticProjectCardTransition.create!(
          synthetic_project_card: card,
          workspace_id: @workspace.id, client_id: client.id,
          project_intake_id: scoped.id, actor_user: @actor,
          sequence: card.lock_version, from_state: expected_state,
          to_state: to_state, recorded_at: Time.current
        )
        receipt(card)
      end
    end

    def list(client:, intake:, explicit_synthetic: false)
      scoped = checked_intake!(client, intake, explicit_synthetic)
      SyntheticProjectCard.where(
        workspace_id: @workspace.id, client_id: client.id,
        project_intake_id: scoped.id
      ).order(:artifact_key).map { |card| receipt(card) }
    end

    private

    def checked_access!(client, explicit_synthetic)
      @access.assert_owner!
      @access.assert_client!(client)
      unless Rails.env.test? && !Rails.env.production? && explicit_synthetic == true
        raise Denied, "Only isolated fictional project cards are allowed"
      end
    end

    def checked_intake!(client, intake, explicit_synthetic)
      checked_access!(client, explicit_synthetic)
      unless intake.is_a?(ProjectIntake) && intake.persisted?
        raise Denied, "Project scope required"
      end
      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped fictional project not found"
    end

    def receipt(card)
      {
        "card_id" => card.id, "artifact_key" => card.artifact_key,
        "state" => card.state, "version" => card.lock_version,
        "classification" => "SYNTHETIC_OWNER_ONLY_CARD",
        "scope_approved" => false, "client_confirmed" => false,
        "document_generation_allowed" => false, "task_delivery_approved" => false,
        "source_content_stored" => false, "external_calls" => 0, "billable_usd" => 0
      }
    end
  end
end
