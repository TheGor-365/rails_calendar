# frozen_string_literal: true

require "json"
require_relative "six_family_scratch_schema_contract"

module DomainOutbox
  # C2.3b7j: fixed, metadata-only SELECT for an individually approved,
  # explicitly identified local scratch. No row content, DDL, restore, backup,
  # replay, network provider, source SELECT, SQL interpolation or write path.
  #
  # The executable operator wrapper calls psql with a pinned local PG16
  # Unix socket and default_transaction_read_only=on. This class is PURE:
  # it does not connect to a DB, launch a command or change any data.
  class SixFamilyScratchMetadataProbe
    TARGET = "rails_calendar_r04_restore_20261121t231331z_27407"
    ROLE = "gor"
    TABLES = SixFamilyScratchSchemaContract::COLUMNS.keys.freeze

    # Keep names LITERAL and allowlisted; SQL fetches only public catalog
    # structure and schema_migrations VERSION strings. No customer rows,
    # event payloads, IDs, file paths, prompts or cost records are read.
    SQL = <<~SQL.freeze
      SELECT jsonb_build_object(
        'database', current_database(),
        'role', current_user,
        'version_num', current_setting('server_version_num')::integer,
        'socket', inet_server_addr() IS NULL,
        'read_only', current_setting('transaction_read_only') = 'on',
        'other_sessions', (
          SELECT count(*) FROM pg_catalog.pg_stat_activity
          WHERE datname = current_database() AND pid <> pg_backend_pid()
        ),
        'catalog', jsonb_build_object(
          'migration_versions', (
            SELECT coalesce(jsonb_agg(version), '[]'::jsonb)
            FROM public.schema_migrations
          ),
          'tables', (
            SELECT coalesce(jsonb_object_agg(rel.relname, jsonb_build_object(
              'columns', (
                SELECT coalesce(jsonb_agg(att.attname), '[]'::jsonb)
                FROM pg_catalog.pg_attribute att
                WHERE att.attrelid = rel.oid
                  AND att.attnum > 0 AND NOT att.attisdropped
              ),
              'foreign_keys', (
                SELECT coalesce(
                  jsonb_agg(jsonb_build_array(col.attname, parent.relname)),
                  '[]'::jsonb
                )
                FROM pg_catalog.pg_constraint fk
                JOIN pg_catalog.pg_class parent ON parent.oid = fk.confrelid
                JOIN pg_catalog.pg_namespace parent_ns
                  ON parent_ns.oid = parent.relnamespace
                JOIN pg_catalog.pg_attribute col
                  ON col.attrelid = rel.oid AND col.attnum = fk.conkey[1]
                WHERE fk.conrelid = rel.oid AND fk.contype = 'f'
                  AND fk.convalidated AND cardinality(fk.conkey) = 1
                  AND parent_ns.nspname = 'public'
              ),
              'indexes', (
                SELECT coalesce(
                  jsonb_agg(jsonb_build_array(idx_rel.relname, idx.indisunique)),
                  '[]'::jsonb
                )
                FROM pg_catalog.pg_index idx
                JOIN pg_catalog.pg_class idx_rel
                  ON idx_rel.oid = idx.indexrelid
                WHERE idx.indrelid = rel.oid
                  AND idx.indisvalid AND idx.indisready
              ),
              'checks', (
                SELECT coalesce(jsonb_agg(con.conname), '[]'::jsonb)
                FROM pg_catalog.pg_constraint con
                WHERE con.conrelid = rel.oid
                  AND con.contype = 'c' AND con.convalidated
              )
            )), '{}'::jsonb)
            FROM pg_catalog.pg_class rel
            JOIN pg_catalog.pg_namespace ns ON ns.oid = rel.relnamespace
            WHERE ns.nspname = 'public' AND rel.relkind IN ('r', 'p')
              AND rel.relname IN (
                'users', 'workspaces', 'project_intakes',
                'intake_scope_revisions', 'intake_requirement_sets',
                'client_request_invitations', 'service_offerings',
                'service_offering_versions', 'service_offering_publications',
                'owner_ai_conversations', 'owner_ai_messages',
                'ai_spend_entries', 'professional_profiles',
                'domain_outbox_events', 'activity_events',
                'active_storage_blobs', 'active_storage_attachments'
              )
          )
        )
      )::text;
    SQL

    def self.assess(document)
      unless document.is_a?(Hash) &&
          document.keys.sort == %w[catalog database other_sessions read_only role socket version_num] &&
          document.fetch("other_sessions").is_a?(Integer) &&
          document.fetch("other_sessions") >= 0
        raise ArgumentError, "invalid metadata report shape"
      end

      reasons = []
      reasons << "database identity" unless document["database"] == TARGET
      reasons << "role identity" unless document["role"] == ROLE
      reasons << "PostgreSQL major" unless document["version_num"].is_a?(Integer) &&
        document["version_num"].between?(160000, 169999)
      reasons << "Unix socket" unless document["socket"] == true
      reasons << "read-only transaction" unless document["read_only"] == true
      reasons << "other DB sessions" unless document["other_sessions"] == 0

      # Shape and expected identifiers are hardcoded, so no source-row data
      # or secret-bearing values are rendered in the public status.
      reasons.concat(SixFamilyScratchSchemaContract.violations(document.fetch("catalog")))
      {
        status: reasons.empty? ? "SCHEMA_CATALOG_PASS" : "SCHEMA_CATALOG_BLOCKED",
        # Catalog-only PASS is never backup/media parity, role/ACL signoff,
        # source-row validation, owner authorization or safe replay permission.
        backup_restore_verified: false,
        media_integrity_verified: false,
        tenant_isolation_verified: false,
        scan_approved: false,
        writer_approved: false,
        production_approved: false,
        reasons: reasons.freeze
      }.freeze
    end
  end
end
