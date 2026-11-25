require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxRequirementSetBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("requirement-dry-run-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("requirement-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("requirement-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("requirement-empty-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @intake = make_intake(@workspace)
    @source = make_revision(@intake)
    @spare_revision = make_revision(@intake, version: 2)
    @sets = (1..4).map { |version| make_set(@intake, @source, version) }
    @foreign_intake = make_intake(@other_workspace)
    @foreign_revision = make_revision(@foreign_intake)
    @foreign_set = make_set(@foreign_intake, @foreign_revision, 1)

    # Synthetic CI fixture only: all four envelope/projection combinations.
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeRequirementSet", source_id: @sets[1].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: event_key(@sets[2])).delete_all
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeRequirementSet", source_id: @sets[3].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: event_key(@sets[3])).delete_all
  end

  def make_intake(workspace)
    ProjectIntake.create!(
      workspace: workspace, title: "Fictional versioned requirement audit",
      project_type: "rails_bugfix",
      goal: "Synthetic requirement version lineage without user content.",
      demo_consent_at: Time.current
    )
  end

  def make_revision(intake, version: 1)
    intake.intake_scope_revisions.create!(
      version: version, author_role: "owner",
      answers: { "business_goal" => {
        "text" => "Only fictional scope input",
        "status" => "suggested", "responsibility" => "owner"
      } }
    )
  end

  def make_set(intake, revision, version)
    intake.intake_requirement_sets.create!(
      intake_scope_revision: revision, version: version,
      requirements: [] # intentionally avoids reading or exporting client statements
    )
  end

  def event_key(set)
    "IntakeRequirementSet:#{set.id}:requirements_saved"
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::RequirementSetBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7c counts only owner-scoped immutable sets with no writes" do
    assert_no_difference([
      "ProjectIntake.count", "IntakeScopeRevision.count",
      "IntakeRequirementSet.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      expected = {
        source_type: "IntakeRequirementSet", inspected: 4,
        already_indexed: 1, projection_only: 1, envelope_only: 1,
        missing_both: 1, inconsistent_records: 0, ineligible_sources: 0,
        has_more: false, scan_budget_exhausted: false, next_cursor: nil
      }
      assert_equal expected, result
      assert_equal result, preview
      assert_equal 1, preview(owner: @other)[:already_indexed]
      assert_equal 1, preview(owner: @other)[:inspected]
      assert_not_includes result.to_json, @intake.title
      assert_not_includes result.to_json, @foreign_intake.title
      assert_not result.key?(:source_id)
      assert_not result.key?(:revision_id)
      assert_not result.key?(:requirements)
    end
  end

  test "C2.3b7c requirement set version is independent of source scope version" do
    assert_equal 1, @source.version
    assert_equal [1, 2, 3, 4], @sets.map(&:version)
    assert_equal 1, preview[:already_indexed]
    assert_equal 0, preview[:ineligible_sources]
  end

  test "C2.3b7c wrong outbox version and activity version metadata are inconsistent" do
    first = @sets[0]
    projection_only = @sets[1]
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeRequirementSet", source_id: first.id)
      .update_all(source_version: 98)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: event_key(projection_only))
      .update_all(metadata: { "version" => 99 })
    assert_no_difference([
      "IntakeRequirementSet.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 2, result[:inconsistent_records]
      assert_equal 0, result[:already_indexed]
      assert_equal 0, result[:projection_only]
      assert_equal 1, result[:envelope_only]
      assert_equal 1, result[:missing_both]
    end
  end

  test "C2.3b7c drifted timestamps never count as indexed" do
    first = @sets[0]
    projection_only = @sets[1]
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeRequirementSet", source_id: first.id)
      .update_all(occurred_at: first.created_at + 1.hour)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: event_key(projection_only))
      .update_all(occurred_at: projection_only.created_at + 1.hour)
    result = preview
    assert_equal 2, result[:inconsistent_records]
    assert_equal 0, result[:already_indexed]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
  end

  test "C2.3b7c mismatched source revision lineage is ineligible, not backfillable" do
    first = @sets[0]
    # DB has a single-column FK to scope revision, not a composite tenant FK.
    # Emulate historical corruption only in synthetic test fixtures.
    IntakeRequirementSet.where(id: first.id)
      .update_all(intake_scope_revision_id: @foreign_revision.id)
    assert_no_difference([
      "IntakeRequirementSet.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 1, result[:ineligible_sources]
      assert_equal 0, result[:already_indexed]
      assert_equal 1, result[:projection_only]
      assert_equal 1, result[:envelope_only]
      assert_equal 1, result[:missing_both]
    end
  end

  test "C2.3b7c encrypted cursor separates owner, family and bounds scanning" do
    first = preview(limit: 2)
    assert_equal 2, first[:inspected]
    assert first[:has_more]
    assert_kind_of String, first[:next_cursor]
    assert_operator first[:next_cursor].bytesize, :<=, 2048

    second = preview(limit: 2, cursor: first[:next_cursor])
    assert_equal 2, second[:inspected]
    assert_equal 1, second[:envelope_only]
    assert_equal 1, second[:missing_both]
    assert_equal false, second[:has_more]
    assert_nil second[:next_cursor]

    assert_raises(ArgumentError) { preview(owner: @other, limit: 2, cursor: first[:next_cursor]) }
    assert_raises(ArgumentError) { preview(owner: @client, limit: 2, cursor: first[:next_cursor]) }
    assert_raises(ArgumentError) { preview(limit: 2, cursor: first[:next_cursor].reverse) }

    other_family_cursor = DomainOutbox::ScopeRevisionBackfillDryRun.preview(
      owner: @owner, limit: 1
    )[:next_cursor]
    assert_kind_of String, other_family_cursor
    assert_raises(ArgumentError) { preview(limit: 2, cursor: other_family_cursor) }
  end

  test "C2.3b7c rejects invalid actors, limits and tokens" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { preview(owner: actor) }
    end
    [nil, 0, -1, 26, 251, "5", 1.5].each do |bad|
      assert_raises(ArgumentError) { preview(limit: bad) }
    end
    ["", "invalid", "z" * 2049, 123, []].each do |bad|
      assert_raises(ArgumentError) { preview(cursor: bad) }
    end
  end

  test "C2.3b7c 250-row chain stops without automatic cursor renewal" do
    crypto = DomainOutbox::RequirementSetBackfillDryRun.send(:encryptor)
    cursor = crypto.encrypt_and_sign({
      "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
      "source_type" => "IntakeRequirementSet",
      "ceiling_id" => @sets.last.id, "after_id" => @sets.first.id,
      "scanned" => 249
    }, purpose: DomainOutbox::RequirementSetBackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes)
    result = preview(limit: 25, cursor: cursor)
    assert_equal 1, result[:inspected]
    assert_equal true, result[:has_more]
    assert_equal true, result[:scan_budget_exhausted]
    assert_nil result[:next_cursor]
  end
end
