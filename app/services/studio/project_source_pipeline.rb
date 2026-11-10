require "digest"
require "securerandom"

module Studio
  # Owner-only synthetic vertical slice: isolated quarantine -> explicit AV
  # verdict -> tenant-scoped attachment. Not enabled for production clients.
  class ProjectSourcePipeline
    class Denied < StandardError; end
    RETENTION = 7.days
    MIME = { "markdown" => "text/markdown", "text" => "text/plain", "json" => "application/json" }.freeze
    EXT = { "markdown" => ".md", "text" => ".txt", "json" => ".json" }.freeze

    def initialize(actor:, workspace:, storage: nil, scanner: nil)
      @actor = actor
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      @registry = ProjectSourceRegistry.new(actor: actor, workspace: workspace)
      @storage = storage || PrivateSourceStorage.new
      @scanner = scanner || ClamAvScanner.new
    end

    def stage!(client:, intake:, filename:, bytes:, declared_mime: nil)
      @access.assert_client!(client)
      raw = bytes.to_s.b
      report = SourceInspector.new.call(filename: filename, bytes: raw)
      expected = MIME.fetch(report.fetch("format"))
      if declared_mime.present? && ![expected, "application/octet-stream"].include?(declared_mime)
        raise ArgumentError, "Source MIME does not match the file extension"
      end
      if raw.start_with?("%PDF-", "PK\x03\x04".b, "MZ".b, "\x7fELF".b)
        raise ArgumentError, "Executable or archive signatures are not permitted"
      end

      source = @registry.register_preview!(client: client, intake: intake, report: report)
      raise ArgumentError, "Source is already quarantined" if source.project_source_blob

      key = "q/#{SecureRandom.hex(32)}"
      @storage.upload!(key: key, bytes: raw)
      begin
        source.create_project_source_blob!(
          workspace: @workspace, client: client, project_intake: intake,
          object_key: key, scan_state: "quarantined",
          expires_at: RETENTION.from_now
        )
      rescue StandardError
        @storage.delete!(key: key)
        raise
      end
      source
    end

    def scan!(client:, intake:, source_id:)
      source = @registry.find!(client: client, intake: intake, id: source_id)
      blob = source.project_source_blob
      raise Denied, "Source is not staged" unless blob && %w[quarantined failed].include?(blob.scan_state)
      raise Denied, "Quarantine expired" unless blob.expires_at > Time.current

      begin
        raw = @storage.read!(key: blob.object_key)
        raise Denied, "Quarantined bytes have changed" unless digest_matches?(source, raw)
        verdict = @scanner.scan!(raw)
        unless verdict.respond_to?(:state) && %w[clean infected].include?(verdict.state) &&
               verdict.engine.to_s.match?(/\A[a-zA-Z0-9._-]{1,80}\z/)
          raise Denied, "Scanner returned an unsupported verdict"
        end

        blob.update!(scan_state: verdict.state, scanned_at: Time.current,
                     scan_sha256: Digest::SHA256.hexdigest(raw), scanner_engine: verdict.engine)
      rescue StandardError => error
        blob.update!(scan_state: "failed", scanned_at: nil, scanner_engine: nil, scan_sha256: nil) if blob.reload.scan_state != "failed"
        raise Denied, "Source scanning could not be verified (#{error.class})"
      end
      blob
    end

    def download!(client:, intake:, source_id:)
      source = @registry.find!(client: client, intake: intake, id: source_id)
      blob = source.project_source_blob
      raise Denied, "Source is not scan-cleared" unless blob&.downloadable?

      @access.assert_client!(client) # recheck membership immediately before byte access
      raw = @storage.read!(key: blob.object_key)
      unless digest_matches?(source, raw)
        blob.update!(scan_state: "revoked")
        raise Denied, "Stored content integrity failed"
      end
      { bytes: raw, mime: MIME.fetch(source.source_format), extension: EXT.fetch(source.source_format) }
    rescue PrivateSourceStorage::MissingObject
      raise Denied, "Private object missing"
    end

    private

    def digest_matches?(source, raw)
      raw.bytesize == source.byte_size && Digest::SHA256.hexdigest(raw) == source.source_sha256
    end
  end
end
