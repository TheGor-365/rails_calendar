require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxScopeRevisionBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("scope-backfill-own-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("scope-backfill-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("scope-backfill-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("scope-backfill-empty-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @intake = create_intake(@workspace)
    @spare_intake = create_intake(@workspace) # ensures distinct-family cursor exists
    @revisions = (1..4).map { |version| create_revision(@intake, version) }
    @foreign = create_revision(create_intake(@other_workspace), 1)

    # Synthetic CI-only missing-row conditions; never delete real user data.
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeScopeRevision", source_id: @revisions[1].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: activity_key(@revisions[2])).delete_all
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeScopeRevision", source_id: @revisions[3].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: activity_key(@revisions[3])).delete_all
  end

  def create_intake(workspace)
    ProjectIntake.create!(
      workspace: workspace, title: "Fictional scope revision audit",
      project_type: "rails_bugfix",
      goal: "A synthetic historical source audit without client information.",
      demo_consent_at: Time.current
    )
  end

  def create_revision(intake, version)
    intake.intake_scope_revisions.create!(
      version: version, author_role: "owner",
      answers: {
        "business_goal" => {
          "text" => "Only fictional test requirements.",
          "status" => "suggested", "responsibility" => "owner"
        }
      }
    )
  end

  def activity_key(revision)
    "IntakeScopeRevision:#{revision.id}:scope_revision_saved"
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::ScopeRevisionBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7b four exact source-version reconciliation categories and no writes" do
    counters = [
      "ProjectIntake.count", "IntakeScopeRevision.count",
      "DomainOutboxEvent.count", "ActivityEvent.count",
      "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]
    assert_no_difference(counters) do
      expected = {
        source_type: "IntakeScopeRevision", inspected: 4,
        already_indexed: 1, projection_only: 1,
        envelope_only: 1, missing_both: 1,
        inconsistent_records: 0, ineligible_sources: 0,
        has_more: false, scan_budget_exhausted: false, next_cursor: nil
      }
      assert_equal expected, preview
      assert_equal expected, preview
      assert_equal 1, preview(owner: @other)[:already_indexed]
      assert_equal 1, preview(owner: @other)[:inspected]
      assert_not_includes expected.to_json, @foreign.project_intake.goal
      assert_not_includes expected.to_json, @intake.title
      assert_not expected.key?(:source_id)
      assert_not expected.key?(:version)
    end
  end

  test "C2.3b7b version and occurred_at metadata drift must never be marked indexed" do
    first = @revisions.first
    other = @revisions[1] # projection exists here (envelope was deleted)
    assert_equal 1, preview[:already_indexed]
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeScopeRevision", source_id: first.id)
      .update_all(source_version: 99)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: activity_key(other))
      .update_all(metadata: { "version" => 98 })
    assert_no_difference([
      "DomainOutboxEvent.count", "ActivityEvent.count",
      "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 2, result.fetch(:inconsistent_records)
      assert_equal 0, result.fetch(:already_indexed)
      assert_equal 0, result.fetch(:projection_only)
      assert_equal 1, result.fetch(:envelope_only)
      assert_equal 1, result.fetch(:missing_both)
    end
  end

  test "C2.3b7b source/envelope or activity timestamp drift is inconsistent" do
    first = @revisions.first
    projection_only = @revisions[1]
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeScopeRevision", source_id: first.id)
      .update_all(occurred_at: first.created_at + 1.hour)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: activity_key(projection_only))
      .update_all(occurred_at: projection_only.created_at + 1.hour)

    assert_no_difference([
      "IntakeScopeRevision.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 2, result.fetch(:inconsistent_records)
      assert_equal 0, result.fetch(:already_indexed)
      assert_equal 0, result.fetch(:projection_only)
      assert_equal 1, result.fetch(:envelope_only)
      assert_equal 1, result.fetch(:missing_both)
    end
  end

  test "C2.3b7b opaque cursor separates owners, source family and pins ceiling" do
    first = preview(limit: 2)
    assert_equal 2, first.fetch(:inspected)
    assert first.fetch(:has_more)
    assert_kind_of String, first.fetch(:next_cursor)
    assert_operator first.fetch(:next_cursor).bytesize, :<=, 2048

    second = preview(limit: 2, cursor: first.fetch(:next_cursor))
    assert_equal 2, second.fetch(:inspected)
    assert_equal 1, second.fetch(:envelope_only)
    assert_equal 1, second.fetch(:missing_both)
    assert_equal false, second.fetch(:has_more)
    assert_nil second.fetch(:next_cursor)

    assert_raises(ArgumentError) do
      preview(owner: @other, limit: 2, cursor: first.fetch(:next_cursor))
    end
    assert_raises(ArgumentError) do
      preview(owner: @client, limit: 2, cursor: first.fetch(:next_cursor))
    end
    assert_raises(ArgumentError) do
      preview(limit: 2, cursor: first.fetch(:next_cursor).reverse)
    end
    intake_cursor = DomainOutbox::BackfillDryRun.preview(owner: @owner, limit: 1)[:next_cursor]
    assert_kind_of String, intake_cursor
    assert_raises(ArgumentError) { preview(limit: 2, cursor: intake_cursor) }
  end

  test "C2.3b7b denies invalid actors page sizes and malformed cursors" do
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

  test "C2.3b7b scan budget ends without a cursor and never restarts automatically" do
    crypto = DomainOutbox::ScopeRevisionBackfillDryRun.send(:encryptor)
    cursor = crypto.encrypt_and_sign(
      {
        "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
        "source_type" => "IntakeScopeRevision",
        "ceiling_id" => @revisions.last.id,
        "after_id" => @revisions.first.id, "scanned" => 249
      },
      purpose: DomainOutbox::ScopeRevisionBackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes
    )
    result = preview(limit: 25, cursor: cursor)
    assert_equal 1, result.fetch(:inspected)
    assert_equal true, result.fetch(:has_more)
    assert_equal true, result.fetch(:scan_budget_exhausted)
    assert_nil result.fetch(:next_cursor)
  end
end
