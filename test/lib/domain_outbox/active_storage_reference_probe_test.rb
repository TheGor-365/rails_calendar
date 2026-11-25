require "test_helper"
require "open3"
require "rbconfig"
require_relative "../../../lib/domain_outbox/active_storage_reference_probe"

class DomainOutboxActiveStorageReferenceProbeTest < ActiveSupport::TestCase
  P = DomainOutbox::ActiveStorageReferenceProbe
  SCRIPT = Rails.root.join("script/rc0551f_c23b7s_dual_db_aggregates_readonly.rb").to_s

  def identity(db)
    {
      "database" => db, "role" => "gor", "version_num" => 160011,
      "socket" => true, "read_only" => true, "other_sessions" => 0,
      "tables" => P::TABLES.to_h { |name| [name, true] }
    }
  end

  def aggregate
    {
      "blob_count" => 12, "attachment_count" => 7, "variant_count" => 2,
      "orphan_attachments" => 0, "orphan_variants" => 0,
      "blank_blob_keys" => 0, "nonlocal_blobs" => 0
    }
  end

  test "C2.3b7s pure contract accepts exact isolated identities" do
    assert P.validate_identity!(identity(P::SOURCE), expected: P::SOURCE)
    assert P.validate_identity!(identity(P::SCRATCH), expected: P::SCRATCH)
    [P::SOURCE, P::SCRATCH].each do |db|
      %w[read_only socket].each do |key|
        bad = identity(db).merge(key => false)
        assert_raises(ArgumentError) { P.validate_identity!(bad, expected: db) }
      end
      bad = identity(db).merge("other_sessions" => 1)
      assert_raises(ArgumentError) { P.validate_identity!(bad, expected: db) }
      bad = identity(db).merge("tables" => { "active_storage_blobs" => true })
      assert_raises(ArgumentError) { P.validate_identity!(bad, expected: db) }
      bad = identity(db).merge("database" => "other_database")
      assert_raises(ArgumentError) { P.validate_identity!(bad, expected: db) }
    end
  end

  test "C2.3b7s only fixed SQL references permitted Active Storage tables" do
    assert P::IDENTITY_SQL.lstrip.start_with?("SELECT")
    assert P::AGGREGATE_SQL.lstrip.start_with?("SELECT")
    assert_includes P::IDENTITY_SQL, "pg_catalog.pg_stat_activity"
    %w[active_storage_blobs active_storage_attachments active_storage_variant_records].each do |name|
      assert_includes P::AGGREGATE_SQL, "public.#{name}"
    end
    %w[filename metadata checksum token_digest seed_goal request_digest].each do |secret|
      refute_match(/\b#{Regexp.escape(secret)}\b/, P::AGGREGATE_SQL)
    end
    refute_match(/\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|COPY|GRANT|TRUNCATE)\b/i, P::AGGREGATE_SQL)
  end

  test "C2.3b7s identical aggregate yields no authorization" do
    x = P.assess(source: aggregate, scratch: aggregate)
    assert_equal "AGGREGATE_PARITY", x.fetch(:status)
    assert_equal "ZERO", x.fetch(:orphan_blob_references)
    assert_equal false, x.fetch(:media_file_reference_parity_proved)
    assert_equal false, x.fetch(:tenant_isolation_proved)
    assert_equal false, x.fetch(:writer_quiescence_proved)
    assert_equal false, x.fetch(:replay_authorized)
    assert_equal false, x.fetch(:production_authorized)
  end

  test "C2.3b7s mismatches and orphan keys cannot silently PASS" do
    changed = aggregate.merge("blob_count" => 13)
    assert_equal "DELTA_REVIEW", P.assess(source: aggregate, scratch: changed).fetch(:status)
    orphan = aggregate.merge("orphan_attachments" => 1)
    r = P.assess(source: orphan, scratch: aggregate)
    assert_equal "DELTA_REVIEW", r.fetch(:status)
    assert_equal "PRESENT", r.fetch(:orphan_blob_references)
    blank = aggregate.merge("blank_blob_keys" => 1)
    assert_equal "DELTA_REVIEW", P.assess(source: blank, scratch: aggregate).fetch(:status)
    nonlocal = aggregate.merge("nonlocal_blobs" => 2)
    # Equal source/scratch counts are not a safe local DiskService recovery.
    assert_equal "DELTA_REVIEW",
      P.assess(source: nonlocal, scratch: nonlocal).fetch(:status)
    assert_equal "DELTA_REVIEW",
      P.assess(source: nonlocal, scratch: aggregate).fetch(:status)
    assert_raises(ArgumentError) {
      P.validate_aggregate!(aggregate.merge("nonlocal_blobs" => 13))
    }
    assert_raises(ArgumentError) { P.validate_aggregate!(aggregate.merge("extra" => 1)) }
    assert_raises(ArgumentError) { P.validate_aggregate!(aggregate.merge("blob_count" => -1)) }
    assert_raises(ArgumentError) { P.validate_aggregate!(aggregate.merge("orphan_variants" => 3)) }
  end

  test "C2.3b7s operator refuses to connect without independent consent" do
    env = {
      "RC_APPROVE_C23B7S_AGGREGATES" => nil, "RC_REVIEWED_SOURCE" => nil,
      "RC_REVIEWED_SCRATCH" => nil, "RC_EXPECTED_HEAD_SHA" => nil,
      "RAILS_ENV" => nil, "RACK_ENV" => nil
    }
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, SCRIPT)
    assert_not status.success?
    assert_empty stdout
    assert_includes stderr, "NEW_EXPLICIT_APPROVAL_REQUIRED"
    approved = env.merge(
      "RC_APPROVE_C23B7S_AGGREGATES" => "YES_ONE_C23B7S_DUAL_DB_AGGREGATE_READ",
      "RC_REVIEWED_SOURCE" => P::SOURCE, "RC_REVIEWED_SCRATCH" => P::SCRATCH,
      "RAILS_ENV" => "production"
    )
    stdout, stderr, status = Open3.capture3(approved, RbConfig.ruby, SCRIPT)
    assert_not status.success?
    assert_empty stdout
    assert_includes stderr, "DEVELOPMENT_ONLY"
  end
end
