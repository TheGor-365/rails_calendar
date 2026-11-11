require "test_helper"

class StudioSyntheticDocumentRevisionImpactTest < ActiveSupport::TestCase
  setup do
    tag = SecureRandom.hex(5)
    password = "fictional-change-control-test-password"
    @owner = User.create!(email: "impact-owner-#{tag}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @stranger = User.create!(email: "impact-other-#{tag}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @ws = Workspace.create!(owner_user: @owner, name: "Fictional document impact",
      slug: "impact-#{tag}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner",
      status: "active")
    @client = @ws.clients.create!(display_name: "Fictional document impact client")
    @intake = @ws.project_intakes.create!(client: @client,
      title: "Fictional document revision", project_type: "website",
      goal: "Only invented source claims, never a customer document.",
      demo_consent_at: Time.current)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
    @reconciliation = Studio::SyntheticSourceReconciliation.new(actor: @owner,
      workspace: @ws)
    @triage = Studio::SyntheticReviewTriage.new(actor: @owner, workspace: @ws)
    @service = Studio::SyntheticDocumentRevisionImpact.new(actor: @owner,
      workspace: @ws)
    @baseline = source("base.json", "{}")
  end

  test "changed fictional claim produces deterministic gated change-control packet" do
    before = snapshot("before.json", '{"feature":"search"}')
    after = snapshot("after.json", '{"feature":"checkout"}')
    retain_all(before)
    retain_all(after)
    facts_before = ClientFact.count
    receipts_before = Studio::SyntheticReviewDecision.count

    first = impact(before, after)
    assert_equal first, impact(before, after)
    assert_equal "manual_change_assessment_pending", first.fetch("review_state")
    assert_equal true, first.fetch("source_review_complete")
    assert_equal 1, first.fetch("change_count")
    assert_equal "changed_unverified", first.fetch("review_queue").first.fetch("classification")
    assert_equal false, first.fetch("review_report_id_is_authorization")
    assert_equal "pending", first.fetch("review_queue").first.fetch("owner_review_state")
    assert_equal "not_requested", first.fetch("review_queue").first.fetch("client_confirmation_state")
    assert_equal false, first.fetch("automatic_document_revision")
    assert_equal false, first.fetch("scope_approved")
    assert_equal false, first.fetch("client_confirmed")
    assert_equal false, first.fetch("document_generation_allowed")
    assert_equal false, first.fetch("persisted")
    assert_equal 0, first.fetch("external_calls")
    assert_equal 0, first.fetch("billable_usd")
    assert_equal 9, first.fetch("artifact_review_candidates").length
    assert first.fetch("document_generation_gates").all? { |gate| gate.fetch("state") == "blocked" }
    assert_equal facts_before, ClientFact.count
    assert_equal receipts_before, Studio::SyntheticReviewDecision.count
    refute_includes first.to_json, '"search"'
    refute_includes first.to_json, '"checkout"'
  end

  test "unchanged reviewed candidate yields no change request or artifact revision" do
    before = snapshot("before.json", '{"feature":"search"}')
    after = snapshot("after.json", '{"feature":"search"}')
    retain_all(before)
    retain_all(after)

    result = impact(before, after)
    assert_equal "no_change_observed_not_verified", result.fetch("review_state")
    assert_equal 0, result.fetch("change_count")
    assert_equal [], result.fetch("review_queue")
    assert_equal [], result.fetch("artifact_review_candidates")
    assert_equal false, result.fetch("automatic_document_revision")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal 9, result.fetch("document_generation_gates").size
  end

  test "no longer retained is a review question, never deletion authorization" do
    before = snapshot("before.json", '{"feature":"search","scope":"mobile"}')
    after = snapshot("after.json", '{"feature":"search"}')
    retain_all(before)
    retain_all(after)

    result = impact(before, after)
    assert_equal 1, result.fetch("change_count")
    row = result.fetch("review_queue").sole
    assert_equal "no_longer_retained_unverified", row.fetch("classification")
    assert_equal false, row.fetch("deletion_authorized")
    assert_equal false, result.fetch("automatic_deletion")
    assert_equal false, result.fetch("automatic_supersession")
  end

  test "unreviewed or needs-information evidence prevents any change packet" do
    before = snapshot("before.json", '{"feature":"search"}')
    after = snapshot("after.json", '{"feature":"checkout"}')
    retain_all(before)
    result = impact(before, after)
    assert_equal "blocked_unresolved_source_review", result.fetch("review_state")
    assert_equal false, result.fetch("source_review_complete")
    assert_equal [], result.fetch("review_queue")
    assert_equal [], result.fetch("artifact_review_candidates")

    triage(after, after.fetch(:comparison).fetch("comparisons").first,
      "needs_information")
    result = impact(before, after)
    assert_equal "blocked_unresolved_source_review", result.fetch("review_state")
    assert_equal false, result.fetch("document_generation_allowed")
  end

  test "stale digest, foreign owner, revoked membership and production deny" do
    before = snapshot("before.json", '{"feature":"search"}')
    after = snapshot("after.json", '{"feature":"checkout"}')
    retain_all(before)
    retain_all(after)

    assert_raises(Studio::SyntheticReviewReadiness::Conflict) do
      impact(before, after.merge(expected_digest: "e" * 64))
    end
    assert_raises(SecurityError) do
      Studio::SyntheticDocumentRevisionImpact.new(actor: @stranger, workspace: @ws)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticDocumentRevisionImpact::Denied) do
        impact(before, after)
      end
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { impact(before, after) }
  end

  private

  def source(filename, bytes)
    inspected = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    registered = @registry.register_preview!(client: @client, intake: @intake,
      report: inspected)
    { source_id: registered.id, filename: filename, bytes: bytes }
  end

  def snapshot(filename, bytes)
    incoming = source(filename, bytes)
    compare = @reconciliation.call(client: @client, intake: @intake,
      baseline: @baseline, incoming: incoming, explicit_synthetic: true)
    { baseline: @baseline, incoming: incoming,
      expected_digest: compare.fetch("comparison_digest"), comparison: compare }
  end

  def triage(snapshot, candidate, resolution)
    @triage.call(client: @client, intake: @intake,
      baseline: snapshot.fetch(:baseline), incoming: snapshot.fetch(:incoming),
      expected_digest: snapshot.fetch(:expected_digest),
      incoming_fact_id: candidate.fetch("incoming_fact_id"), resolution: resolution,
      confirmation: "REVIEW-SYNTHETIC-#{snapshot.fetch(:expected_digest).first(12)}",
      explicit_synthetic: true)
  end

  def retain_all(snapshot)
    snapshot.fetch(:comparison).fetch("comparisons").each do |candidate|
      triage(snapshot, candidate, "retain_for_review")
    end
  end

  def impact(previous, current)
    @service.call(client: @client, intake: @intake,
      previous: previous.except(:comparison), current: current.except(:comparison),
      explicit_synthetic: true)
  end
end
