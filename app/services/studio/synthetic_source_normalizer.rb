require "digest"
require "json"

module Studio
  # Strictly ephemeral owner-only synthetic provenance. No persistence/AI/HTTP.
  class SyntheticSourceNormalizer
    VERSION = "rc038-normalizer.v1".freeze
    MAX_SEGMENTS = 40
    MAX_TEXT = 240
    class Denied < StandardError; end

    class StrictJsonObject < Hash
      def []=(key, value)
        raise JSON::ParserError, "Duplicate JSON key" if key?(key)
        super
      end
    end

    def initialize(actor:, workspace:)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def call(client:, intake:, source_id:, filename:, bytes:, explicit_synthetic: false)
      unless !Rails.env.production? &&
             (Rails.env.test? || (Rails.env.development? && ENV["RC_STUDIO_RC038_SYNTHETIC"] == "true")) &&
             explicit_synthetic == true
        raise Denied, "Synthetic nonproduction opt-in required"
      end
      @access.assert_client!(client)
      raise Denied, "Scoped project intake required" unless intake.is_a?(ProjectIntake) && intake.persisted?
      scoped = @workspace.project_intakes.where(client_id: client.id).find(intake.id)
      source = @workspace.project_sources.where(
        client_id: client.id, project_intake_id: scoped.id, state: "metadata_only"
      ).find(source_id)
      raise Denied, "Quarantine cannot be bypassed" if source.project_source_blob
      raise ArgumentError, "Expected in-memory String" unless bytes.is_a?(String)

      report = SourceInspector.new.call(filename: filename, bytes: bytes)
      unless source.source_sha256 == report.fetch("sha256") &&
             source.byte_size == report.fetch("bytes") &&
             source.source_format == report.fetch("format") &&
             source.parser_version == ProjectSource::PARSER_VERSION
        raise Denied, "Source mismatch"
      end

      normalized = bytes.dup.force_encoding(Encoding::UTF_8)
                        .delete_prefix("\uFEFF").gsub("\r\n", "\n")
      @segments = []
      @omitted = 0
      if source.source_format == "json"
        walk_json(JSON.parse(normalized, max_nesting: 8, allow_nan: false,
                             object_class: StrictJsonObject), "", source.source_sha256)
      else
        fenced = false
        normalized.each_line.with_index(1) do |line, number|
          value = line.strip
          if source.source_format == "markdown" && value.match?(/\A(?:\x60{3,}|~{3,})/)
            fenced = !fenced
            next
          end
          next if value.empty? || fenced
          kind, text, completed = line_kind(value, source.source_format)
          append(kind: kind, text: text, locator: "line:#{number}",
                 digest: source.source_sha256, completed: completed)
        end
      end

      facts = @segments.filter_map do |segment|
        next if segment.fetch("kind") == "heading" || segment.fetch("truncated")
        { "id" => "fact-#{segment.fetch("id").delete_prefix("seg-")}",
          "type" => segment.fetch("kind") == "task" ? "requirement_candidate" : "statement_candidate",
          "status" => segment.fetch("kind") == "json_null" ? "unknown" : "reported",
          "value" => segment.fetch("text"), "source_segment_id" => segment.fetch("id"),
          "review" => "owner_and_client_confirmation_required" }
      end
      { "schema_version" => VERSION, "classification" => "UNTRUSTED_SYNTHETIC_EPHEMERAL",
        "source_id" => source.id, "source_sha256" => source.source_sha256,
        "source_format" => source.source_format, "segments" => @segments,
        "fact_candidates" => facts,
        "provenance_edges" => facts.map { |f| { "from" => f.fetch("id"),
          "to" => f.fetch("source_segment_id"), "relation" => "reported_in" } },
        "omitted_segment_count" => @omitted,
        "coverage" => @omitted.zero? && @segments.none? { |s| s.fetch("truncated") } ? "complete" : "partial",
        "stored" => false, "provider_ready" => false, "auto_approved" => false,
        "external_calls" => 0, "billable_usd" => 0,
        "required_gates" => %w[owner_review client_confirmation privacy_release] }
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped synthetic source not found"
    rescue JSON::ParserError, JSON::NestingError
      raise ArgumentError, "Ambiguous or invalid JSON source"
    end

    private

    def line_kind(line, format)
      return ["statement", line, nil] unless format == "markdown"
      heading = line.match(/\A[#]{1,6}[ \t]+(.+)\z/)
      return ["heading", heading[1], nil] if heading
      task = line.match(/\A[-*][ \t]+\[([ xX])\][ \t]+(.+)\z/)
      return ["task", task[2], task[1].downcase == "x"] if task
      ["statement", line, nil]
    end

    def walk_json(node, pointer, digest)
      case node
      when Hash
        node.each do |key, value|
          walk_json(value, pointer + "/" + key.to_s.gsub("~", "~0").gsub("/", "~1"), digest)
        end
      when Array
        node.each_with_index { |value, index| walk_json(value, "#{pointer}/#{index}", digest) }
      else
        append(kind: node.nil? ? "json_null" : "json_scalar",
               text: node.is_a?(String) ? node : JSON.generate(node),
               locator: pointer, digest: digest, completed: nil)
      end
    end

    def append(kind:, text:, locator:, digest:, completed:)
      raise ArgumentError, "Source locator too long" if locator.length > 180
      value = text.to_s.gsub(/[\u0000-\u001F\u007F]/, " ").strip
      return if value.empty?
      if @segments.size >= MAX_SEGMENTS
        @omitted += 1
        return
      end
      fingerprint = Digest::SHA256.hexdigest([VERSION, digest, locator, kind, value].join("\u0000"))
      segment = { "id" => "seg-#{fingerprint[0, 24]}", "locator" => locator,
        "kind" => kind, "text" => value.slice(0, MAX_TEXT),
        "text_sha256" => Digest::SHA256.hexdigest(value), "source_sha256" => digest,
        "truncated" => value.length > MAX_TEXT, "trust" => "unverified_source_claim" }
      segment["done_in_source"] = completed unless completed.nil?
      @segments << segment
    end
  end
end
