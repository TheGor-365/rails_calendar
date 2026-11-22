require "digest"

module DomainOutbox
  # C2.3b7g: explicit operator-driven, metadata-only traversal of the six
  # independently reviewed dry-runs. One family/page per call; NO writes,
  # scheduled job, replay, HTTP endpoint, provider call or automatic retry.
  class CrossFamilyBackfillDryRun
    FAMILIES = [
      [BackfillDryRun, "ProjectIntake", "project_intakes"],
      [ScopeRevisionBackfillDryRun, "IntakeScopeRevision", "intake_scope_revisions"],
      [RequirementSetBackfillDryRun, "IntakeRequirementSet", "intake_requirement_sets"],
      [InvitationTransitionBackfillDryRun, "ClientRequestInvitation", "client_request_invitations"],
      [PublicationBackfillDryRun, "ServiceOfferingPublication", "service_offering_publications"],
      [SettledAiReplyBackfillDryRun, "OwnerAiMessage", "owner_ai_messages"]
    ].freeze

    # Only IDs, structural lineage, state/version and timestamps. Never select
    # goal, body, seed, answers, token_digest, financial result/usage or title.
    FIELDS = {
      "ProjectIntake" => %w[project_intakes.id project_intakes.workspace_id project_intakes.status
        project_intakes.created_at project_intakes.updated_at],
      "IntakeScopeRevision" => %w[intake_scope_revisions.id intake_scope_revisions.project_intake_id
        intake_scope_revisions.version intake_scope_revisions.author_role
        intake_scope_revisions.created_at intake_scope_revisions.updated_at project_intakes.workspace_id],
      "IntakeRequirementSet" => %w[intake_requirement_sets.id intake_requirement_sets.project_intake_id
        intake_requirement_sets.intake_scope_revision_id intake_requirement_sets.version
        intake_requirement_sets.created_at intake_requirement_sets.updated_at
        intake_scope_revisions.id intake_scope_revisions.project_intake_id
        intake_scope_revisions.version intake_scope_revisions.created_at],
      "ClientRequestInvitation" => %w[client_request_invitations.id client_request_invitations.workspace_id
        client_request_invitations.created_at client_request_invitations.updated_at
        client_request_invitations.claimed_at client_request_invitations.submitted_at
        client_request_invitations.revoked_at client_request_invitations.claimed_by_user_id
        client_request_invitations.project_intake_id project_intakes.id project_intakes.workspace_id],
      "ServiceOfferingPublication" => %w[service_offering_publications.id
        service_offering_publications.event service_offering_publications.owner_user_id
        service_offering_publications.service_offering_id
        service_offering_publications.service_offering_version_id
        service_offering_publications.created_at service_offering_publications.updated_at
        service_offering_versions.id service_offering_versions.service_offering_id
        service_offering_versions.approved_at service_offerings.workspace_id],
      "OwnerAiMessage" => %w[owner_ai_messages.id owner_ai_messages.owner_ai_conversation_id
        owner_ai_messages.role owner_ai_messages.state owner_ai_messages.sequence
        owner_ai_messages.ai_spend_entry_id owner_ai_messages.created_at owner_ai_messages.updated_at
        ai_spend_entries.id ai_spend_entries.status ai_spend_entries.operation
        ai_spend_entries.professional_profile_id ai_spend_entries.project_intake_id
        ai_spend_entries.charged_ticks ai_spend_entries.created_at ai_spend_entries.updated_at
        ai_spend_entries.resolved_at professional_profiles.workspace_id
        owner_ai_conversations.workspace_id]
    }.transform_values(&:freeze).freeze

    MAX_PAGE_SIZE = 25
    MAX_FAMILY_SCAN = 250
    CURSOR_TTL = 15.minutes
    MIN_PACE_SECONDS = 2
    CURSOR_PURPOSE = "rc:outbox:cross-family-dry-run:v1"
    CURSOR_SALT = "rc:outbox:cross-family-dry-run:key:v1"
    COUNT_KEYS = %w[already_indexed projection_only envelope_only missing_both
      inconsistent_records ineligible_sources unexpected_artifacts
      manual_review_required expected_transitions].freeze

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "cross-family dry-run limit must be 1..25"
      end

      state = cursor.nil? ? initial_state : read_cursor!(cursor, owner: owner, workspace: workspace)
      if cursor
        unless Time.current.to_f - state.fetch("issued_at") >= MIN_PACE_SECONDS
          raise ArgumentError, "cross-family dry-run continuation is rate limited"
        end
        guard = state["guard"]
        if guard && fingerprint(workspace: workspace, index: guard.fetch("index"),
                                last_id: guard.fetch("last_id"), count: guard.fetch("count")) != guard.fetch("digest")
          raise ArgumentError, "source or projection changed between pages; manual review required"
        end
      end

      index = state.fetch("index")
      klass, source_type, table = FAMILIES.fetch(index)
      family_cursor = state.fetch("family_cursor")
      before = family_cursor && klass.send(:read_cursor!, family_cursor, owner: owner, workspace: workspace)
      after_id = before ? before.fetch("after_id") : 0
      ceiling_id = before && before.fetch("ceiling_id")

      page = klass.preview(owner: owner, limit: limit, cursor: family_cursor)
      # Invitations count source invitations AND their expected transitions.
      # The other five services expose :inspected directly.
      inspected = source_type == "ClientRequestInvitation" ?
        page.fetch(:inspected_invitations) : page.fetch(:inspected)
      unless inspected.is_a?(Integer) && inspected.between?(0, limit)
        raise ArgumentError, "invalid source-family inspection result"
      end
      # Confirm the actual bounded source prefix selected by the child.
      next_child = page.fetch(:next_cursor)
      next_child_state = next_child && klass.send(:read_cursor!, next_child, owner: owner, workspace: workspace)
      ceiling_id ||= next_child_state && next_child_state.fetch("ceiling_id")
      scope = source_scope(workspace: workspace, source_type: source_type)
      id_column = scope.klass.arel_table[:id]
      window = scope.where(id_column.gt(after_id))
      window = window.where(id_column.lteq(ceiling_id)) if ceiling_id
      ids = window.order(id_column.asc)
        .limit(inspected).pluck(id_column)
      if ids.length != inspected ||
         (next_child_state && ids.last != next_child_state.fetch("after_id"))
        raise ArgumentError, "source page changed during inspection; manual review required"
      end

      totals = state.fetch("totals")
      family_total = totals.fetch(index)
      family_total["inspected"] += inspected
      COUNT_KEYS.each { |key| family_total[key] += page.fetch(key.to_sym, 0) }
      family_total["budget_exhausted"] ||= page.fetch(:scan_budget_exhausted)

      last_id = ids.last || after_id
      guard = {
        "index" => index, "last_id" => last_id,
        "count" => family_total.fetch("inspected"),
        "digest" => fingerprint(workspace: workspace, index: index,
          last_id: last_id, count: family_total.fetch("inspected"))
      }
      next_index = next_child ? index : index + 1
      finished = next_index == FAMILIES.length
      next_cursor = unless finished
        issue_cursor(owner: owner, workspace: workspace,
          state: {
            "index" => next_index, "family_cursor" => next_child,
            "totals" => totals, "guard" => guard,
            "started_at" => state.fetch("started_at"), "issued_at" => Time.current.to_f
          })
      end

      {
        source_type: source_type, family_number: index + 1,
        inspected: inspected,
        page_counts: COUNT_KEYS.to_h { |key| [key.to_sym, page.fetch(key.to_sym, 0)] },
        has_more_in_family: page.fetch(:has_more),
        family_budget_exhausted: page.fetch(:scan_budget_exhausted),
        completed: finished, min_resume_seconds: MIN_PACE_SECONDS,
        report: totals.each_with_index.map do |numbers, i|
          { source_type: FAMILIES.fetch(i)[1], **numbers.transform_keys(&:to_sym) }
        end,
        next_cursor: next_cursor
      }
    end

    def self.initial_state
      {
        "index" => 0, "family_cursor" => nil, "guard" => nil,
        "totals" => FAMILIES.map do
          { "inspected" => 0, "budget_exhausted" => false,
            **COUNT_KEYS.to_h { |key| [key, 0] } }
        end,
        "started_at" => Time.current.to_f, "issued_at" => Time.current.to_f
      }
    end
    private_class_method :initial_state

    def self.source_scope(workspace:, source_type:)
      case source_type
      when "ProjectIntake"
        ProjectIntake.where(workspace_id: workspace.id)
      when "IntakeScopeRevision"
        IntakeScopeRevision.joins(:project_intake)
          .where(project_intakes: { workspace_id: workspace.id })
      when "IntakeRequirementSet"
        IntakeRequirementSet.joins(:project_intake).left_joins(:intake_scope_revision)
          .where(project_intakes: { workspace_id: workspace.id })
      when "ClientRequestInvitation"
        ClientRequestInvitation.left_joins(:project_intake)
          .where(client_request_invitations: { workspace_id: workspace.id })
      when "ServiceOfferingPublication"
        ServiceOfferingPublication.joins(:service_offering)
          .left_joins(:service_offering_version)
          .where(service_offerings: { workspace_id: workspace.id })
      when "OwnerAiMessage"
        OwnerAiMessage.joins(:owner_ai_conversation)
          .left_joins(ai_spend_entry: :professional_profile)
          .where(owner_ai_conversations: { workspace_id: workspace.id })
      end
    end
    private_class_method :source_scope

    def self.fingerprint(workspace:, index:, last_id:, count:)
      _, source_type, table = FAMILIES.fetch(index)
      scope = source_scope(workspace: workspace, source_type: source_type)
      id_column = scope.klass.arel_table[:id]
      rows = scope.where(id_column.lteq(last_id))
        .order(id_column.asc)
        .limit(MAX_FAMILY_SCAN + 1).pluck(*FIELDS.fetch(source_type))
      raise ArgumentError, "source population changed; manual review required" unless rows.length == count

      ids = rows.map(&:first)
      envelopes = []
      activities = []
      if ids.any?
        envelopes = DomainOutboxEvent.where(workspace_id: workspace.id,
          source_type: source_type, source_id: ids)
          .order(:id).pluck(:id, :source_id, :source_version,
            :kind, :occurred_at, :state, :updated_at)
        kinds = Array(DomainOutboxEvent::SOURCES.fetch(source_type))
        keys = ids.flat_map { |id| kinds.map { |kind| "#{source_type}:#{id}:#{kind}" } }
        activities = ActivityEvent.where(workspace_id: workspace.id)
          .where("event_key IN (?) OR (subject_type = ? AND subject_id IN (?))",
            keys, source_type, ids)
          .order(:id).pluck(:id, :event_key, :subject_type, :subject_id,
            :kind, :occurred_at, :metadata, :created_at)
      end
      Digest::SHA256.hexdigest(Marshal.dump([rows, envelopes, activities]))
    end
    private_class_method :fingerprint

    def self.issue_cursor(owner:, workspace:, state:)
      encryptor.encrypt_and_sign(
        state.merge("owner_user_id" => owner.id, "workspace_id" => workspace.id),
        purpose: CURSOR_PURPOSE, expires_in: CURSOR_TTL
      )
    end
    private_class_method :issue_cursor

    def self.read_cursor!(cursor, owner:, workspace:)
      unless cursor.is_a?(String) && cursor.bytesize.between?(1, 16384)
        raise ArgumentError, "invalid cross-family dry-run cursor"
      end
      state = encryptor.decrypt_and_verify(cursor, purpose: CURSOR_PURPOSE)
      valid = state.is_a?(Hash) &&
        state.keys.sort == %w[family_cursor guard index issued_at owner_user_id
          started_at totals workspace_id].sort &&
        state["owner_user_id"] == owner.id && state["workspace_id"] == workspace.id &&
        state["index"].is_a?(Integer) && state["index"].between?(0, FAMILIES.length - 1) &&
        (state["family_cursor"].nil? || state["family_cursor"].is_a?(String)) &&
        state["totals"].is_a?(Array) && state["totals"].length == FAMILIES.length &&
        state["totals"].all? { |item| item.is_a?(Hash) &&
          item["inspected"].is_a?(Integer) && item["inspected"].between?(0, MAX_FAMILY_SCAN) } &&
        state["started_at"].is_a?(Numeric) && state["issued_at"].is_a?(Numeric) &&
        state["started_at"] <= state["issued_at"] &&
        Time.current.to_f >= state["issued_at"] &&
        Time.current.to_f - state["started_at"] <= CURSOR_TTL.to_i
      guard = state["guard"] if valid
      valid &&= guard.nil? || (guard.is_a?(Hash) &&
        guard.keys.sort == %w[count digest index last_id] &&
        guard["index"].is_a?(Integer) && guard["index"].between?(0, FAMILIES.length - 1) &&
        guard["last_id"].is_a?(Integer) && guard["last_id"] >= 0 &&
        guard["count"].is_a?(Integer) && guard["count"].between?(0, MAX_FAMILY_SCAN) &&
        guard["digest"].is_a?(String) && guard["digest"].match?(/\A[0-9a-f]{64}\z/))
      raise ArgumentError, "invalid cross-family dry-run cursor" unless valid

      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid cross-family dry-run cursor"
    end
    private_class_method :read_cursor!

    def self.encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(
        Rails.application.key_generator.generate_key(
          CURSOR_SALT, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm")
        ), cipher: "aes-256-gcm"
      )
    end
    private_class_method :encryptor
  end
end
