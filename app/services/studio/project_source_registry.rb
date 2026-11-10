module Studio
  # Owner-only, synthetic-source metadata ledger. This does NOT store file
  # bytes, original filenames, text segments, provider context or blob URLs.
  # Private object storage, scan/quarantine, retention and identity verification
  # remain release gates; no download or client access is possible here.
  class ProjectSourceRegistry
    def initialize(actor:, workspace:)
      @actor = actor
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def register_preview!(client:, intake:, report:)
      scoped_intake = checked_intake!(client: client, intake: intake)
      validate_report!(report)

      @workspace.project_sources.find_or_create_by!(
        client: client, project_intake: scoped_intake,
        source_sha256: report.fetch("sha256"),
        parser_version: ProjectSource::PARSER_VERSION
      ) do |record|
        record.recorded_by = @actor
        record.byte_size = report.fetch("bytes")
        record.source_format = report.fetch("format")
        record.state = "metadata_only"
      end
    end

    def list!(client:, intake:)
      scoped_intake = checked_intake!(client: client, intake: intake)
      @workspace.project_sources.where(client: client, project_intake: scoped_intake)
                .order(created_at: :desc, id: :desc)
    end

    def find!(client:, intake:, id:)
      list!(client: client, intake: intake).find(id)
    end

    def download!(client:, intake:, id:)
      find!(client: client, intake: intake, id: id)
      raise SecurityError, "Source bytes are not stored or cleared for download"
    end

    private

    def checked_intake!(client:, intake:)
      @access.assert_client!(client)
      raise SecurityError, "Invalid project intake" unless intake.is_a?(ProjectIntake) && intake.persisted?

      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
    end

    def validate_report!(report)
      unless report.is_a?(Hash) &&
             report["classification"] == "UNTRUSTED_OWNER_PREVIEW_NOT_PERSISTED" &&
             report["stored"] == false && report["provider_ready"] == false &&
             ProjectSource::FORMATS.include?(report["format"]) &&
             report["sha256"].is_a?(String) && report["sha256"].match?(/\A[0-9a-f]{64}\z/) &&
             report["bytes"].is_a?(Integer) &&
             report["bytes"].between?(1, SourceInspector::MAX_BYTES)
        raise ArgumentError, "Expected a validated, synthetic, non-persisted source preview"
      end
    end
  end
end
