# frozen_string_literal: true

require "json"

module DomainOutbox
  # C2.3b7s: fixed SQL + pure validation, no connection or application boot.
  # Future owner-local read requires its own explicit one-shot authorization.
  class ActiveStorageReferenceProbe
    SOURCE = "rails_calendar_rc0551f_c21b_review_20261117"
    SCRATCH = "rails_calendar_r04_restore_20261121t231331z_27407"
    ROLE = "gor"
    TABLES = %w[active_storage_blobs active_storage_attachments active_storage_variant_records].freeze
    KEYS = %w[blob_count attachment_count variant_count orphan_attachments orphan_variants blank_blob_keys nonlocal_blobs].freeze

    IDENTITY_SQL = <<~SQL.freeze
      SELECT jsonb_build_object(
        'database', current_database(),
        'role', current_user,
        'version_num', current_setting('server_version_num')::integer,
        'socket', inet_server_addr() IS NULL,
        'read_only', current_setting('transaction_read_only') = 'on',
        'other_sessions', (
          SELECT COUNT(*) FROM pg_catalog.pg_stat_activity
          WHERE datname = current_database() AND pid <> pg_backend_pid()
        ),
        'tables', jsonb_build_object(
          'active_storage_blobs', to_regclass('public.active_storage_blobs') IS NOT NULL,
          'active_storage_attachments', to_regclass('public.active_storage_attachments') IS NOT NULL,
          'active_storage_variant_records', to_regclass('public.active_storage_variant_records') IS NOT NULL
        )
      )::text;
    SQL

    # Each subquery is a count (no row text or IDs returned), fixed tables.
    # This inspects application-row presence and links. It is NOT a catalog-only
    # query and must not be executed using consumed C2.3b7n authorization.
    AGGREGATE_SQL = <<~SQL.freeze
      SELECT jsonb_build_object(
        'blob_count', (SELECT COUNT(*) FROM public.active_storage_blobs),
        'attachment_count', (SELECT COUNT(*) FROM public.active_storage_attachments),
        'variant_count', (SELECT COUNT(*) FROM public.active_storage_variant_records),
        'orphan_attachments', (
          SELECT COUNT(*) FROM public.active_storage_attachments a
          LEFT JOIN public.active_storage_blobs b ON b.id = a.blob_id
          WHERE b.id IS NULL
        ),
        'orphan_variants', (
          SELECT COUNT(*) FROM public.active_storage_variant_records v
          LEFT JOIN public.active_storage_blobs b ON b.id = v.blob_id
          WHERE b.id IS NULL
        ),
        'blank_blob_keys', (
          SELECT COUNT(*) FROM public.active_storage_blobs
          WHERE key IS NULL OR key = ''
        ),
        'nonlocal_blobs', (
          SELECT COUNT(*) FROM public.active_storage_blobs
          WHERE service_name IS DISTINCT FROM 'local'
        )
      )::text;
    SQL

    def self.validate_identity!(doc, expected:)
      raise ArgumentError, "metadata shape" unless doc.is_a?(Hash) &&
        doc.keys.sort == %w[database other_sessions read_only role socket tables version_num]
      raise ArgumentError, "database identity" unless [SOURCE, SCRATCH].include?(expected) &&
        doc.fetch("database") == expected
      raise ArgumentError, "pg16 identity" unless doc.fetch("version_num").is_a?(Integer) &&
        doc.fetch("version_num").between?(160000, 169999)
      raise ArgumentError, "role/socket/readonly" unless doc.fetch("role") == ROLE &&
        doc.fetch("socket") == true && doc.fetch("read_only") == true
      raise ArgumentError, "other sessions observed" unless doc.fetch("other_sessions") == 0
      tables = doc.fetch("tables")
      raise ArgumentError, "relation existence" unless tables.is_a?(Hash) &&
        tables.keys.sort == TABLES.sort && tables.values.all? { |value| value == true }
      true
    end

    def self.validate_aggregate!(doc)
      raise ArgumentError, "aggregate shape" unless doc.is_a?(Hash) &&
        doc.keys.sort == KEYS.sort &&
        doc.values.all? { |n| n.is_a?(Integer) && n >= 0 && n <= 1_000_000 }
      raise ArgumentError, "implausible attachment count" if doc.fetch("orphan_attachments") > doc.fetch("attachment_count")
      raise ArgumentError, "implausible variant count" if doc.fetch("orphan_variants") > doc.fetch("variant_count")
      raise ArgumentError, "implausible blob anomaly count" if doc.fetch("blank_blob_keys") > doc.fetch("blob_count") ||
        doc.fetch("nonlocal_blobs") > doc.fetch("blob_count")
      doc
    end

    def self.assess(source:, scratch:)
      a = validate_aggregate!(source)
      b = validate_aggregate!(scratch)
      equal = KEYS.all? { |key| a.fetch(key) == b.fetch(key) }
      orphans = a.fetch("orphan_attachments") + a.fetch("orphan_variants") +
        b.fetch("orphan_attachments") + b.fetch("orphan_variants")
      # Both databases may agree on *unexpected* non-local services.
      # Equal counts do not make a DiskService snapshot recoverable.
      anomalies = orphans +
        a.fetch("blank_blob_keys") + b.fetch("blank_blob_keys") +
        a.fetch("nonlocal_blobs") + b.fetch("nonlocal_blobs")
      {
        status: equal && anomalies.zero? ? "AGGREGATE_PARITY" : "DELTA_REVIEW",
        orphan_blob_references: orphans.zero? ? "ZERO" : "PRESENT",
        # Matching aggregate counts cannot establish key sets or file contents.
        media_file_reference_parity_proved: false,
        polymorphic_record_links_proved: false,
        tenant_isolation_proved: false,
        writer_quiescence_proved: false,
        replay_authorized: false,
        production_authorized: false
      }.freeze
    end
  end
end
