module DomainOutbox
  # C2.3b7f: private, metadata-only historical reconciliation of settled AI
  # replies. Never uses the mutable message updated_at as a settlement timestamp.
  # No backfill, database writes, provider requests, jobs or HTTP endpoint.
  class SettledAiReplyBackfillDryRun
    SOURCE_TYPE = "OwnerAiMessage"
    KIND = "ai_reply_saved"
    MAX_PAGE_SIZE = 25
    MAX_SCAN = 250
    CURSOR_TTL = 15.minutes
    CURSOR_PURPOSE = "rc:outbox:backfill-dry-run:settled-ai-reply:v1"
    CURSOR_SALT = "rc:outbox:settled-ai-reply-dry-run:cursor:v1"

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "AI reply dry-run limit must be an integer 1..25"
      end

      # Include non-settled/owner messages as ineligible sources, rather than
      # silently considering all messages to be historical billable replies.
      # SELECT only relational IDs, state/version and accounting/time metadata.
      # Never load body, prompts, result, usage, digest or provider identifiers.
      scope = OwnerAiMessage.joins(:owner_ai_conversation)
        .left_joins(ai_spend_entry: :professional_profile)
        .where(owner_ai_conversations: { workspace_id: workspace.id })

      if cursor.nil?
        ceiling_id = scope.maximum("owner_ai_messages.id") || 0
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
        "owner_ai_messages.id > ? AND owner_ai_messages.id <= ?",
        after_id, ceiling_id
      ).order("owner_ai_messages.id ASC").limit(page_size + 1)
        .pluck(
          "owner_ai_messages.id",
          "owner_ai_messages.role",
          "owner_ai_messages.state",
          "owner_ai_messages.sequence",
          "owner_ai_messages.created_at",
          "owner_ai_messages.updated_at",
          "owner_ai_messages.ai_spend_entry_id",
          "ai_spend_entries.id",
          "ai_spend_entries.status",
          "ai_spend_entries.operation",
          "ai_spend_entries.project_intake_id",
          "ai_spend_entries.professional_profile_id",
          "ai_spend_entries.charged_ticks",
          "ai_spend_entries.created_at",
          "ai_spend_entries.resolved_at",
          "professional_profiles.workspace_id"
        )
      has_more = rows.size > page_size
      rows = rows.first(page_size)
      ids = rows.map(&:first)

      envelopes = DomainOutboxEvent.where(
        workspace_id: workspace.id, source_type: SOURCE_TYPE, source_id: ids
      ).pluck(:source_id, :kind, :source_version, :occurred_at)
        .group_by(&:first)

      keys = ids.map { |id| event_key(id) }
      activities = ActivityEvent.where(workspace_id: workspace.id)
        .where(
          "event_key IN (?) OR (subject_type = ? AND subject_id IN (?))",
          keys, SOURCE_TYPE, ids
        )
        .pluck(:event_key, :subject_type, :subject_id, :kind, :occurred_at, :metadata)
      activities_by_key = activities.index_by(&:first)
      activities_by_subject = activities.select { |row| row[1] == SOURCE_TYPE }
        .group_by { |row| row[2] }

      counts = {
        already_indexed: 0, projection_only: 0, envelope_only: 0,
        missing_both: 0, inconsistent_records: 0,
        ineligible_sources: 0, unexpected_artifacts: 0,
        manual_review_required: 0
      }

      rows.each do |id, role, status, sequence, created_at, updated_at,
                    ledger_id, joined_ledger_id, ledger_status, operation,
                    project_intake_id, profile_id, charged_ticks,
                    ledger_created_at, resolved_at, profile_workspace_id|
        eligible = role == "assistant" && status == "settled" &&
          sequence.is_a?(Integer) && sequence.positive? &&
          created_at.present? && updated_at.present? &&
          ledger_id.present? && joined_ledger_id == ledger_id &&
          ledger_status == "settled" &&
          [OwnerAi::Composer::VERSION, OwnerAi::ConversationResponder::VERSION].include?(operation) &&
          project_intake_id.nil? && profile_id.present? &&
          profile_workspace_id == workspace.id &&
          charged_ticks.is_a?(Integer) && charged_ticks >= 0 &&
          ledger_created_at.present? &&
          (resolved_at.nil? || resolved_at >= ledger_created_at)

        unless eligible
          counts[:ineligible_sources] += 1
          next
        end

        key = event_key(id)
        records = envelopes.fetch(id, [])
        matching = records.select { |row| row[1] == KIND }
        activity = activities_by_key[key]
        unexpected = records.any? { |row| row[1] != KIND } ||
          activities_by_subject.fetch(id, []).any? { |row| row[0] != key || row[3] != KIND }
        counts[:unexpected_artifacts] += 1 if unexpected

        # The original timestamp is stored in each surviving projection.
        # The current message updated_at may be LATER following a body edit.
        envelope_time = matching.first[3] if matching.size == 1
        envelope_valid = matching.size == 1 && matching.first[2] == sequence &&
          acceptable_time?(envelope_time, created_at, updated_at,
            ledger_created_at, resolved_at)

        activity_time = activity && activity[4]
        activity_valid = activity &&
          activity[1] == SOURCE_TYPE && activity[2] == id &&
          activity[3] == KIND &&
          activity[5].is_a?(Hash) && activity[5].empty? &&
          acceptable_time?(activity_time, created_at, updated_at,
            ledger_created_at, resolved_at)

        # With two saved historical times, require agreement; never compare
        # equality with the mutable current updated_at. A single remaining
        # valid timestamp can be reported, but is NOT approval to write.
        time_conflict = envelope_valid && activity_valid &&
          envelope_time.to_i != activity_time.to_i

        if unexpected || (matching.any? && !envelope_valid) ||
           (activity && !activity_valid) || time_conflict
          counts[:inconsistent_records] += 1
          counts[:manual_review_required] += 1
        elsif envelope_valid
          counts[activity_valid ? :already_indexed : :envelope_only] += 1
        elsif activity_valid
          counts[:projection_only] += 1
        else
          # No immutable settlement timestamp remains. Even if updated_at
          # happens to equal the original value, that is not provable.
          counts[:missing_both] += 1
          counts[:manual_review_required] += 1
        end
      end

      inspected = rows.size
      exhausted = has_more && scanned + inspected >= MAX_SCAN
      next_cursor = if has_more && !exhausted
        issue_cursor(owner: owner, workspace: workspace,
          ceiling_id: ceiling_id, after_id: rows.last.first,
          scanned: scanned + inspected)
      end

      {
        source_type: SOURCE_TYPE, inspected: inspected, **counts,
        has_more: has_more, scan_budget_exhausted: exhausted,
        next_cursor: next_cursor
      }
    end

    def self.acceptable_time?(time, source_created_at, source_updated_at,
                              ledger_created_at, resolved_at)
      time.present? &&
        time >= source_created_at && time <= source_updated_at &&
        time >= ledger_created_at && (resolved_at.nil? || time >= resolved_at)
    end
    private_class_method :acceptable_time?

    def self.event_key(id)
      "#{SOURCE_TYPE}:#{id}:#{KIND}"
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
        raise ArgumentError, "invalid AI reply dry-run cursor"
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
      raise ArgumentError, "invalid AI reply dry-run cursor" unless valid
      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid AI reply dry-run cursor"
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
