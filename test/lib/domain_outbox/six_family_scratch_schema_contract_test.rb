require "test_helper"
require_relative "../../../lib/domain_outbox/six_family_scratch_schema_contract"

class DomainOutboxSixFamilyScratchSchemaContractTest < ActiveSupport::TestCase
  CONTRACT = DomainOutbox::SixFamilyScratchSchemaContract

  # Introspection of the CI-created test DB *catalog only*. Never query
  # customer rows, the owner's PostgreSQL socket, backups or Railway.
  def synthetic_catalog
    db = ActiveRecord::Base.connection
    tables = CONTRACT::COLUMNS.keys.to_h do |table|
      next [table, nil] unless db.data_source_exists?(table)

      [table, {
        "columns" => db.columns(table).map(&:name),
        "foreign_keys" => db.foreign_keys(table).map do |fk|
          [fk.column.to_s, fk.to_table.to_s]
        end,
        "indexes" => db.indexes(table).map do |index|
          [index.name, index.unique]
        end,
        "checks" => db.check_constraints(table).map(&:name)
      }]
    end
    {
      "tables" => tables,
      "migration_versions" => db.select_values("SELECT version FROM schema_migrations")
    }
  end

  test "C2.3b7i actual isolated CI test schema implements six-family catalog" do
    assert_empty CONTRACT.violations(synthetic_catalog)
    assert_equal(
      DomainOutbox::CrossFamilyBackfillDryRun::FAMILIES.map { |family| family[1] },
      CONTRACT::FAMILIES.keys
    )

    # Fingerprint SELECT list and the shared event projection must never
    # silently gain a source column absent from the minimum catalog.
    DomainOutbox::CrossFamilyBackfillDryRun::FIELDS.each_value do |columns|
      columns.each do |field|
        table, column = field.split(".", 2)
        assert_includes CONTRACT::COLUMNS.fetch(table), column
      end
    end
    CONTRACT::FAMILIES.each do |source, required_tables|
      required_tables.each do |table|
        assert CONTRACT::COLUMNS.key?(table), "#{source}: unknown relation #{table}"
      end
    end
    CONTRACT::REQUIRED_MIGRATIONS.each do |version|
      matches = Dir.glob(Rails.root.join("db/migrate/#{version}_*.rb").to_s)
      assert_equal 1, matches.length, "missing/ambiguous versioned migration #{version}"
    end
  end

  test "C2.3b7i rejects missing activity table, a required column and migration" do
    catalog = synthetic_catalog
    catalog["tables"].delete("activity_events")
    assert_includes CONTRACT.violations(catalog), "missing or malformed table activity_events"

    catalog = synthetic_catalog
    catalog.fetch("tables").fetch("owner_ai_messages").fetch("columns").delete("sequence")
    assert_includes CONTRACT.violations(catalog), "missing column owner_ai_messages.sequence"

    catalog = synthetic_catalog
    catalog.fetch("migration_versions").delete("20261121120000")
    assert_includes CONTRACT.violations(catalog), "missing migration 20261121120000"
  end

  test "C2.3b7i catches wrong FK, missing CHECK and non-unique event key" do
    catalog = synthetic_catalog
    catalog.fetch("tables").fetch("intake_requirement_sets").fetch("foreign_keys")
      .delete(["intake_scope_revision_id", "intake_scope_revisions"])
    assert_includes CONTRACT.violations(catalog),
      "missing FK intake_requirement_sets.intake_scope_revision_id -> intake_scope_revisions"

    catalog = synthetic_catalog
    catalog.fetch("tables").fetch("domain_outbox_events").fetch("checks")
      .delete("chk_domain_outbox_valid_state")
    assert_includes CONTRACT.violations(catalog),
      "missing CHECK domain_outbox_events.chk_domain_outbox_valid_state"

    catalog = synthetic_catalog
    source_indexes = catalog.fetch("tables").fetch("intake_requirement_sets").fetch("indexes")
    source_indexes.delete(["idx_intake_requirement_sets_source", false])
    source_indexes << ["idx_intake_requirement_sets_source", true]
    assert_includes CONTRACT.violations(catalog),
      "missing index intake_requirement_sets.idx_intake_requirement_sets_source unique=false"

    catalog = synthetic_catalog
    indexes = catalog.fetch("tables").fetch("activity_events").fetch("indexes")
    indexes.delete(["idx_activity_events_workspace_key", true])
    indexes << ["idx_activity_events_workspace_key", false]
    assert_includes CONTRACT.violations(catalog),
      "missing index activity_events.idx_activity_events_workspace_key unique=true"
  end

  test "C2.3b7m accepts only both verified Rails invitation index names" do
    require "digest"

    full = CONTRACT::LEGACY_INVITATION_INDEX
    generated = CONTRACT::RAILS_GENERATED_INVITATION_INDEX

    assert_equal 63, full.bytesize
    assert_equal 62, ActiveRecord::Base.connection.max_index_name_size
    assert_equal "idx_on_workspace_id_created_at_#{Digest::SHA256.hexdigest(full).first(10)}",
      generated

    for_name = lambda do |name, unique|
      catalog = synthetic_catalog
      indexes = catalog.fetch("tables").fetch("client_request_invitations").fetch("indexes")
      indexes.reject! { |item| [full, generated].include?(item[0]) }
      indexes << [name, unique]
      catalog
    end

    assert_empty CONTRACT.violations(for_name.call(generated, false))
    assert_empty CONTRACT.violations(for_name.call(full, false))

    unknown = for_name.call("idx_on_workspace_id_created_at_arbitrary", false)
    assert_includes CONTRACT.violations(unknown),
      "missing index client_request_invitations.#{generated} unique=false"

    wrong_unique = for_name.call(generated, true)
    assert_includes CONTRACT.violations(wrong_unique),
      "missing index client_request_invitations.#{generated} unique=false"
  end

  test "C2.3b7i contract requires explicit catalog shape and emits no DB acceptance" do
    assert_raises(ArgumentError) { CONTRACT.violations({}) }
    assert_raises(ArgumentError) do
      CONTRACT.violations("tables" => {}, "migration_versions" => [], "secret" => "fake")
    end
    assert CONTRACT.violations(synthetic_catalog).is_a?(Array)
    assert_not CONTRACT.respond_to?(:restore!)
    assert_not CONTRACT.respond_to?(:migrate!)
    assert_not CONTRACT.respond_to?(:scan!)
    assert_not CONTRACT.respond_to?(:approve!)
  end
end
