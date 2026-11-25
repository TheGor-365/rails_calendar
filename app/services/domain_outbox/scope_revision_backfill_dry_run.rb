module DomainOutbox
  # C2.3b7b: READ-ONLY reconciliation of immutable scope snapshots only.
  # No backfill writer, replay, provider call, HTTP route or source mutation.
  class ScopeRevisionBackfillDryRun
    SOURCE_TYPE = "IntakeScopeRevision"
    SOURCE_KIND = "scope_revision_saved"
    MAX_PAGE_SIZE = 25
    MAX_SCAN = 250
    CURSOR_TTL = 15.minutes
    CURSOR_PURPOSE = "rc:outbox:backfill-dry-run:intake-scope-revision:v1"
    CURSOR_SALT = "rc:outbox:scope-revision-dry-run:cursor:v1"

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "scope dry-run limit must be an integer 1..25"
      end

      scope = IntakeScopeRevision.joins(:project_intake)
        .where(project_intakes: { workspace_id: workspace.id })
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
      rows = scope.where("intake_scope_revisions.id > ? AND intake_scope_revisions.id <= ?",
        after_id, ceiling_id)
        .order("intake_scope_revisions.id ASC").limit(page_size + 1)
        .pluck("intake_scope_revisions.id", "intake_scope_revisions.version",
          "intake_scope_revisions.author_role", "intake_scope_revisions.created_at")
      has_more = rows.size > page_size
      rows = rows.first(page_size)
      ids = rows.map(&:first)

      envelopes = DomainOutboxEvent.where(
        workspace_id: workspace.id, source_type: SOURCE_TYPE,
        kind: SOURCE_KIND, source_id: ids
      ).pluck(:source_id, :source_version, :occurred_at)
        .group_by(&:first)

      activity_keys = ids.map { |id| "#{SOURCE_TYPE}:#{id}:#{SOURCE_KIND}" }
      projections = ActivityEvent.where(workspace_id: workspace.id, event_key: activity_keys)
        .pluck(:event_key, :subject_type, :subject_id, :kind, :occurred_at, :metadata)
        .index_by(&:first)

      counts = {
        already_indexed: 0, projection_only: 0,
        envelope_only: 0, missing_both: 0,
        inconsistent_records: 0, ineligible_sources: 0
      }

      rows.each do |id, version, author_role, created_at|
        unless version.is_a?(Integer) && version.positive? &&
            %w[owner client].include?(author_role) && created_at.present?
          counts[:ineligible_sources] += 1
          next
        end

        envelope_rows = envelopes.fetch(id, [])
        envelope = envelope_rows.size == 1 &&
          envelope_rows.first[1] == version &&
          envelope_rows.first[2]&.to_i == created_at.to_i

        projection = projections["#{SOURCE_TYPE}:#{id}:#{SOURCE_KIND}"]
        activity = projection &&
          projection[1] == SOURCE_TYPE &&
          projection[2] == id &&
          projection[3] == SOURCE_KIND &&
          projection[4]&.to_i == created_at.to_i &&
          projection[5].is_a?(Hash) &&
          projection[5]["version"] == version

        if (envelope_rows.any? && !envelope) || (projection && !activity)
          counts[:inconsistent_records] += 1
        elsif envelope
          counts[activity ? :already_indexed : :envelope_only] += 1
        else
          counts[activity ? :projection_only : :missing_both] += 1
        end
      end

      inspected = rows.size
      budget_exhausted = has_more && scanned + inspected >= MAX_SCAN
      next_cursor = if has_more && !budget_exhausted
        issue_cursor(owner: owner, workspace: workspace,
          ceiling_id: ceiling_id, after_id: rows.last.first, scanned: scanned + inspected)
      end

      {
        source_type: SOURCE_TYPE, inspected: inspected, **counts,
        has_more: has_more, scan_budget_exhausted: budget_exhausted,
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
        raise ArgumentError, "invalid scope dry-run cursor"
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
        state["ceiling_id"].positive? &&
        state["after_id"].between?(1, state["ceiling_id"]) &&
        state["scanned"].between?(1, MAX_SCAN - 1)
      raise ArgumentError, "invalid scope dry-run cursor" unless valid

      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid scope dry-run cursor"
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
