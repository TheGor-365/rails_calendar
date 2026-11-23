# frozen_string_literal: true

require_relative "six_family_scratch_schema_contract"

module DomainOutbox
  # C2.3b7t: PURE STATIC G5 typed catalog expectations. No SQL or IO.
  # CHECK expressions are authored migration SQL, not guaranteed to match
  # pg_get_expr on PG16. Any discrepancy must BLOCK until reviewed.
  class SixFamilyTypedSchemaContract
    BASE = SixFamilyScratchSchemaContract
    COLUMN_SPEC = {
      "users" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "role" => { "type" => "character varying", "not_null" => true, "limit" => 20 } },
      "workspaces" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "owner_user_id" => { "type" => "bigint", "not_null" => true, "limit" => nil } },
      "project_intakes" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "status" => { "type" => "character varying", "not_null" => true, "limit" => 32 }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "intake_scope_revisions" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "project_intake_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "version" => { "type" => "integer", "not_null" => true, "limit" => nil }, "author_role" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "intake_requirement_sets" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "project_intake_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "intake_scope_revision_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "version" => { "type" => "integer", "not_null" => true, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "client_request_invitations" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "project_intake_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "claimed_by_user_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "claimed_at" => { "type" => "timestamp without time zone", "not_null" => false, "limit" => nil }, "submitted_at" => { "type" => "timestamp without time zone", "not_null" => false, "limit" => nil }, "revoked_at" => { "type" => "timestamp without time zone", "not_null" => false, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "service_offerings" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil } },
      "service_offering_versions" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "service_offering_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "approved_at" => { "type" => "timestamp without time zone", "not_null" => false, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "service_offering_publications" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "service_offering_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "service_offering_version_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "owner_user_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "event" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "owner_ai_conversations" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil } },
      "owner_ai_messages" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "owner_ai_conversation_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "ai_spend_entry_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "role" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "state" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "sequence" => { "type" => "integer", "not_null" => true, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "ai_spend_entries" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "professional_profile_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "project_intake_id" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "status" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "operation" => { "type" => "character varying", "not_null" => true, "limit" => 40 }, "charged_ticks" => { "type" => "bigint", "not_null" => false, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "resolved_at" => { "type" => "timestamp without time zone", "not_null" => false, "limit" => nil } },
      "professional_profiles" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil } },
      "domain_outbox_events" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "source_type" => { "type" => "character varying", "not_null" => true, "limit" => 48 }, "source_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "source_version" => { "type" => "integer", "not_null" => true, "limit" => nil }, "kind" => { "type" => "character varying", "not_null" => true, "limit" => 48 }, "state" => { "type" => "character varying", "not_null" => true, "limit" => 16 }, "occurred_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "updated_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "activity_events" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "workspace_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "event_key" => { "type" => "character varying", "not_null" => true, "limit" => 180 }, "subject_type" => { "type" => "character varying", "not_null" => true, "limit" => 60 }, "subject_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "kind" => { "type" => "character varying", "not_null" => true, "limit" => 48 }, "occurred_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil }, "metadata" => { "type" => "jsonb", "not_null" => true, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "active_storage_blobs" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "key" => { "type" => "character varying", "not_null" => true, "limit" => nil }, "checksum" => { "type" => "character varying", "not_null" => false, "limit" => nil }, "byte_size" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "service_name" => { "type" => "character varying", "not_null" => true, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } },
      "active_storage_attachments" => { "id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "record_type" => { "type" => "character varying", "not_null" => true, "limit" => nil }, "record_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "name" => { "type" => "character varying", "not_null" => true, "limit" => nil }, "blob_id" => { "type" => "bigint", "not_null" => true, "limit" => nil }, "created_at" => { "type" => "timestamp without time zone", "not_null" => true, "limit" => nil } }
    }.freeze

    INDEX_SPEC = {
      "workspaces" => { "index_workspaces_on_owner_user_id" => { "keys" => ["owner_user_id"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "project_intakes" => { "index_project_intakes_on_workspace_id" => { "keys" => ["workspace_id"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "intake_scope_revisions" => { "idx_intake_scope_revisions_version" => { "keys" => ["project_intake_id", "version"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "intake_requirement_sets" => { "idx_intake_requirement_sets_version" => { "keys" => ["project_intake_id", "version"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true }, "idx_intake_requirement_sets_source" => { "keys" => ["project_intake_id", "intake_scope_revision_id"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "client_request_invitations" => { "idx_on_workspace_id_created_at_2c68e09548" => { "keys" => ["workspace_id", "created_at"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "service_offerings" => { "idx_service_offerings_workspace_key" => { "keys" => ["workspace_id", "key"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "service_offering_versions" => { "idx_service_offering_versions_unique" => { "keys" => ["service_offering_id", "version"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true }, "idx_service_offering_single_draft" => { "keys" => ["service_offering_id"], "unique" => true, "predicate" => "approved_at IS NULL", "valid" => true, "ready" => true } },
      "owner_ai_conversations" => { "idx_owner_ai_conversations_recency" => { "keys" => ["workspace_id", "updated_at"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "owner_ai_messages" => { "idx_owner_ai_message_sequence" => { "keys" => ["owner_ai_conversation_id", "sequence"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "professional_profiles" => { "index_professional_profiles_on_workspace_id" => { "keys" => ["workspace_id"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "domain_outbox_events" => { "idx_domain_outbox_source_revision" => { "keys" => ["workspace_id", "source_type", "source_id", "source_version", "kind"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true }, "idx_domain_outbox_delivery_queue" => { "keys" => ["state", "next_attempt_at", "id"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "activity_events" => { "idx_activity_events_workspace_key" => { "keys" => ["workspace_id", "event_key"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true }, "idx_activity_events_workspace_subject" => { "keys" => ["workspace_id", "subject_type", "subject_id"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true }, "idx_activity_events_workspace_time" => { "keys" => ["workspace_id", "occurred_at", "id"], "unique" => false, "predicate" => nil, "valid" => true, "ready" => true } },
      "active_storage_blobs" => { "index_active_storage_blobs_on_key" => { "keys" => ["key"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } },
      "active_storage_attachments" => { "index_active_storage_attachments_uniqueness" => { "keys" => ["record_type", "record_id", "name", "blob_id"], "unique" => true, "predicate" => nil, "valid" => true, "ready" => true } }
    }.freeze

    FK_SPEC = {
      "workspaces" => { "owner_user_id" => { "target_table" => "users", "target_columns" => ["id"], "validated" => true } },
      "project_intakes" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "intake_scope_revisions" => { "project_intake_id" => { "target_table" => "project_intakes", "target_columns" => ["id"], "validated" => true } },
      "intake_requirement_sets" => { "project_intake_id" => { "target_table" => "project_intakes", "target_columns" => ["id"], "validated" => true }, "intake_scope_revision_id" => { "target_table" => "intake_scope_revisions", "target_columns" => ["id"], "validated" => true } },
      "client_request_invitations" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true }, "project_intake_id" => { "target_table" => "project_intakes", "target_columns" => ["id"], "validated" => true } },
      "service_offerings" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "service_offering_versions" => { "service_offering_id" => { "target_table" => "service_offerings", "target_columns" => ["id"], "validated" => true } },
      "service_offering_publications" => { "service_offering_id" => { "target_table" => "service_offerings", "target_columns" => ["id"], "validated" => true }, "service_offering_version_id" => { "target_table" => "service_offering_versions", "target_columns" => ["id"], "validated" => true }, "owner_user_id" => { "target_table" => "users", "target_columns" => ["id"], "validated" => true } },
      "owner_ai_conversations" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "owner_ai_messages" => { "owner_ai_conversation_id" => { "target_table" => "owner_ai_conversations", "target_columns" => ["id"], "validated" => true }, "ai_spend_entry_id" => { "target_table" => "ai_spend_entries", "target_columns" => ["id"], "validated" => true } },
      "ai_spend_entries" => { "professional_profile_id" => { "target_table" => "professional_profiles", "target_columns" => ["id"], "validated" => true } },
      "professional_profiles" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "domain_outbox_events" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "activity_events" => { "workspace_id" => { "target_table" => "workspaces", "target_columns" => ["id"], "validated" => true } },
      "active_storage_attachments" => { "blob_id" => { "target_table" => "active_storage_blobs", "target_columns" => ["id"], "validated" => true } }
    }.freeze

    CHECK_SPEC = {
      "intake_scope_revisions" => { "chk_intake_scope_version_positive" => { "source_expression" => "version > 0", "validated" => true }, "chk_intake_scope_author_role" => { "source_expression" => "author_role IN ('owner', 'client')", "validated" => true } },
      "intake_requirement_sets" => { "chk_intake_requirement_set_version" => { "source_expression" => "version > 0", "validated" => true } },
      "client_request_invitations" => { "chk_client_invite_claim_triplet" => { "source_expression" => "(claimed_at IS NULL AND claimed_by_user_id IS NULL AND project_intake_id IS NULL) OR (claimed_at IS NOT NULL AND claimed_by_user_id IS NOT NULL AND project_intake_id IS NOT NULL)", "validated" => true } },
      "service_offering_versions" => { "chk_service_offering_version_positive" => { "source_expression" => "version > 0", "validated" => true } },
      "service_offering_publications" => { "chk_service_publication_event" => { "source_expression" => "event IN ('publish', 'unpublish')", "validated" => true } },
      "owner_ai_messages" => { "chk_owner_ai_settled_requires_spend" => { "source_expression" => "(role <> 'assistant' OR state <> 'settled' OR ai_spend_entry_id IS NOT NULL)", "validated" => true }, "chk_owner_ai_message_sequence_positive" => { "source_expression" => "sequence > 0", "validated" => true } },
      "ai_spend_entries" => { "chk_ai_spend_exactly_one_subject" => { "source_expression" => "(project_intake_id IS NOT NULL) <> (professional_profile_id IS NOT NULL)", "validated" => true }, "chk_ai_spend_ticks_nonnegative" => { "source_expression" => "reserved_ticks >= 0 AND (charged_ticks IS NULL OR charged_ticks >= 0)", "validated" => true } },
      "domain_outbox_events" => { "chk_domain_outbox_source_positive" => { "source_expression" => "source_id > 0 AND source_version > 0", "validated" => true }, "chk_domain_outbox_attempts_nonnegative" => { "source_expression" => "attempts >= 0", "validated" => true }, "chk_domain_outbox_valid_state" => { "source_expression" => "state IN ('pending', 'delivered', 'failed')", "validated" => true } },
      "activity_events" => { "chk_activity_events_names" => { "source_expression" => "length(event_key) > 0 AND length(kind) > 0", "validated" => true }, "chk_activity_events_subject" => { "source_expression" => "subject_id > 0", "validated" => true } }
    }.freeze

    REQUIRED_MIGRATIONS = BASE::REQUIRED_MIGRATIONS

    def self.assess(report)
      unless report.is_a?(Hash) && report.keys.sort == %w[migration_versions tables] &&
          report["migration_versions"].is_a?(Array) && report["tables"].is_a?(Hash)
        return { status: "G5_TYPED_BLOCKED", reasons: ["invalid catalog shape"],
                 scan_approved: false, writer_approved: false }.freeze
      end
      errors = []
      (REQUIRED_MIGRATIONS - report.fetch("migration_versions")).each do |version|
        errors << "missing required migration #{version}"
      end
      COLUMN_SPEC.each do |table, columns|
        data = report.fetch("tables").fetch(table, nil)
        unless data.is_a?(Hash) && data.keys.sort == %w[checks columns foreign_keys indexes]
          errors << "missing typed catalog table #{table}"
          next
        end
        {
          "columns" => columns,
          "indexes" => INDEX_SPEC.fetch(table, {}),
          "foreign_keys" => FK_SPEC.fetch(table, {}),
          "checks" => CHECK_SPEC.fetch(table, {})
        }.each do |type, required|
          found = data.fetch(type, nil)
          unless found.is_a?(Hash)
            errors << "missing section #{table}.#{type}"
            next
          end
          required.each do |name, expected|
            # Only allowlisted *schema labels* may enter reasons; never actual
            # SQL expression, private identifier, key or database payload.
            errors << "typed mismatch #{table}.#{type}.#{name}" unless found.fetch(name, nil) == expected
          end
        end
      end
      { status: errors.empty? ? "G5_TYPED_MINIMUM_PASS" : "G5_TYPED_BLOCKED",
        reasons: errors.freeze, scan_approved: false, writer_approved: false,
        full_g5_approved: false, tenancy_verified: false }.freeze
    end
  end
end
