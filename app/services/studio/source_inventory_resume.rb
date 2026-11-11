require "aws-sdk-s3"
require "openssl"

module Studio
  # Resumable, one-page-or-20-HEAD-at-a-time, READ ONLY local inventory.
  # An encrypted S3 continuation cursor and aggregate counters are persisted
  # in PostgreSQL. There is no auto-delete, lease, cloud worker, or scheduler.
  class SourceInventoryResume
    class Denied < StandardError; end
    MAX_PAGES = 10_000
    PAGE_SIZE = 100
    HEADS_PER_STEP = 20
    TTL = 24.hours
    MIN_ORPHAN_AGE = 2.hours
    KEY = /\Aq\/[0-9a-f]{64}\z/
    COUNTERS = %w[
      listed owned_by_workspace foreign_workspace orphan_candidates_review_only
      recent_unreferenced unknown_timestamp invalid_keys
      db_heads_checked db_missing_objects db_head_errors
    ].freeze

    def initialize(actor:, workspace:, s3_client: nil, storage: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise Denied, "Local synthetic S3 only" unless
        PrivateSourceStorage.enabled? && PrivateSourceStorage.s3_backend?
      PrivateSourceStorage.new(service: Object.new) # strict S3 configuration
      @client = s3_client || Aws::S3::Client.new(
        endpoint: ENV.fetch("RC_STUDIO_S3_ENDPOINT"),
        region: ENV.fetch("RC_STUDIO_S3_REGION"),
        access_key_id: ENV.fetch("RC_STUDIO_S3_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("RC_STUDIO_S3_SECRET_ACCESS_KEY"),
        force_path_style: true, retry_limit: 0,
        http_open_timeout: 5, http_read_timeout: 8
      )
      @storage = storage || PrivateSourceStorage.new
    end

    def begin!
      @access.assert_owner!
      checkpoint = nil
      @workspace.with_lock do
        @access.assert_owner!
        checkpoint = @workspace.studio_inventory_checkpoints
          .where(state: %w[listing checking]).first
        if checkpoint
          check_config!(checkpoint)
        else
          checkpoint = @workspace.studio_inventory_checkpoints.create!(
            state: "listing", config_digest: config_digest,
            expires_at: TTL.from_now,
            db_target_max_id: @workspace.project_source_blobs.maximum(:id).to_i,
            counts: COUNTERS.index_with { 0 }
          )
        end
      end
      checkpoint
    end

    def step!(checkpoint_id:)
      @access.assert_owner!
      checkpoint = @workspace.studio_inventory_checkpoints.find(checkpoint_id)
      checkpoint.with_lock do
        @access.assert_owner!
        check_config!(checkpoint)
        return report(checkpoint) if checkpoint.finished?

        if checkpoint.expires_at <= Time.current
          checkpoint.update!(state: "failed", finished_at: Time.current,
                             error_code: "expired", encrypted_cursor: nil)
          return report(checkpoint)
        end

        case checkpoint.state
        when "listing" then list_one_page!(checkpoint)
        when "checking" then check_one_db_batch!(checkpoint)
        else raise Denied, "Unsupported checkpoint state"
        end
        report(checkpoint)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Unknown scoped checkpoint"
    rescue StandardError, SecurityError => e
      raise Denied, "Synthetic inventory step failed (#{e.class})"
    end

    def report(checkpoint)
      @access.assert_owner!
      counts = COUNTERS.index_with { |key| checkpoint.counts.fetch(key, 0).to_i }
      {
        checkpoint_id: checkpoint.id, phase: checkpoint.state,
        pages_scanned: checkpoint.pages_scanned,
        db_last_id: checkpoint.last_db_blob_id,
        db_target_max_id: checkpoint.db_target_max_id,
        counts: counts,
        scan_complete: checkpoint.state == "completed",
        snapshot_consistent: false,
        orphan_deletion_permitted: false, deleted_objects: 0,
        raw_cursors_exported: false, raw_keys_exported: false,
        production_ready: false
      }
    end

    private

    def list_one_page!(cp)
      raise Denied, "Max S3 pages reached; no automatic reset" if cp.pages_scanned >= MAX_PAGES
      token = decrypt_cursor(cp.encrypted_cursor) if cp.encrypted_cursor.present?
      args = { bucket: ENV.fetch("RC_STUDIO_S3_BUCKET"), prefix: "q/", max_keys: PAGE_SIZE }
      args[:continuation_token] = token if token
      page = @client.list_objects_v2(**args)
      items = Array(page.contents)
      raise Denied, "Provider exceeded page size" if items.size > PAGE_SIZE
      raise Denied, "Invalid S3 truncation flag" unless [true, false].include?(page.is_truncated)

      counts = cp.counts.deep_dup
      valid = items.select do |obj|
        if obj.key.to_s.match?(KEY)
          true
        else
          counts["invalid_keys"] += 1
          false
        end
      end
      counts["listed"] += valid.length
      owners = ProjectSourceBlob.where(object_key: valid.map(&:key))
                                 .pluck(:object_key, :workspace_id).to_h
      valid.each do |obj|
        owner = owners[obj.key]
        if owner
          counts[owner == @workspace.id ? "owned_by_workspace" : "foreign_workspace"] += 1
        elsif !obj.last_modified.respond_to?(:to_time)
          counts["unknown_timestamp"] += 1
        elsif obj.last_modified.to_time < cp.created_at - MIN_ORPHAN_AGE
          counts["orphan_candidates_review_only"] += 1
        else
          counts["recent_unreferenced"] += 1
        end
      end

      seen = cp.seen_cursor_digests.dup
      if page.is_truncated
        next_token = page.next_continuation_token.to_s
        raise Denied, "Invalid continuation token" unless
          next_token.bytesize.between?(1, 2048)
        digest = cursor_digest(next_token)
        raise Denied, "Continuation token loop" if seen.include?(digest)
        seen << digest
        new_encrypted = encrypt_cursor(next_token)
      else
        new_encrypted = nil
      end
      cp.update!(counts: counts, seen_cursor_digests: seen,
                 pages_scanned: cp.pages_scanned + 1,
                 encrypted_cursor: new_encrypted,
                 state: page.is_truncated ? "listing" : "checking")
    end

    def check_one_db_batch!(cp)
      rows = @workspace.project_source_blobs
                       .where("id > ? AND id <= ?", cp.last_db_blob_id, cp.db_target_max_id)
                       .where.not(scan_state: "revoked")
                       .order(:id).limit(HEADS_PER_STEP).pluck(:id, :object_key)
      counts = cp.counts.deep_dup
      rows.each do |id, key|
        @access.assert_owner!
        counts["db_heads_checked"] += 1
        begin
          counts["db_missing_objects"] += 1 unless @storage.exists?(key: key)
        rescue StandardError
          counts["db_head_errors"] += 1
        end
      end
      last_id = rows.last&.first || cp.db_target_max_id
      # A full batch could be the final one; one more safe DB tick detects EOF.
      done = rows.length < HEADS_PER_STEP
      cp.update!(
        counts: counts, last_db_blob_id: last_id,
        state: done ? "completed" : "checking",
        finished_at: done ? Time.current : nil,
        encrypted_cursor: nil
      )
    end

    def check_config!(cp)
      raise Denied, "Storage target changed: cannot resume" unless
        ActiveSupport::SecurityUtils.secure_compare(cp.config_digest, config_digest)
    end

    def config_digest
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
        "rc036-inventory-v1|#{ENV.fetch('RC_STUDIO_S3_ENDPOINT')}|" \
        "#{ENV.fetch('RC_STUDIO_S3_BUCKET')}|#{ENV.fetch('RC_STUDIO_S3_REGION')}")
    end

    def cursor_digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
                             "rc036-inventory-cursor-v1|#{token}")
    end

    def encryptor
      key = Rails.application.key_generator.generate_key(
        "rc036-inventory-cursor-encryption-v1", 32
      )
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end

    def encrypt_cursor(token)
      encryptor.encrypt_and_sign(token, purpose: "rc036-inventory-ws-#{@workspace.id}")
    end

    def decrypt_cursor(ciphertext)
      cursor = encryptor.decrypt_and_verify(
        ciphertext, purpose: "rc036-inventory-ws-#{@workspace.id}"
      )
      raise Denied, "Invalid stored cursor" unless cursor.is_a?(String) &&
                                                     cursor.bytesize.between?(1, 2048)
      cursor
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise Denied, "Stored cursor cannot be verified"
    end
  end
end
