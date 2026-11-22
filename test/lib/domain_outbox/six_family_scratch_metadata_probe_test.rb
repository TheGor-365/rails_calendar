require "test_helper"
require "json"
require "open3"
require "rbconfig"
require_relative "../../../lib/domain_outbox/six_family_scratch_metadata_probe"

class DomainOutboxSixFamilyScratchMetadataProbeTest < ActiveSupport::TestCase
  PROBE = DomainOutbox::SixFamilyScratchMetadataProbe
  CONTRACT = DomainOutbox::SixFamilyScratchSchemaContract
  OPERATOR = Rails.root.join("script/rc0551f_c23b7j_scratch_catalog_readonly.rb").to_s

  def synthetic_ci_document
    # CI ONLY: the disposal PostgreSQL 15 test DB. There is never a query
    # against the owner's real PG16, media, Railway or production.
    JSON.parse(ActiveRecord::Base.connection.select_value(PROBE::SQL))
  end

  def spoofed_identity
    doc = synthetic_ci_document
    doc["database"] = PROBE::TARGET
    doc["role"] = PROBE::ROLE
    doc["version_num"] = 160011
    doc["socket"] = true
    doc["read_only"] = true
    doc["other_sessions"] = 0
    doc
  end

  test "C2.3b7j catalog SQL is scoped to exactly the known 17 public metadata tables" do
    assert_equal 17, PROBE::TABLES.length
    PROBE::TABLES.each do |table|
      assert_includes PROBE::SQL, "'#{table}'"
    end
    assert_includes PROBE::SQL, "public.schema_migrations"
    assert_includes PROBE::SQL, "pg_catalog.pg_constraint"
    assert_includes PROBE::SQL, "pg_catalog.pg_index"
    assert_includes PROBE::SQL, "idx.indisvalid AND idx.indisready"
    assert_includes PROBE::SQL, "fk.convalidated"
    assert_includes PROBE::SQL, "con.convalidated"
    %w[goal body token_digest seed_goal requirements answers result usage provider_response_id].each do |secret|
      refute_match(/\b#{Regexp.escape(secret)}\b/, PROBE::SQL)
    end

    ci_document = synthetic_ci_document
    assert_empty CONTRACT.violations(ci_document.fetch("catalog"))
    assert_equal false, ci_document.fetch("read_only") # CI service SELECT, not operator PGOPTIONS
    assert_equal "SCHEMA_CATALOG_PASS", PROBE.assess(spoofed_identity).fetch(:status)
    assert_equal false, PROBE.assess(spoofed_identity).fetch(:scan_approved)
    assert_equal false, PROBE.assess(spoofed_identity).fetch(:backup_restore_verified)
  end

  test "C2.3b7j never accepts a failed target, transport, mode or concurrent sessions" do
    mismatches = {
      "database" => "ruby_calendar_test",
      "role" => "unexpected",
      "version_num" => 150011,
      "socket" => false,
      "read_only" => false,
      "other_sessions" => 1
    }
    mismatches.each do |key, bad_value|
      sample = spoofed_identity
      sample[key] = bad_value
      result = PROBE.assess(sample)
      assert_equal "SCHEMA_CATALOG_BLOCKED", result.fetch(:status), key
      assert_equal false, result.fetch(:writer_approved)
    end
  end

  test "C2.3b7j blocks missing activity, FK, source index, invalid migration and CHECK" do
    [
      lambda { |doc| doc.fetch("catalog").fetch("tables").delete("activity_events") },
      lambda { |doc| doc.fetch("catalog").fetch("tables")
        .fetch("owner_ai_messages").fetch("columns").delete("sequence") },
      lambda { |doc| doc.fetch("catalog").fetch("tables")
        .fetch("intake_requirement_sets").fetch("foreign_keys")
        .delete(["intake_scope_revision_id", "intake_scope_revisions"]) },
      lambda { |doc| doc.fetch("catalog").fetch("tables")
        .fetch("intake_requirement_sets").fetch("indexes")
        .delete(["idx_intake_requirement_sets_source", false]) },
      lambda { |doc| doc.fetch("catalog").fetch("tables")
        .fetch("domain_outbox_events").fetch("checks")
        .delete("chk_domain_outbox_valid_state") },
      lambda { |doc| doc.fetch("catalog").fetch("migration_versions")
        .delete("20261120204500") }
    ].each do |mutation|
      doc = spoofed_identity
      mutation.call(doc)
      result = PROBE.assess(doc)
      assert_equal "SCHEMA_CATALOG_BLOCKED", result.fetch(:status)
      assert result.fetch(:reasons).any?
    end
  end

  test "C2.3b7j wrapper refuses missing authorization and inherited production context offline" do
    clean = {
      "RC_APPROVE_C23B7J_METADATA_READ" => nil,
      "RC_REVIEWED_SCRATCH_NAME" => nil,
      "RC_EXPECTED_HEAD_SHA" => nil,
      "DATABASE_URL" => nil,
      "RC_LOCAL_DEV_DATABASE_URL" => nil,
      "PGHOST" => nil,
      "PGUSER" => nil
    }
    output, error, status = Open3.capture3(
      clean, RbConfig.ruby, OPERATOR
    )
    assert_not status.success?
    assert_includes error, "explicit metadata-only permission missing"
    assert_empty output

    ["production", "test"].each do |app_env|
      _, error, status = Open3.capture3(
        clean.merge(
          "RC_APPROVE_C23B7J_METADATA_READ" => "YES_METADATA_ONLY",
          "RC_REVIEWED_SCRATCH_NAME" => PROBE::TARGET,
          "RAILS_ENV" => app_env
        ), RbConfig.ruby, OPERATOR
      )
      assert_not status.success?
      assert_includes error, "development-only context"
    end
    _, error, status = Open3.capture3(
      clean.merge(
        "RC_APPROVE_C23B7J_METADATA_READ" => "YES_METADATA_ONLY",
        "RC_REVIEWED_SCRATCH_NAME" => PROBE::TARGET,
        "RAILS_ENV" => "development",
        "DATABASE_URL" => "postgres://invalid.example/production"
      ), RbConfig.ruby, OPERATOR
    )
    assert_not status.success?
    assert_includes error, "inherited application/PostgreSQL context"
  end
end
