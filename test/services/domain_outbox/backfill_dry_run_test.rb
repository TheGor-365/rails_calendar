require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("backfill-preview-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("backfill-preview-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("backfill-preview-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("backfill-preview-empty-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @intakes = 4.times.map do |i|
      ProjectIntake.create!(
        workspace: @workspace,
        title: "Fictional backfill candidate #{i}",
        project_type: "rails_bugfix",
        goal: "Synthetic audit of a historical intake without source-data export.",
        demo_consent_at: Time.current
      )
    end
    @foreign = ProjectIntake.create!(
      workspace: @other_workspace,
      title: "Private foreign project must never leak",
      project_type: "rails_bugfix",
      goal: "Synthetic foreign-workspace source must be invisible.",
      demo_consent_at: Time.current
    )

    # Deliberately damaged SYNTHETIC test DB only, after real callbacks:
    # four possible source/outbox/activity reconciliation classifications.
    DomainOutboxEvent.where(workspace_id: @workspace.id, source_type: "ProjectIntake",
      source_id: @intakes[1].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: "ProjectIntake:#{@intakes[2].id}:intake_created").delete_all
    DomainOutboxEvent.where(workspace_id: @workspace.id, source_type: "ProjectIntake",
      source_id: @intakes[3].id).delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: "ProjectIntake:#{@intakes[3].id}:intake_created").delete_all
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::BackfillDryRun.preview(owner: owner, limit: limit, cursor: cursor)
  end

  test "C2.3b7a scans only bounded canonical intake IDs and classifies without any writes" do
    assert_no_difference([
      "ProjectIntake.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal({
        source_type: "ProjectIntake", inspected: 4,
        already_indexed: 1, projection_only: 1,
        envelope_only: 1, missing_both: 1,
        has_more: false, scan_budget_exhausted: false,
        next_cursor: nil
      }, result)
      assert_equal result, preview
      assert_equal 1, preview(owner: @other)[:already_indexed]
      assert_equal 1, preview(owner: @other)[:inspected]
      assert_not_includes result.to_json, @foreign.title
      assert_not_includes result.to_json, @intakes.first.title
      assert_equal %i[already_indexed envelope_only has_more inspected missing_both
        next_cursor projection_only scan_budget_exhausted source_type], result.keys.sort
    end
  end

  test "C2.3b7a encrypted cursor paginates only its owner and pinned source ceiling" do
    first = preview(limit: 2)
    assert_equal 2, first[:inspected]
    assert first[:has_more]
    assert_kind_of String, first[:next_cursor]
    assert_operator first[:next_cursor].length, :>, 64
    assert_not_equal @intakes[1].id.to_s, first[:next_cursor]
    assert_equal [1, 1, 0, 0], [
      first[:already_indexed], first[:projection_only],
      first[:envelope_only], first[:missing_both]
    ]

    second = preview(limit: 2, cursor: first[:next_cursor])
    assert_equal [0, 0, 1, 1], [
      second[:already_indexed], second[:projection_only],
      second[:envelope_only], second[:missing_both]
    ]
    assert_equal 2, second[:inspected]
    assert_equal false, second[:has_more]
    assert_nil second[:next_cursor]

    assert_raises(ArgumentError) do
      preview(owner: @other, limit: 2, cursor: first[:next_cursor])
    end
    assert_raises(ArgumentError) do
      preview(owner: @client, limit: 2, cursor: first[:next_cursor])
    end
    assert_raises(ArgumentError) do
      preview(limit: 2, cursor: first[:next_cursor].reverse)
    end
  end

  test "C2.3b7a refuses malformed roles, oversized pages and invalid cursors" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { preview(owner: actor) }
    end
    [0, -1, 26, 100, "5", 2.5, nil].each do |invalid|
      assert_raises(ArgumentError) { preview(limit: invalid) }
    end
    ["", "not-an-encrypted-cursor", "a" * 2049, [], 123].each do |invalid|
      assert_raises(ArgumentError) { preview(cursor: invalid) }
    end
  end

  test "C2.3b7a single-chain scan budget is fail-closed without a new cursor" do
    # Synthetic cursor directly exercises the 250-source safety boundary:
    # 1 remaining source in this chain with more than one available.
    key = DomainOutbox::BackfillDryRun::CURSOR_PURPOSE
    crypto = DomainOutbox::BackfillDryRun.send(:encryptor)
    cursor = crypto.encrypt_and_sign(
      {
        "owner_user_id" => @owner.id,
        "workspace_id" => @workspace.id,
        "source_type" => "ProjectIntake",
        "ceiling_id" => @intakes.last.id,
        "after_id" => @intakes.first.id,
        "scanned" => 249
      },
      purpose: key, expires_in: 15.minutes
    )
    result = preview(limit: 25, cursor: cursor)
    assert_equal 1, result[:inspected]
    assert_equal true, result[:has_more]
    assert_equal true, result[:scan_budget_exhausted]
    assert_nil result[:next_cursor]
  end
end
