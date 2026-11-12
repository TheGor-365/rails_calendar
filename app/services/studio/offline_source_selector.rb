module Studio
  # Explicit synthetic metadata-only source selection. Zero byte downloads,
  # no cross-project context, AI embeddings or external retrieval.
  class OfflineSourceSelector
    class Denied < StandardError; end
    MAX_SELECTED = 10

    def initialize(actor:, workspace:, intake:)
      @workspace, @intake = workspace, intake
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             intake.workspace_id == workspace.id && intake.client_id.present? &&
             workspace.project_intakes.where(id: intake.id, client_id: intake.client_id).exists?
        raise Denied, "Invalid scoped project"
      end
    end

    def select!(source_ids:)
      @access.assert_owner!
      unless source_ids.is_a?(Array) && source_ids.size <= MAX_SELECTED &&
             source_ids.all? { |id| id.is_a?(Integer) && id.positive? } &&
             source_ids.uniq.size == source_ids.size
        raise Denied, "Invalid explicit source selection"
      end
      return [] if source_ids.empty?

      rows = @workspace.project_sources.where(
        id: source_ids, project_intake_id: @intake.id, client_id: @intake.client_id,
        state: "metadata_only"
      ).order(:id).pluck(:id, :source_sha256, :source_format, :byte_size)
      raise Denied, "Source is not authorized for this project" unless rows.size == source_ids.size

      # Only minimal metadata, never filename, bytes, title or source content.
      rows.map do |id, digest, format, bytes|
        { source_id: id, sha256: digest, format: format, bytes: bytes }
      end
    end
  end
end
