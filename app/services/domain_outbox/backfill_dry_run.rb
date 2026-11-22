require "set"

module DomainOutbox
  # C2.3b7a: bounded, private, READ-ONLY legacy source-to-envelope audit.
  # This FIRST slice scans ProjectIntake only. Other source/version mappings
  # require independent review before scanning/backfilling them.
  # No enqueue, projection, replay, provider call or public route.
  class BackfillDryRun
    SOURCE_TYPE = "ProjectIntake"
    SOURCE_KIND = "intake_created"
    MAX_PAGE_SIZE = 25
    MAX_SCAN = 250
    CURSOR_TTL = 15.minutes
    CURSOR_PURPOSE = "rc:outbox:backfill-dry-run:project-intake:v1"
    CURSOR_SALT = "rc:outbox:backfill-dry-run:cursor:v1"

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "dry-run page size must be 1..25"
      end

      scope = ProjectIntake.where(workspace_id: workspace.id)
      if cursor.nil?
        ceiling_id = scope.maximum(:id) || 0
        after_id = 0
        scanned = 0
      else
        state = read_cursor!(cursor, owner: owner, workspace: workspace)
        ceiling_id = state.fetch("ceiling_id")
        after_id = state.fetch("after_id")
        scanned = state.fetch("scanned")
      end

      page_size = [limit, MAX_SCAN - scanned].min
      ids = scope.where("id > ? AND id <= ?", after_id, ceiling_id)
        .order(:id).limit(page_size + 1).pluck(:id)
      has_more = ids.length > page_size
      ids = ids.first(page_size)

      envelopes = DomainOutboxEvent.where(
        workspace_id: workspace.id, source_type: SOURCE_TYPE,
        source_version: 1, kind: SOURCE_KIND, source_id: ids
      ).pluck(:source_id).to_set

      keys = ids.map { |id| "#{SOURCE_TYPE}:#{id}:#{SOURCE_KIND}" }
      projected = ActivityEvent.where(workspace_id: workspace.id, event_key: keys)
        .pluck(:event_key).to_set

      counts = {
        already_indexed: 0, projection_only: 0,
        envelope_only: 0, missing_both: 0
      }
      ids.each do |id|
        envelope = envelopes.include?(id)
        activity = projected.include?("#{SOURCE_TYPE}:#{id}:#{SOURCE_KIND}")
        category = if envelope
          activity ? :already_indexed : :envelope_only
        else
          activity ? :projection_only : :missing_both
        end
        counts[category] += 1
      end

      budget_exhausted = has_more && scanned + ids.length >= MAX_SCAN
      next_cursor = if has_more && !budget_exhausted
        issue_cursor(owner: owner, workspace: workspace,
          ceiling_id: ceiling_id, after_id: ids.last,
          scanned: scanned + ids.length)
      end

      {
        source_type: SOURCE_TYPE,
        inspected: ids.length,
        **counts,
        has_more: has_more,
        scan_budget_exhausted: budget_exhausted,
        next_cursor: next_cursor
      }
    end

    def self.issue_cursor(owner:, workspace:, ceiling_id:, after_id:, scanned:)
      encryptor.encrypt_and_sign(
        {
          "owner_user_id" => owner.id, "workspace_id" => workspace.id,
          "source_type" => SOURCE_TYPE, "ceiling_id" => ceiling_id,
          "after_id" => after_id, "scanned" => scanned
        },
        purpose: CURSOR_PURPOSE, expires_in: CURSOR_TTL
      )
    end
    private_class_method :issue_cursor

    def self.read_cursor!(cursor, owner:, workspace:)
      unless cursor.is_a?(String) && cursor.bytesize.between?(1, 2048)
        raise ArgumentError, "invalid dry-run cursor"
      end

      state = encryptor.decrypt_and_verify(cursor, purpose: CURSOR_PURPOSE)
      valid = state.is_a?(Hash) &&
        state.keys.sort == %w[after_id ceiling_id owner_user_id scanned source_type workspace_id] &&
        state["owner_user_id"] == owner.id &&
        state["workspace_id"] == workspace.id &&
        state["source_type"] == SOURCE_TYPE &&
        state["ceiling_id"].is_a?(Integer) &&
        state["after_id"].is_a?(Integer) &&
        state["scanned"].is_a?(Integer) &&
        state["ceiling_id"] > 0 &&
        state["after_id"].between?(1, state["ceiling_id"]) &&
        state["scanned"].between?(1, MAX_SCAN - 1)
      raise ArgumentError, "invalid dry-run cursor" unless valid

      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid dry-run cursor"
    end
    private_class_method :read_cursor!

    def self.encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(
        Rails.application.key_generator.generate_key(
          CURSOR_SALT, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm")
        ),
        cipher: "aes-256-gcm"
      )
    end
    private_class_method :encryptor
  end
end
