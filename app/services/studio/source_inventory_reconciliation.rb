require "aws-sdk-s3"

module Studio
  # Non-mutating, tenant-scoped, *paginated* quarantine audit. Returns totals
  # only and NEVER a key. Does not authorize deleting "orphan candidates".
  class SourceInventoryReconciliation
    KEY = /\Aq\/[0-9a-f]{64}\z/
    MIN_AGE = 2.hours
    PAGE_SIZE = 100
    MAX_PAGES = 25
    MAX_DB_HEADS = 2_500

    def initialize(actor:, workspace:, s3_client: nil, storage: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise SecurityError, "Synthetic S3 only" unless
        PrivateSourceStorage.enabled? && PrivateSourceStorage.s3_backend?
      PrivateSourceStorage.new(service: Object.new) # validate endpoint/purpose
      @storage = storage || PrivateSourceStorage.new
      @client = s3_client || Aws::S3::Client.new(
        endpoint: ENV.fetch("RC_STUDIO_S3_ENDPOINT"),
        region: ENV.fetch("RC_STUDIO_S3_REGION"),
        access_key_id: ENV.fetch("RC_STUDIO_S3_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("RC_STUDIO_S3_SECRET_ACCESS_KEY"),
        force_path_style: true, retry_limit: 0, http_open_timeout: 5, http_read_timeout: 8
      )
    end

    def call(max_pages: MAX_PAGES, max_db_heads: MAX_DB_HEADS)
      unless max_pages.is_a?(Integer) && max_pages.between?(1, MAX_PAGES) &&
             max_db_heads.is_a?(Integer) && max_db_heads.between?(1, MAX_DB_HEADS)
        raise ArgumentError, "Unsafe inventory limits"
      end
      @access.assert_owner!
      now = Time.current
      counts = {
        listed: 0, owned_by_workspace: 0, foreign_workspace: 0,
        orphan_candidates_review_only: 0, recent_unreferenced: 0,
        unknown_timestamp: 0, invalid_keys: 0,
        db_active_total: 0, db_heads_checked: 0, db_missing_objects: 0,
        db_head_errors: 0
      }
      token = nil
      used_tokens = {}
      pages = 0
      list_complete = false

      max_pages.times do
        @access.assert_owner!
        args = { bucket: ENV.fetch("RC_STUDIO_S3_BUCKET"), prefix: "q/",
                 max_keys: PAGE_SIZE }
        args[:continuation_token] = token if token
        page = @client.list_objects_v2(**args)
        objects = Array(page.contents)
        raise SecurityError, "Provider exceeded page size" if objects.length > PAGE_SIZE
        pages += 1
        valid = objects.select do |obj|
          if obj.key.to_s.match?(KEY)
            true
          else
            counts[:invalid_keys] += 1
            false
          end
        end
        counts[:listed] += valid.length
        owners = ProjectSourceBlob.where(object_key: valid.map(&:key))
                                  .pluck(:object_key, :workspace_id).to_h
        valid.each do |object|
          owning_workspace = owners[object.key]
          if owning_workspace
            name = owning_workspace == @workspace.id ? :owned_by_workspace : :foreign_workspace
            counts[name] += 1
          elsif !object.last_modified.respond_to?(:to_time)
            counts[:unknown_timestamp] += 1
          elsif object.last_modified.to_time < now - MIN_AGE
            counts[:orphan_candidates_review_only] += 1
          else
            counts[:recent_unreferenced] += 1
          end
        end
        if page.is_truncated == false
          list_complete = true
          break
        end

        new_token = page.next_continuation_token.to_s
        if new_token.empty? || new_token.bytesize > 2048 || used_tokens[new_token]
          raise SecurityError, "Provider pagination cursor invalid"
        end
        used_tokens[new_token] = true
        token = new_token
      end

      active = @workspace.project_source_blobs.where.not(scan_state: "revoked")
      counts[:db_active_total] = active.count
      active.order(:id).limit(max_db_heads).pluck(:object_key).each do |key|
        @access.assert_owner!
        counts[:db_heads_checked] += 1
        begin
          counts[:db_missing_objects] += 1 unless @storage.exists?(key: key)
        rescue StandardError
          counts[:db_head_errors] += 1
        end
      end
      db_complete = counts[:db_heads_checked] == counts[:db_active_total]
      {
        counts: counts,
        pages: pages,
        list_complete: list_complete,
        db_complete: db_complete,
        reconciliation_complete: list_complete && db_complete &&
                                 counts[:db_head_errors].zero?,
        snapshot_consistent: false,
        orphan_deletion_permitted: false,
        deleted_objects: 0,
        object_keys_exported: false,
        production_ready: false
      }
    rescue StandardError, SecurityError => error
      raise SecurityError, "S3 reconciliation failed closed (#{error.class})"
    end
  end
end
