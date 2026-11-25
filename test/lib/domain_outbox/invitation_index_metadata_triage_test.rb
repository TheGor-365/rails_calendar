require "test_helper"
require "json"
require "open3"
require "rbconfig"
require_relative "../../../lib/domain_outbox/invitation_index_metadata_triage"

class DomainOutboxInvitationIndexMetadataTriageTest < ActiveSupport::TestCase
  PROBE = DomainOutbox::InvitationIndexMetadataTriage
  OPERATOR = Rails.root.join("script/rc0551f_c23b7k_invitation_index_readonly.rb").to_s

  def reviewed_synthetic_document
    # The connected catalog is disposable GitHub CI PG15, NOT the owner's PG16.
    sample = JSON.parse(ActiveRecord::Base.connection.select_value(PROBE::SQL))
    sample.merge!(
      "database" => PROBE::TARGET,
      "role" => PROBE::ROLE,
      "version_num" => 160011,
      "socket" => true,
      "read_only" => true,
      "other_sessions" => 0
    )
  end

  def matching_index(document)
    document.fetch("indexes").find { |index| index["name"] == PROBE::EXPECTED_INDEX }
  end

  test "C2.3b7k catalog-only SQL and CI synthetic expected index" do
    %w[pg_class pg_namespace pg_index pg_attribute pg_stat_activity].each do |table|
      assert_includes PROBE::SQL, "pg_catalog.#{table}"
    end
    %w[indisvalid indisready indisunique].each do |column|
      assert_includes PROBE::SQL, "idx.#{column}"
    end
    assert_includes PROBE::SQL, "idx.indkey[key_pos.n]"
    refute_match(/\b(?:FROM|JOIN)\s+public\.client_request_invitations\b/i, PROBE::SQL)
    refute_includes PROBE::SQL, "public.schema_migrations"
    %w[token_digest seed_goal client_fact_reviews ai_spend_entries].each do |field|
      refute_includes PROBE::SQL, field
    end

    document = reviewed_synthetic_document
    assert_equal true, document.fetch("table_present")
    assert_equal "r", document.fetch("table_kind")
    assert_not_nil matching_index(document)
    assert_equal "EXACT_EXPECTED_INDEX_PRESENT", PROBE.classify(document)
  end

  test "C2.3b7k classifies index absence invalid unready unique and drift" do
    sample = reviewed_synthetic_document

    missing = Marshal.load(Marshal.dump(sample))
    missing.fetch("indexes").reject! { |index| index["name"] == PROBE::EXPECTED_INDEX }
    assert_equal "INDEX_ABSENT", PROBE.classify(missing)

    %w[valid ready].each do |flag|
      altered = Marshal.load(Marshal.dump(sample))
      matching_index(altered)[flag] = false
      assert_equal "INDEX_INVALID_OR_NOT_READY", PROBE.classify(altered)
    end

    unique = Marshal.load(Marshal.dump(sample))
    matching_index(unique)["unique"] = true
    assert_equal "INDEX_UNEXPECTEDLY_UNIQUE", PROBE.classify(unique)

    renamed = Marshal.load(Marshal.dump(sample))
    matching_index(renamed)["name"] = "index_invitation_workspace_created_renamed"
    assert_equal "INDEX_NAME_OR_DEFINITION_DRIFT", PROBE.classify(renamed)

    [
      lambda { |index| index["keys"].reverse! },
      lambda { |index| index["method"] = "hash" },
      lambda { |index| index["included_count"] = 1 },
      lambda { |index| index["has_predicate"] = true },
      lambda { |index| index["has_expression"] = true }
    ].each do |mutation|
      altered = Marshal.load(Marshal.dump(sample))
      mutation.call(matching_index(altered))
      assert_equal "INDEX_NAME_OR_DEFINITION_DRIFT", PROBE.classify(altered)
    end
  end

  test "C2.3b7k incorrect identity or malformed metadata cannot pass" do
    sample = reviewed_synthetic_document
    {
      "database" => "wrong", "role" => "wrong", "version_num" => 150011,
      "socket" => false, "read_only" => false, "other_sessions" => 1,
      "table_present" => false, "table_kind" => "p"
    }.each do |field, value|
      altered = Marshal.load(Marshal.dump(sample))
      altered[field] = value
      assert_equal "UNKNOWN", PROBE.classify(altered), field
    end
    malformed = Marshal.load(Marshal.dump(sample))
    matching_index(malformed).delete("ready")
    assert_equal "UNKNOWN", PROBE.classify(malformed)
    assert_equal "UNKNOWN", PROBE.classify({})
  end

  test "C2.3b7k wrapper blocks missing one-shot consent and production" do
    clean = {
      "RC_APPROVE_C23B7K_INDEX_READ" => nil,
      "RC_REVIEWED_SCRATCH_NAME" => nil,
      "RC_EXPECTED_HEAD_SHA" => nil,
      "RAILS_ENV" => nil,
      "RACK_ENV" => nil
    }
    stdout, stderr, status = Open3.capture3(clean, RbConfig.ruby, OPERATOR)
    assert_not status.success?
    assert_empty stdout
    assert_includes stderr, "new, separate one-query authorization missing"

    approval = clean.merge(
      "RC_APPROVE_C23B7K_INDEX_READ" => "YES_ONE_C23B7K_INDEX_CATALOG_READ",
      "RC_REVIEWED_SCRATCH_NAME" => PROBE::TARGET
    )
    _stdout, stderr, status = Open3.capture3(
      approval.merge("RAILS_ENV" => "production"), RbConfig.ruby, OPERATOR
    )
    assert_not status.success?
    assert_includes stderr, "development-only context"

    _stdout, stderr, status = Open3.capture3(
      approval.merge("RC_REVIEWED_SCRATCH_NAME" => "wrong"), RbConfig.ruby, OPERATOR
    )
    assert_not status.success?
    assert_includes stderr, "wrong reviewed scratch identity"
  end
end
