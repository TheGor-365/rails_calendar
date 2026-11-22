module DomainOutbox
  # C2.3b7d: private READ-ONLY historical invitation transition audit.
  # Does not reconstruct token digests, grant access, enqueue/replay events,
  # send notifications, or change invitations. No HTTP entrypoint.
  class InvitationTransitionBackfillDryRun
    SOURCE_TYPE = "ClientRequestInvitation"
    FIELDS = DomainOutboxEvent::INVITATION_EVENT_FIELDS
    MAX_PAGE_SIZE = 25
    MAX_SCAN = 250
    CURSOR_TTL = 15.minutes
    CURSOR_PURPOSE = "rc:outbox:backfill-dry-run:invitation-transitions:v1"
    CURSOR_SALT = "rc:outbox:invitation-transition-dry-run:cursor:v1"

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "invitation dry-run limit must be an integer 1..25"
      end

      scope = ClientRequestInvitation.left_joins(:project_intake)
        .where(client_request_invitations: { workspace_id: workspace.id })
      if cursor.nil?
        ceiling_id = scope.maximum("client_request_invitations.id") || 0
        after_id = 0
        scanned = 0
      else
        state = read_cursor!(cursor, owner: owner, workspace: workspace)
        ceiling_id = state.fetch("ceiling_id")
        after_id = state.fetch("after_id")
        scanned = state.fetch("scanned")
      end

      page_size = [limit, MAX_SCAN - scanned].min
      rows = scope.where(
        "client_request_invitations.id > ? AND client_request_invitations.id <= ?",
        after_id, ceiling_id
      ).order("client_request_invitations.id ASC").limit(page_size + 1)
        .pluck(
          "client_request_invitations.id",
          "client_request_invitations.created_at",
          "client_request_invitations.claimed_at",
          "client_request_invitations.submitted_at",
          "client_request_invitations.revoked_at",
          "client_request_invitations.claimed_by_user_id",
          "client_request_invitations.project_intake_id",
          "project_intakes.id",
          "project_intakes.workspace_id"
        )

      has_more = rows.size > page_size
      rows = rows.first(page_size)
      ids = rows.map(&:first)
      kinds = FIELDS.keys.freeze

      envelopes = DomainOutboxEvent.where(
        workspace_id: workspace.id, source_type: SOURCE_TYPE,
        source_id: ids, kind: kinds
      ).pluck(:source_id, :kind, :source_version, :occurred_at)
        .group_by { |source_id, kind, _version, _time| [source_id, kind] }

      event_keys = ids.flat_map do |id|
        kinds.map { |kind| event_key(id, kind) }
      end
      projections = ActivityEvent.where(
        workspace_id: workspace.id, event_key: event_keys
      ).pluck(
        :event_key, :subject_type, :subject_id, :kind, :occurred_at, :metadata
      ).index_by(&:first)

      totals = {
        already_indexed: 0, projection_only: 0, envelope_only: 0,
        missing_both: 0, inconsistent_records: 0,
        ineligible_invitations: 0, unexpected_artifacts: 0
      }
      expected_transitions = 0

      rows.each do |id, created_at, claimed_at, submitted_at, revoked_at,
                    claimant_id, intake_id, joined_intake_id, intake_workspace_id|
        if invalid_source?(workspace: workspace, created_at: created_at,
                           claimed_at: claimed_at, submitted_at: submitted_at,
                           revoked_at: revoked_at, claimant_id: claimant_id,
                           intake_id: intake_id, joined_intake_id: joined_intake_id,
                           intake_workspace_id: intake_workspace_id)
          totals[:ineligible_invitations] += 1
          next
        end

        timestamps = {
          "invitation_issued" => created_at,
          "invitation_claimed" => claimed_at,
          "invitation_submitted" => submitted_at,
          "invitation_revoked" => revoked_at
        }

        FIELDS.each do |kind, (version, _timestamp_field)|
          entry_rows = envelopes.fetch([id, kind], [])
          projection = projections[event_key(id, kind)]
          occurred_at = timestamps.fetch(kind)

          # A null timestamp means NO canonical transition. Any projection
          # or envelope for it is anomalous, not an item to backfill.
          if occurred_at.nil?
            totals[:unexpected_artifacts] += 1 if entry_rows.any? || projection
            next
          end

          expected_transitions += 1
          envelope = entry_rows.size == 1 &&
            entry_rows.first[2] == version &&
            entry_rows.first[3]&.to_i == occurred_at.to_i
          activity = projection &&
            projection[1] == SOURCE_TYPE && projection[2] == id &&
            projection[3] == kind &&
            projection[4]&.to_i == occurred_at.to_i &&
            projection[5] == {}

          if (entry_rows.any? && !envelope) || (projection && !activity)
            totals[:inconsistent_records] += 1
          elsif envelope
            totals[activity ? :already_indexed : :envelope_only] += 1
          else
            totals[activity ? :projection_only : :missing_both] += 1
          end
        end
      end

      inspected = rows.size
      exhausted = has_more && scanned + inspected >= MAX_SCAN
      next_cursor = if has_more && !exhausted
        issue_cursor(owner: owner, workspace: workspace, ceiling_id: ceiling_id,
          after_id: rows.last.first, scanned: scanned + inspected)
      end

      {
        source_type: SOURCE_TYPE, inspected_invitations: inspected,
        expected_transitions: expected_transitions, **totals,
        has_more: has_more, scan_budget_exhausted: exhausted,
        next_cursor: next_cursor
      }
    end

    def self.invalid_source?(workspace:, created_at:, claimed_at:, submitted_at:,
                             revoked_at:, claimant_id:, intake_id:, joined_intake_id:,
                             intake_workspace_id:)
      return true unless created_at.present?
      triplet = claimed_at.present? == claimant_id.present? &&
        claimed_at.present? == intake_id.present?
      return true unless triplet
      if claimed_at.present?
        return true unless joined_intake_id == intake_id &&
          intake_workspace_id == workspace.id
        return true if claimed_at < created_at
      end
      return true if submitted_at.present? &&
        (claimed_at.nil? || submitted_at < claimed_at)
      return true if revoked_at.present? &&
        (revoked_at < created_at || claimed_at.present? || submitted_at.present?)
      false
    end
    private_class_method :invalid_source?

    def self.event_key(source_id, kind)
      "#{SOURCE_TYPE}:#{source_id}:#{kind}"
    end
    private_class_method :event_key

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
        raise ArgumentError, "invalid invitation dry-run cursor"
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
      raise ArgumentError, "invalid invitation dry-run cursor" unless valid
      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid invitation dry-run cursor"
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
