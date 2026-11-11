require "aws-sdk-s3"

module Studio
  # Strictly READ-ONLY, bounded S3 inventory of synthetic quarantine keys.
  # Never deletes or exports object keys. Does not infer an orphan if another
  # workspace owns a key, or if the object may be an in-flight upload.
  class SourceInventoryAudit
    MAX_ITEMS = 100
    MIN_ORPHAN_AGE = 2.hours
    KEY_PATTERN = /\Aq\/[0-9a-f]{64}\z/

    def initialize(actor:, workspace:, s3_client: nil, storage: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise SecurityError, "Synthetic S3 diagnostics only" unless
        PrivateSourceStorage.enabled? && PrivateSourceStorage.s3_backend?

      # Enforce the same HTTPS/bucket/purpose gate used by actual S3 storage.
      PrivateSourceStorage.new(service: Object.new)
      @storage = storage || PrivateSourceStorage.new
      @client = s3_client || build_client
    end

    def call(limit: MAX_ITEMS)
      raise ArgumentError, "Invalid inventory limit" unless
        limit.is_a?(Integer) && limit.between?(1, MAX_ITEMS)
      @access.assert_owner!
      bucket = ENV.fetch("RC_STUDIO_S3_BUCKET")
      response = @client.list_objects_v2(bucket: bucket, prefix: "q/", max_keys: limit)
      items = Array(response.contents)
      raise SecurityError, "Provider ignored inventory bounds" if items.length > limit

      counts = {
        listed: 0, owned_by_workspace: 0, belongs_to_other_workspace: 0,
        orphan_candidates: 0, recent_unreferenced: 0,
        unverified_unreferenced: 0, invalid_keys: 0,
        scoped_metadata_checked: 0, scoped_missing_objects: 0, scoped_exists_errors: 0
      }
      valid = items.select do |object|
        if object.key.to_s.match?(KEY_PATTERN)
          counts[:listed] += 1
          true
        else
          counts[:invalid_keys] += 1
          false
        end
      end
      lookup = ProjectSourceBlob
                 .where(object_key: valid.map(&:key))
                 .pluck(:object_key, :workspace_id).to_h
      valid.each do |object|
        owner_workspace_id = lookup[object.key]
        if owner_workspace_id
          counts[owner_workspace_id == @workspace.id ? :owned_by_workspace : :belongs_to_other_workspace] += 1
        elsif !object.last_modified.respond_to?(:to_time)
          counts[:unverified_unreferenced] += 1
        elsif object.last_modified.to_time > Time.current - MIN_ORPHAN_AGE
          counts[:recent_unreferenced] += 1
        else
          counts[:orphan_candidates] += 1
        end
      end

      # Independently HEAD active DB records for this tenant. These are
      # sampled separately from the listing: no claim of full reconciliation.
      @workspace.project_source_blobs
                .where.not(scan_state: "revoked")
                .order(:id).limit(limit).pluck(:object_key).each do |key|
        @access.assert_owner!
        counts[:scoped_metadata_checked] += 1
        begin
          counts[:scoped_missing_objects] += 1 unless @storage.exists?(key: key)
        rescue StandardError
          counts[:scoped_exists_errors] += 1
        end
      end

      {
        counts: counts,
        listing_truncated: response.is_truncated != false,
        completeness: response.is_truncated == false ? "bounded_sample" : "partial",
        object_keys_exported: false,
        automatic_deletion: false,
        actual_storage_deletions: 0,
        production_ready: false
      }
    rescue StandardError => error
      # Never present transport/provider failure as a clean audit.
      raise SecurityError, "Synthetic inventory could not be verified (#{error.class})"
    end

    private

    def build_client
      Aws::S3::Client.new(
        endpoint: ENV.fetch("RC_STUDIO_S3_ENDPOINT"),
        region: ENV.fetch("RC_STUDIO_S3_REGION"),
        access_key_id: ENV.fetch("RC_STUDIO_S3_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("RC_STUDIO_S3_SECRET_ACCESS_KEY"),
        force_path_style: true, retry_limit: 0,
        http_open_timeout: 5, http_read_timeout: 8
      )
    end
  end
end
