# frozen_string_literal: true

require "json"

module DomainOutbox
  # C2.3b7k: pure index metadata classifier. No DB connection or mutation.
  class InvitationIndexMetadataTriage
    TARGET = "rails_calendar_r04_restore_20261121t231331z_27407"
    ROLE = "gor"
    EXPECTED_INDEX = "index_client_request_invitations_on_workspace_id_and_created_at"
    EXPECTED_KEYS = %w[workspace_id created_at].freeze
    CLASSES = %w[
      EXACT_EXPECTED_INDEX_PRESENT INDEX_ABSENT INDEX_INVALID_OR_NOT_READY
      INDEX_NAME_OR_DEFINITION_DRIFT INDEX_UNEXPECTEDLY_UNIQUE UNKNOWN
    ].freeze

    # One pg_catalog-only SELECT. No reads from application/source rows,
    # schema_migrations, token digests, private files or financial records.
    SQL = <<~SQL.freeze
      WITH target AS (
        SELECT rel.oid, rel.relkind
        FROM pg_catalog.pg_class rel
        JOIN pg_catalog.pg_namespace ns ON ns.oid = rel.relnamespace
        WHERE ns.nspname = 'public'
          AND rel.relname = 'client_request_invitations'
          AND rel.relkind IN ('r', 'p')
      )
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
        'table_present', EXISTS(SELECT 1 FROM target),
        'table_kind', (SELECT relkind::text FROM target LIMIT 1),
        'indexes', (
          SELECT coalesce(jsonb_agg(jsonb_build_object(
            'name', index_rel.relname,
            'valid', idx.indisvalid,
            'ready', idx.indisready,
            'unique', idx.indisunique,
            'method', am.amname,
            'keys', (
              SELECT coalesce(
                jsonb_agg(coalesce(att.attname, '<expression>') ORDER BY key_pos.n),
                '[]'::jsonb
              )
              FROM generate_series(0, idx.indnkeyatts - 1) AS key_pos(n)
              LEFT JOIN pg_catalog.pg_attribute att
                ON att.attrelid = idx.indrelid AND att.attnum = idx.indkey[key_pos.n]
            ),
            'included_count', idx.indnatts - idx.indnkeyatts,
            'has_predicate', idx.indpred IS NOT NULL,
            'has_expression', idx.indexprs IS NOT NULL
          ) ORDER BY index_rel.relname), '[]'::jsonb)
          FROM target
          JOIN pg_catalog.pg_index idx ON idx.indrelid = target.oid
          JOIN pg_catalog.pg_class index_rel ON index_rel.oid = idx.indexrelid
          JOIN pg_catalog.pg_am am ON am.oid = index_rel.relam
        )
      )::text;
    SQL

    def self.classify(document)
      return "UNKNOWN" unless valid_shape?(document)
      return "UNKNOWN" unless document["database"] == TARGET &&
        document["role"] == ROLE &&
        document["version_num"].between?(160000, 169999) &&
        document["socket"] == true && document["read_only"] == true &&
        document["other_sessions"] == 0 &&
        document["table_present"] == true && document["table_kind"] == "r"

      indexes = document.fetch("indexes")
      exact = indexes.find { |index| index["name"] == EXPECTED_INDEX }
      if exact
        return "INDEX_INVALID_OR_NOT_READY" unless exact["valid"] && exact["ready"]
        return "INDEX_UNEXPECTEDLY_UNIQUE" if exact["unique"]
        return "INDEX_NAME_OR_DEFINITION_DRIFT" unless expected_definition?(exact)

        "EXACT_EXPECTED_INDEX_PRESENT"
      elsif indexes.any? { |index| expected_definition?(index) && !index["unique"] }
        "INDEX_NAME_OR_DEFINITION_DRIFT"
      else
        "INDEX_ABSENT"
      end
    end

    def self.expected_definition?(index)
      index["method"] == "btree" && index["keys"] == EXPECTED_KEYS &&
        index["included_count"] == 0 && index["has_predicate"] == false &&
        index["has_expression"] == false
    end
    private_class_method :expected_definition?

    def self.valid_shape?(document)
      return false unless document.is_a?(Hash) &&
        document.keys.sort == %w[
          database indexes other_sessions read_only role socket
          table_kind table_present version_num
        ].sort
      return false unless document["database"].is_a?(String) &&
        document["role"].is_a?(String) && document["version_num"].is_a?(Integer) &&
        [true, false].include?(document["socket"]) &&
        [true, false].include?(document["read_only"]) &&
        document["other_sessions"].is_a?(Integer) && document["other_sessions"] >= 0 &&
        [true, false].include?(document["table_present"]) &&
        [nil, "r", "p"].include?(document["table_kind"])

      indexes = document["indexes"]
      return false unless indexes.is_a?(Array) && indexes.length <= 32

      indexes.all? do |index|
        index.is_a?(Hash) && index.keys.sort == %w[
          has_expression has_predicate included_count keys method
          name ready unique valid
        ].sort &&
          index["name"].is_a?(String) && index["name"].match?(/\A[a-zA-Z0-9_]{1,90}\z/) &&
          index["method"].is_a?(String) &&
          index["keys"].is_a?(Array) && index["keys"].length <= 32 &&
          index["keys"].all? { |name| name.is_a?(String) && name.match?(/\A[a-zA-Z0-9_<>]{1,90}\z/) } &&
          index["included_count"].is_a?(Integer) &&
          index["included_count"].between?(0, 32) &&
          %w[valid ready unique has_predicate has_expression].all? do |field|
            [true, false].include?(index[field])
          end
      end
    end
    private_class_method :valid_shape?
  end
end
