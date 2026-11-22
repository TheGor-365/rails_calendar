# frozen_string_literal: true

module DomainOutbox
  # C2.3b7i: static minimum PostgreSQL *catalog* contract for the six historical
  # read-only scanners. Pure data and pure comparison: NO connection, IO, SQL,
  # dump/restore, migration, execution permission or customer data access.
  #
  # A passing catalog check is ONLY structural compatibility. An operator
  # must independently attest source/scratch identity, backup+media parity,
  # privacy, schema_migrations and application runtime before any scan.
  class SixFamilyScratchSchemaContract
    FAMILIES = {
      "ProjectIntake" => %w[project_intakes],
      "IntakeScopeRevision" => %w[intake_scope_revisions project_intakes],
      "IntakeRequirementSet" => %w[intake_requirement_sets project_intakes intake_scope_revisions],
      "ClientRequestInvitation" => %w[client_request_invitations project_intakes],
      "ServiceOfferingPublication" => %w[service_offering_publications service_offerings service_offering_versions workspaces],
      "OwnerAiMessage" => %w[owner_ai_messages owner_ai_conversations ai_spend_entries professional_profiles]
    }.freeze

    # Required per scanner's pluck, left/inner join, page cursor, prefix guard
    # or operator authorization; *not* every column in each business table.
    COLUMNS = {
      "users" => %w[id role],
      "workspaces" => %w[id owner_user_id],
      "project_intakes" => %w[id workspace_id status created_at updated_at],
      "intake_scope_revisions" => %w[id project_intake_id version author_role created_at updated_at],
      "intake_requirement_sets" => %w[id project_intake_id intake_scope_revision_id version created_at updated_at],
      "client_request_invitations" => %w[id workspace_id project_intake_id claimed_by_user_id
        claimed_at submitted_at revoked_at created_at updated_at],
      "service_offerings" => %w[id workspace_id],
      "service_offering_versions" => %w[id service_offering_id approved_at created_at],
      "service_offering_publications" => %w[id service_offering_id service_offering_version_id
        owner_user_id event created_at updated_at],
      "owner_ai_conversations" => %w[id workspace_id],
      "owner_ai_messages" => %w[id owner_ai_conversation_id ai_spend_entry_id role state sequence
        created_at updated_at],
      "ai_spend_entries" => %w[id professional_profile_id project_intake_id status operation charged_ticks
        created_at updated_at resolved_at],
      "professional_profiles" => %w[id workspace_id],
      "domain_outbox_events" => %w[id workspace_id source_type source_id source_version
        kind state occurred_at updated_at],
      "activity_events" => %w[id workspace_id event_key subject_type subject_id
        kind occurred_at metadata created_at],
      # Recovery gate ONLY: backup must include private media, not just SQL.
      "active_storage_blobs" => %w[id key checksum byte_size service_name created_at],
      "active_storage_attachments" => %w[id record_type record_id name blob_id created_at]
    }.transform_values(&:freeze).freeze

    # Required relational links; this does NOT prove all legacy row lineage.
    FOREIGN_KEYS = {
      "workspaces" => { "owner_user_id" => "users" },
      "project_intakes" => { "workspace_id" => "workspaces" },
      "intake_scope_revisions" => { "project_intake_id" => "project_intakes" },
      "intake_requirement_sets" => {
        "project_intake_id" => "project_intakes",
        "intake_scope_revision_id" => "intake_scope_revisions"
      },
      "client_request_invitations" => {
        "workspace_id" => "workspaces", "project_intake_id" => "project_intakes"
      },
      "service_offerings" => { "workspace_id" => "workspaces" },
      "service_offering_versions" => { "service_offering_id" => "service_offerings" },
      "service_offering_publications" => {
        "service_offering_id" => "service_offerings",
        "service_offering_version_id" => "service_offering_versions",
        "owner_user_id" => "users"
      },
      "owner_ai_conversations" => { "workspace_id" => "workspaces" },
      "owner_ai_messages" => {
        "owner_ai_conversation_id" => "owner_ai_conversations",
        "ai_spend_entry_id" => "ai_spend_entries"
      },
      "ai_spend_entries" => { "professional_profile_id" => "professional_profiles" },
      "professional_profiles" => { "workspace_id" => "workspaces" },
      "domain_outbox_events" => { "workspace_id" => "workspaces" },
      "activity_events" => { "workspace_id" => "workspaces" },
      "active_storage_attachments" => { "blob_id" => "active_storage_blobs" }
    }.freeze

    # Named identity/index constraints that matter for versioning,
    # idempotency, source tenancy and deterministic projections.
    # Expected uniqueness is explicit, not inferred merely from index name.
    INDEXES = {
      "workspaces" => { "index_workspaces_on_owner_user_id" => true },
      "project_intakes" => { "index_project_intakes_on_workspace_id" => false },
      "intake_scope_revisions" => { "idx_intake_scope_revisions_version" => true },
      "intake_requirement_sets" => {
        "idx_intake_requirement_sets_version" => true,
        "idx_intake_requirement_sets_source" => true
      },
      "client_request_invitations" => {
        "index_client_request_invitations_on_workspace_id_and_created_at" => false
      },
      "service_offerings" => { "idx_service_offerings_workspace_key" => true },
      "service_offering_versions" => { "idx_service_offering_versions_unique" => true },
      "owner_ai_conversations" => { "idx_owner_ai_conversations_recency" => false },
      "owner_ai_messages" => { "idx_owner_ai_message_sequence" => true },
      "professional_profiles" => { "index_professional_profiles_on_workspace_id" => true },
      "domain_outbox_events" => {
        "idx_domain_outbox_source_revision" => true,
        "idx_domain_outbox_delivery_queue" => false
      },
      "activity_events" => {
        "idx_activity_events_workspace_key" => true,
        "idx_activity_events_workspace_subject" => false,
        "idx_activity_events_workspace_time" => false
      },
      "active_storage_blobs" => { "index_active_storage_blobs_on_key" => true },
      "active_storage_attachments" => {
        "index_active_storage_attachments_uniqueness" => true
      }
    }.freeze

    CHECKS = {
      "intake_scope_revisions" => %w[chk_intake_scope_version_positive chk_intake_scope_author_role],
      "intake_requirement_sets" => %w[chk_intake_requirement_set_version],
      "client_request_invitations" => %w[chk_client_invite_claim_triplet],
      "service_offering_versions" => %w[chk_service_offering_version_positive],
      "service_offering_publications" => %w[chk_service_publication_event],
      "owner_ai_messages" => %w[chk_owner_ai_settled_requires_spend chk_owner_ai_message_sequence_positive],
      "ai_spend_entries" => %w[chk_ai_spend_exactly_one_subject chk_ai_spend_ticks_nonnegative],
      "domain_outbox_events" => %w[
        chk_domain_outbox_source_positive chk_domain_outbox_attempts_nonnegative
        chk_domain_outbox_valid_state
      ],
      "activity_events" => %w[chk_activity_events_names chk_activity_events_subject]
    }.freeze

    # Explicit source/milestone versions needed for the current scanned
    # relationships; these are NOT a claim about the owner scratch contents.
    REQUIRED_MIGRATIONS = %w[
      20261108120000 20261113213000 20261115190000
      20261117030000 20261119000500 20261120120000
      20261120183000 20261121003000 20261121120000
    ].freeze

    # Catalog uses public table/column/index/check names and migration versions,
    # never PII, row IDs, passwords, prompts, media or financial ledger content.
    # It is collected by CI tests from a disposable PostgreSQL test database;
    # this module never creates or captures a database connection itself.
    def self.violations(catalog)
      unless catalog.is_a?(Hash) &&
          catalog.keys.sort == %w[migration_versions tables] &&
          catalog.fetch("tables").is_a?(Hash) &&
          catalog.fetch("migration_versions").is_a?(Array)
        raise ArgumentError, "invalid static catalog shape"
      end
      errors = []
      (REQUIRED_MIGRATIONS - catalog.fetch("migration_versions")).each do |version|
        errors << "missing migration #{version}"
      end

      COLUMNS.each do |table, required_columns|
        entry = catalog.fetch("tables").fetch(table, nil)
        unless entry.is_a?(Hash) && entry.keys.sort == %w[checks columns foreign_keys indexes]
          errors << "missing or malformed table #{table}"
          next
        end
        %w[checks columns foreign_keys indexes].each do |key|
          raise ArgumentError, "invalid #{table}.#{key}" unless entry[key].is_a?(Array)
        end

        (required_columns - entry.fetch("columns")).each do |column|
          errors << "missing column #{table}.#{column}"
        end
        FOREIGN_KEYS.fetch(table, {}).each do |column, target|
          unless entry.fetch("foreign_keys").include?([column, target])
            errors << "missing FK #{table}.#{column} -> #{target}"
          end
        end
        INDEXES.fetch(table, {}).each do |name, unique|
          unless entry.fetch("indexes").include?([name, unique])
            errors << "missing index #{table}.#{name} unique=#{unique}"
          end
        end
        (CHECKS.fetch(table, []) - entry.fetch("checks")).each do |name|
          errors << "missing CHECK #{table}.#{name}"
        end
      end
      errors.freeze
    end
  end
end
