module DomainOutbox
  # C2.3b7e: private READ-ONLY reconciliation of immutable publication audits.
  # Current ServiceOffering published_version_id is intentionally NOT used:
  # the published pointer can change after this historical event.
  # No outbox writes, replay, jobs, provider access or HTTP route.
  class PublicationBackfillDryRun
    SOURCE_TYPE = "ServiceOfferingPublication"
    KINDS = {
      "publish" => "service_published",
      "unpublish" => "service_unpublished"
    }.freeze
    MAX_PAGE_SIZE = 25
    MAX_SCAN = 250
    CURSOR_TTL = 15.minutes
    CURSOR_PURPOSE = "rc:outbox:backfill-dry-run:service-publication:v1"
    CURSOR_SALT = "rc:outbox:service-publication-dry-run:cursor:v1"

    def self.preview(owner:, limit: MAX_PAGE_SIZE, cursor: nil)
      workspace = OperatorAccess.workspace_for!(owner: owner)
      unless limit.is_a?(Integer) && limit.between?(1, MAX_PAGE_SIZE)
        raise ArgumentError, "publication dry-run limit must be an integer 1..25"
      end

      scope = ServiceOfferingPublication.joins(:service_offering)
        .left_joins(:service_offering_version)
        .where(service_offerings: { workspace_id: workspace.id })

      if cursor.nil?
        ceiling_id = scope.maximum("service_offering_publications.id") || 0
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
        "service_offering_publications.id > ? AND service_offering_publications.id <= ?",
        after_id, ceiling_id
      ).order("service_offering_publications.id ASC").limit(page_size + 1)
        .pluck(
          "service_offering_publications.id",
          "service_offering_publications.event",
          "service_offering_publications.created_at",
          "service_offering_publications.owner_user_id",
          "service_offering_publications.service_offering_id",
          "service_offering_publications.service_offering_version_id",
          "service_offering_versions.id",
          "service_offering_versions.service_offering_id",
          "service_offering_versions.approved_at"
        )
      has_more = rows.size > page_size
      rows = rows.first(page_size)
      ids = rows.map(&:first)

      envelopes = DomainOutboxEvent.where(
        workspace_id: workspace.id, source_type: SOURCE_TYPE, source_id: ids
      ).pluck(:source_id, :kind, :source_version, :occurred_at)
        .group_by(&:first)

      keys = ids.flat_map do |id|
        KINDS.values.map { |kind| event_key(id, kind) }
      end
      projections = ActivityEvent.where(
        workspace_id: workspace.id, event_key: keys
      ).pluck(:event_key, :subject_type, :subject_id, :kind, :occurred_at, :metadata)
        .index_by(&:first)

      counts = {
        already_indexed: 0, projection_only: 0, envelope_only: 0,
        missing_both: 0, inconsistent_records: 0,
        ineligible_sources: 0, unexpected_artifacts: 0
      }

      rows.each do |id, event, created_at, owner_user_id, offering_id,
                    version_id, linked_id, linked_offering_id, approved_at|
        eligible = created_at.present? && owner_user_id == workspace.owner_user_id &&
          if event == "publish"
            version_id.present? && linked_id == version_id &&
              linked_offering_id == offering_id && approved_at.present? &&
              approved_at <= created_at
          else
            event == "unpublish" && version_id.nil?
          end

        unless eligible
          counts[:ineligible_sources] += 1
          next
        end

        expected_kind = KINDS.fetch(event)
        records = envelopes.fetch(id, [])
        matching = records.select { |record| record[1] == expected_kind }
        opposite = KINDS.values.find { |kind| kind != expected_kind }
        unexpected = records.any? { |record| record[1] != expected_kind } ||
          projections.key?(event_key(id, opposite))
        counts[:unexpected_artifacts] += 1 if unexpected

        envelope = matching.size == 1 &&
          matching.first[2] == 1 &&
          matching.first[3]&.to_i == created_at.to_i

        projection = projections[event_key(id, expected_kind)]
        activity = projection &&
          projection[1] == SOURCE_TYPE &&
          projection[2] == id &&
          projection[3] == expected_kind &&
          projection[4]&.to_i == created_at.to_i &&
          projection[5].is_a?(Hash) &&
          projection[5].empty?

        if unexpected || (matching.any? && !envelope) || (projection && !activity)
          counts[:inconsistent_records] += 1
        elsif envelope
          counts[activity ? :already_indexed : :envelope_only] += 1
        else
          counts[activity ? :projection_only : :missing_both] += 1
        end
      end

      inspected = rows.size
      exhausted = has_more && scanned + inspected >= MAX_SCAN
      next_cursor = if has_more && !exhausted
        issue_cursor(owner: owner, workspace: workspace, ceiling_id: ceiling_id,
          after_id: rows.last.first, scanned: scanned + inspected)
      end
      {
        source_type: SOURCE_TYPE, inspected: inspected, **counts,
        has_more: has_more, scan_budget_exhausted: exhausted,
        next_cursor: next_cursor
      }
    end

    def self.event_key(id, kind)
      "#{SOURCE_TYPE}:#{id}:#{kind}"
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
        raise ArgumentError, "invalid publication dry-run cursor"
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
      raise ArgumentError, "invalid publication dry-run cursor" unless valid
      state
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise ArgumentError, "invalid publication dry-run cursor"
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
