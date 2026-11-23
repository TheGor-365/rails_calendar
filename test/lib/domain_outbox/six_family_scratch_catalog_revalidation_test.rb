require "test_helper"
require "json"
require "open3"
require "rbconfig"
require_relative "../../../lib/domain_outbox/six_family_scratch_metadata_probe"

class DomainOutboxSixFamilyScratchCatalogRevalidationTest < ActiveSupport::TestCase
  PROBE = DomainOutbox::SixFamilyScratchMetadataProbe
  CONTRACT = DomainOutbox::SixFamilyScratchSchemaContract
  OPERATOR = Rails.root.join("script/rc0551f_c23b7n_scratch_catalog_readonly.rb").to_s

  def fake_pg16_document
    # ONLY disposable CI database. Never connect to owner PostgreSQL 16.
    report = JSON.parse(ActiveRecord::Base.connection.select_value(PROBE::SQL))
    report.merge(
      "database" => PROBE::TARGET, "role" => PROBE::ROLE,
      "version_num" => 160011, "socket" => true,
      "read_only" => true, "other_sessions" => 0
    )
  end

  test "C2.3b7n accepts fixed Rails-generated index catalog name" do
    report = fake_pg16_document
    entry = report.fetch("catalog").fetch("tables").fetch("client_request_invitations")
    names = [CONTRACT::LEGACY_INVITATION_INDEX, CONTRACT::RAILS_GENERATED_INVITATION_INDEX]
    entry.fetch("indexes").reject! { |pair| names.include?(pair.first) }
    entry.fetch("indexes") << [CONTRACT::RAILS_GENERATED_INVITATION_INDEX, false]
    result = PROBE.assess(report)
    assert_equal "SCHEMA_CATALOG_PASS", result.fetch(:status)
    assert_equal false, result.fetch(:scan_approved)
    assert_equal false, result.fetch(:writer_approved)
    assert_equal false, result.fetch(:backup_restore_verified)
  end

  test "C2.3b7n fails closed for unknown index and uniqueness" do
    [ ["unrecognized_invitation_index", false],
      [CONTRACT::RAILS_GENERATED_INVITATION_INDEX, true] ].each do |replacement|
      report = fake_pg16_document
      entry = report.fetch("catalog").fetch("tables").fetch("client_request_invitations")
      entry.fetch("indexes").reject! do |pair|
        [CONTRACT::LEGACY_INVITATION_INDEX, CONTRACT::RAILS_GENERATED_INVITATION_INDEX].include?(pair.first)
      end
      entry.fetch("indexes") << replacement
      result = PROBE.assess(report)
      assert_equal "SCHEMA_CATALOG_BLOCKED", result.fetch(:status)
      assert_includes result.fetch(:reasons),
        "missing index client_request_invitations.#{CONTRACT::RAILS_GENERATED_INVITATION_INDEX} unique=false"
    end
  end

  test "C2.3b7n operator cannot run without new independent approval" do
    env = {
      "RC_APPROVE_C23B7N_METADATA_READ" => nil,
      "RC_REVIEWED_SCRATCH_NAME" => nil,
      "RC_EXPECTED_HEAD_SHA" => nil,
      "RAILS_ENV" => nil, "RACK_ENV" => nil
    }
    output, error, status = Open3.capture3(env, RbConfig.ruby, OPERATOR)
    assert_not status.success?
    assert_empty output
    assert_includes error, "explicit metadata-only permission missing"

    approved = env.merge(
      "RC_APPROVE_C23B7N_METADATA_READ" => "YES_ONE_C23B7N_17_TABLE_METADATA_READ",
      "RC_REVIEWED_SCRATCH_NAME" => PROBE::TARGET
    )
    out, error, status = Open3.capture3(
      approved.merge("RAILS_ENV" => "production"), RbConfig.ruby, OPERATOR
    )
    assert_not status.success?
    assert_empty out
    assert_includes error, "development-only context"
  end

  test "C2.3b7n SQL is catalog-only except migration version metadata" do
    assert_includes PROBE::SQL, "pg_catalog.pg_index"
    assert_includes PROBE::SQL, "idx.indisvalid AND idx.indisready"
    assert_includes PROBE::SQL, "public.schema_migrations"
    CONTRACT::COLUMNS.each_key do |table|
      refute_match(/\b(?:FROM|JOIN)\s+public\.#{Regexp.escape(table)}\b/i, PROBE::SQL)
    end
    %w[token_digest seed_goal goal provider_response_id].each do |secret|
      refute_includes PROBE::SQL, secret
    end
  end
end
