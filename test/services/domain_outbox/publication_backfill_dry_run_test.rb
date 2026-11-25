require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxPublicationBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("pub-dry-owner-#{SecureRandom.hex(6)}@example.test")
    @other_owner = make_test_owner("pub-dry-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("pub-dry-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("pub-dry-empty-#{SecureRandom.hex(6)}@example.test")

    @workspace, _, _, caps = approved_profile_for(@owner)
    @other_workspace, _, _, other_caps = approved_profile_for(@other_owner)
    @offering, @version = approved_offering(@workspace, caps.first)
    @foreign_offering, @foreign_version =
      approved_offering(@other_workspace, other_caps.first)
    @other_offering, @other_version = approved_offering(@workspace, caps.first)

    @published = make_publication("publish", @version)
    @unpublished = make_publication("unpublish")
    @published_again = make_publication("publish", @version)
    @unpublished_again = make_publication("unpublish")
    @foreign = @foreign_offering.publications.create!(
      event: "publish", service_offering_version: @foreign_version,
      owner_user: @other_owner
    )
    # Current mutable display pointer deliberately does not reflect history.
    @offering.update!(published_version: nil)

    # Synthetic ephemeral CI-only missing envelope/projection fixtures.
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ServiceOfferingPublication", source_id: @unpublished.id)
      .delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(@published_again, "service_published")).delete_all
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ServiceOfferingPublication", source_id: @unpublished_again.id)
      .delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(@unpublished_again, "service_unpublished")).delete_all
  end

  def approved_offering(workspace, capability)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capability, title: "Fictional private publish audit")
    )
    version = offering.latest_version
    version.update!(approved_at: Time.current)
    offering.update!(approved_version: version)
    [offering, version]
  end

  def make_publication(event, version = nil)
    @offering.publications.create!(
      event: event, owner_user: @owner, service_offering_version: version
    )
  end

  def key(pub, kind)
    "ServiceOfferingPublication:#{pub.id}:#{kind}"
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::PublicationBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7e exact publish and unpublish source matching is aggregate-only, no writes" do
    assert_nil @offering.reload.published_version
    assert_no_difference([
      "ServiceOffering.count", "ServiceOfferingVersion.count",
      "ServiceOfferingPublication.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal({
        source_type: "ServiceOfferingPublication", inspected: 4,
        already_indexed: 1, projection_only: 1, envelope_only: 1,
        missing_both: 1, inconsistent_records: 0,
        ineligible_sources: 0, unexpected_artifacts: 0,
        has_more: false, scan_budget_exhausted: false, next_cursor: nil
      }, result)
      assert_equal result, preview
      assert_equal 1, preview(owner: @other_owner)[:already_indexed]
      assert_equal 1, preview(owner: @other_owner)[:inspected]
      assert_not_includes result.to_json, @version.summary
      assert_not_includes result.to_json, @other_version.title
      assert_not result.key?(:source_id)
      assert_not result.key?(:approved_at)
    end
  end

  test "C2.3b7e outbox version and projected timestamp conflicts are NOT complete" do
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ServiceOfferingPublication", source_id: @published.id)
      .update_all(source_version: 2)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(@unpublished, "service_unpublished"))
      .update_all(occurred_at: @unpublished.created_at + 1.hour)

    assert_no_difference([
      "ServiceOfferingPublication.count", "DomainOutboxEvent.count",
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

  test "C2.3b7e impossible publication owner and foreign version ancestry are ineligible" do
    @published.update_columns(service_offering_version_id: @other_version.id)
    @unpublished.update_columns(owner_user_id: @other_owner.id)
    result = preview
    assert_equal 2, result[:ineligible_sources]
    assert_equal 0, result[:already_indexed]
    assert_equal 0, result[:projection_only]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
  end

  test "C2.3b7e unapproved published version and nonempty unpublish version are invalid" do
    draft_offering = OwnerServices::Catalogue.new(workspace: @workspace)
      .create_draft!(service_fields(@workspace.professional_profile.professional_capabilities.first))
    @published.update_columns(service_offering_version_id: draft_offering.latest_version.id)
    @unpublished.update_columns(service_offering_version_id: @version.id)
    result = preview
    assert_equal 2, result[:ineligible_sources]
    assert_equal 0, result[:already_indexed]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
  end

  test "C2.3b7e artifacts of the opposite publication kind fail closed" do
    DomainOutboxEvent.create!(
      workspace: @workspace, source_type: "ServiceOfferingPublication",
      source_id: @published.id, source_version: 1, kind: "service_unpublished",
      occurred_at: @published.created_at, state: "pending", attempts: 0
    )
    result = preview
    assert_equal 1, result[:unexpected_artifacts]
    assert_equal 1, result[:inconsistent_records]
    assert_equal 0, result[:already_indexed]
    assert_equal 1, result[:projection_only]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
  end

  test "C2.3b7e rejects foreign, guest actors and invalid input" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { preview(owner: actor) }
    end
    [0, -1, 26, 250, "5", nil, 1.5].each do |bad|
      assert_raises(ArgumentError) { preview(limit: bad) }
    end
    ["", "bad-cursor", "x" * 2049, [], 1].each do |bad|
      assert_raises(ArgumentError) { preview(cursor: bad) }
    end
  end

  test "C2.3b7e encrypted cursor enforces owner, source family and page size" do
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

    assert_raises(ArgumentError) do
      preview(owner: @other_owner, limit: 2, cursor: first[:next_cursor])
    end
    assert_raises(ArgumentError) do
      preview(owner: @client, limit: 2, cursor: first[:next_cursor])
    end
    assert_raises(ArgumentError) { preview(limit: 2, cursor: first[:next_cursor].reverse) }

    other = DomainOutbox::BackfillDryRun.send(:encryptor).encrypt_and_sign(
      {
        "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
        "source_type" => "ProjectIntake", "ceiling_id" => 3,
        "after_id" => 1, "scanned" => 1
      },
      purpose: DomainOutbox::BackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes
    )
    assert_raises(ArgumentError) { preview(limit: 2, cursor: other) }
  end

  test "C2.3b7e 250-source cursor budget never auto-renews" do
    crypto = DomainOutbox::PublicationBackfillDryRun.send(:encryptor)
    cursor = crypto.encrypt_and_sign(
      {
        "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
        "source_type" => "ServiceOfferingPublication",
        "ceiling_id" => @unpublished_again.id,
        "after_id" => @published.id, "scanned" => 249
      },
      purpose: DomainOutbox::PublicationBackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes
    )
    result = preview(limit: 25, cursor: cursor)
    assert_equal 1, result[:inspected]
    assert_equal true, result[:has_more]
    assert_equal true, result[:scan_budget_exhausted]
    assert_nil result[:next_cursor]
  end
end
