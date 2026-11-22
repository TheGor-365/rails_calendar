require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxInvitationTransitionBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("inv-dry-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("inv-dry-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("inv-dry-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("inv-dry-empty-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)

    @issued = make_invitation(@workspace)
    @claimed = make_invitation(@workspace)
    claim!(@claimed)
    @submitted = make_invitation(@workspace)
    claim!(@submitted)
    @submitted.update!(submitted_at: Time.current)
    @revoked = make_invitation(@workspace)
    @revoked.update!(revoked_at: Time.current)
    @foreign = make_invitation(@other_workspace)

    # Ephemeral test fixtures only. Four transition reconciliation outcomes:
    # issued: both; claimed: projection-only; submitted: envelope-only;
    # revoked: missing both. Other valid transitions remain fully indexed.
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ClientRequestInvitation", source_id: @claimed.id,
      kind: "invitation_claimed").delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(@submitted, "invitation_submitted")).delete_all
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ClientRequestInvitation", source_id: @revoked.id,
      kind: "invitation_revoked").delete_all
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(@revoked, "invitation_revoked")).delete_all
  end

  def make_invitation(workspace)
    workspace.client_request_invitations.create!(
      token_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      seed_title: "Fictional invitation for dry-run",
      seed_project_type: "rails_bugfix",
      seed_goal: "Fictional goal deliberately excluded from dry-run output.",
      service_version_ids: [], client_fact_reviews: {},
      brief_selections: {}, brief_decisions: {},
      expires_at: 48.hours.from_now
    )
  end

  def claim!(invitation)
    intake = ProjectIntake.create!(
      workspace: invitation.workspace, client_user: @client,
      title: "Fictional claimed project", project_type: "rails_bugfix",
      goal: "Fictional client project linked to synthetic invitation.",
      demo_consent_at: Time.current
    )
    invitation.update!(
      claimed_at: Time.current,
      claimed_by_user: @client,
      project_intake: intake
    )
  end

  def key(invitation, kind)
    "ClientRequestInvitation:#{invitation.id}:#{kind}"
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::InvitationTransitionBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7d reconciles four transition kinds, without false absent events or writes" do
    counts = [
      "ClientRequestInvitation.count", "ProjectIntake.count",
      "DomainOutboxEvent.count", "ActivityEvent.count",
      "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]
    assert_no_difference(counts) do
      result = preview
      assert_equal({
        source_type: "ClientRequestInvitation",
        inspected_invitations: 4, expected_transitions: 8,
        already_indexed: 5, projection_only: 1, envelope_only: 1,
        missing_both: 1, inconsistent_records: 0,
        ineligible_invitations: 0, unexpected_artifacts: 0,
        has_more: false, scan_budget_exhausted: false, next_cursor: nil
      }, result)
      assert_equal result, preview
      foreign = preview(owner: @other)
      assert_equal 1, foreign[:inspected_invitations]
      assert_equal 1, foreign[:expected_transitions]
      assert_equal 1, foreign[:already_indexed]
      assert_not_includes result.to_json, @issued.seed_goal
      assert_not_includes result.to_json, @foreign.token_digest
      assert_not result.key?(:source_id)
      assert_not result.key?(:token_digest)
    end
  end

  test "C2.3b7d wrong kind/version, occurred_at and projection metadata are inconsistent" do
    issued = @issued
    claimed = @claimed
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ClientRequestInvitation", source_id: issued.id,
      kind: "invitation_issued").update_all(source_version: 88)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: key(claimed, "invitation_claimed"))
      .update_all(occurred_at: claimed.claimed_at + 1.hour)
    result = preview
    assert_equal 2, result[:inconsistent_records]
    assert_equal 3, result[:already_indexed]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
    assert_equal 0, result[:projection_only]
  end

  test "C2.3b7d invalid chronology and foreign claimed intake are not candidates" do
    @claimed.update_columns(claimed_at: @claimed.created_at - 1.second)
    other_intake = ProjectIntake.create!(
      workspace: @other_workspace, client_user: @client,
      title: "Fictional foreign link", project_type: "rails_bugfix",
      goal: "Synthetic foreign link must not be seen as eligible.",
      demo_consent_at: Time.current
    )
    @submitted.update_columns(project_intake_id: other_intake.id)

    assert_no_difference([
      "DomainOutboxEvent.count", "ActivityEvent.count",
      "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 2, result[:ineligible_invitations]
      assert_equal 4, result[:inspected_invitations]
      # Every invalid source consumes one invitation scan slot but is NOT
      # counted as an eligible transition.
      assert_equal 3, result[:expected_transitions]
      assert_equal 2, result[:already_indexed]
      assert_equal 1, result[:missing_both]
    end
  end

  test "C2.3b7d cannot invent submit without claim or revoke after claim" do
    # Intentional fictional historical corruption in ephemeral CI DB only.
    @issued.update_columns(submitted_at: Time.current)
    @claimed.update_columns(revoked_at: Time.current)

    assert_no_difference([
      "ClientRequestInvitation.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      result = preview
      assert_equal 2, result[:ineligible_invitations]
      assert_equal 4, result[:inspected_invitations]
      assert_equal 5, result[:expected_transitions]
      assert_equal 3, result[:already_indexed]
      assert_equal 1, result[:envelope_only]
      assert_equal 1, result[:missing_both]
    end
  end

  test "C2.3b7d impossible extra artifacts are surfaced, not backfilled" do
    DomainOutboxEvent.create!(
      workspace: @issued.workspace,
      source_type: "ClientRequestInvitation", source_id: @issued.id,
      kind: "invitation_claimed", source_version: 2,
      occurred_at: Time.current, state: "pending", attempts: 0
    )
    result = preview
    assert_equal 1, result[:unexpected_artifacts]
    assert_equal 8, result[:expected_transitions]
  end

  test "C2.3b7d cross-tenant and family-encrypted cursor rejection" do
    first = preview(limit: 2)
    assert_equal 2, first[:inspected_invitations]
    assert_equal 3, first[:expected_transitions]
    assert first[:has_more]
    assert_kind_of String, first[:next_cursor]
    assert_operator first[:next_cursor].bytesize, :<=, 2048

    second = preview(limit: 2, cursor: first[:next_cursor])
    assert_equal 2, second[:inspected_invitations]
    assert_equal 5, second[:expected_transitions]
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
    another_family = DomainOutbox::BackfillDryRun.preview(owner: @owner, limit: 1)[:next_cursor]
    assert_kind_of String, another_family
    assert_raises(ArgumentError) { preview(limit: 2, cursor: another_family) }
  end

  test "C2.3b7d invalid actors, sizes and cursors fail closed" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { preview(owner: actor) }
    end
    [nil, 0, -1, 26, 300, "5", 1.5].each do |bad|
      assert_raises(ArgumentError) { preview(limit: bad) }
    end
    ["", "not-a-cursor", "x" * 2049, 5, []].each do |bad|
      assert_raises(ArgumentError) { preview(cursor: bad) }
    end
  end

  test "C2.3b7d 250-source scan budget never renews cursor automatically" do
    crypto = DomainOutbox::InvitationTransitionBackfillDryRun.send(:encryptor)
    cursor = crypto.encrypt_and_sign(
      {
        "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
        "source_type" => "ClientRequestInvitation",
        "ceiling_id" => @revoked.id, "after_id" => @issued.id,
        "scanned" => 249
      },
      purpose: DomainOutbox::InvitationTransitionBackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes
    )
    result = preview(limit: 25, cursor: cursor)
    assert_equal 1, result[:inspected_invitations]
    assert_equal true, result[:has_more]
    assert_equal true, result[:scan_budget_exhausted]
    assert_nil result[:next_cursor]
  end
end
