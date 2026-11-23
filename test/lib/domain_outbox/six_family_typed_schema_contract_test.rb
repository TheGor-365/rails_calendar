require "test_helper"
require_relative "../../../lib/domain_outbox/six_family_typed_schema_contract"

class DomainOutboxSixFamilyTypedSchemaContractTest < ActiveSupport::TestCase
  T = DomainOutbox::SixFamilyTypedSchemaContract
  B = DomainOutbox::SixFamilyScratchSchemaContract

  def example_report
    {
      "migration_versions" => B::REQUIRED_MIGRATIONS.dup,
      "tables" => T::COLUMN_SPEC.keys.to_h do |table|
        [table, {
          "columns" => Marshal.load(Marshal.dump(T::COLUMN_SPEC.fetch(table))),
          "indexes" => Marshal.load(Marshal.dump(T::INDEX_SPEC.fetch(table, {}))),
          "foreign_keys" => Marshal.load(Marshal.dump(T::FK_SPEC.fetch(table, {}))),
          "checks" => Marshal.load(Marshal.dump(T::CHECK_SPEC.fetch(table, {})))
        }]
      end
    }
  end

  test "C2.3b7t covers 94 minimum columns of all 17 tables" do
    assert_equal B::COLUMNS.keys.sort, T::COLUMN_SPEC.keys.sort
    assert_equal 17, T::COLUMN_SPEC.size
    assert_equal 94, T::COLUMN_SPEC.values.sum(&:size)
    B::COLUMNS.each do |table, columns|
      assert_equal columns.sort, T::COLUMN_SPEC.fetch(table).keys.sort
    end
    T::INDEX_SPEC.each do |table, indexes|
      indexes.each do |name, spec|
        next if name == "idx_service_offering_single_draft"
        assert_equal B::INDEXES.fetch(table).fetch(name), spec.fetch("unique")
      end
    end
    T::FK_SPEC.each do |table, pairs|
      pairs.each do |column, spec|
        assert_equal B::FOREIGN_KEYS.fetch(table).fetch(column), spec.fetch("target_table")
      end
    end
    B::CHECKS.each do |table, names|
      assert_equal names.sort, T::CHECK_SPEC.fetch(table).keys.sort
    end
  end

  test "C2.3b7t synthetic matching metadata cannot authorize scan" do
    r = T.assess(example_report)
    assert_equal "G5_TYPED_MINIMUM_PASS", r.fetch(:status)
    assert_empty r.fetch(:reasons)
    assert_equal false, r.fetch(:scan_approved)
    assert_equal false, r.fetch(:writer_approved)
    assert_equal false, r.fetch(:full_g5_approved)
    assert_equal false, r.fetch(:tenancy_verified)
  end

  test "C2.3b7t type, nullability and varchar length mismatch BLOCK" do
    [["type", "integer"], ["not_null", false], ["limit", 999]].each do |key, value|
      doc = example_report
      doc["tables"]["client_request_invitations"]["columns"]["workspace_id"][key] = value
      assert_equal "G5_TYPED_BLOCKED", T.assess(doc).fetch(:status)
    end
    doc = example_report
    doc["tables"]["active_storage_blobs"]["columns"].delete("key")
    assert_equal "G5_TYPED_BLOCKED", T.assess(doc).fetch(:status)
  end

  test "C2.3b7t index key order, partial predicate, FK and CHECK drift BLOCK" do
    mutations = [
      ["intake_scope_revisions", "indexes", "idx_intake_scope_revisions_version", "keys", ["version", "project_intake_id"]],
      ["intake_scope_revisions", "indexes", "idx_intake_scope_revisions_version", "ready", false],
      ["service_offering_versions", "indexes", "idx_service_offering_single_draft", "predicate", nil],
      ["active_storage_attachments", "foreign_keys", "blob_id", "target_columns", ["key"]],
      ["activity_events", "checks", "chk_activity_events_subject", "validated", false],
      ["activity_events", "checks", "chk_activity_events_subject", "source_expression", "subject_id >= 0"]
    ]
    mutations.each do |table,section,name,key,value|
      doc=example_report
      doc["tables"][table][section][name][key]=value
      assert_equal "G5_TYPED_BLOCKED", T.assess(doc).fetch(:status)
    end
  end

  test "C2.3b7t required migrations, bad shape and unknown sections BLOCK" do
    doc=example_report
    doc["migration_versions"].pop
    assert_equal "G5_TYPED_BLOCKED", T.assess(doc).fetch(:status)
    doc=example_report
    doc["tables"]["users"].delete("foreign_keys")
    assert_equal "G5_TYPED_BLOCKED", T.assess(doc).fetch(:status)
    assert_equal "G5_TYPED_BLOCKED", T.assess({}).fetch(:status)
    assert_equal "G5_TYPED_BLOCKED", T.assess(nil).fetch(:status)
  end
end
