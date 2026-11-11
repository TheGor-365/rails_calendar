require "test_helper"

class StudioSyntheticReviewReadinessTest < ActiveSupport::TestCase
  setup do
    tag = SecureRandom.hex(5)
    pass = "synthetic-readiness-only-test"
    @owner = User.create!(email: "readiness-owner-#{tag}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @other_owner = User.create!(email: "readiness-other-#{tag}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Fictional readiness",
      slug: "sr-#{tag}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional project customer")
    @intake = @workspace.project_intakes.create!(client: @client,
      title: "Fictional readiness intake", project_type: "website",
      goal: "Only isolated fictional values, no external customer data.",
      demo_consent_at: Time.current)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @workspace)
    @baseline = source('base.json', '{"feature":"search"}')
    @incoming = source('next.json', '{"feature":"search","other":"contact"}')
    @reconciliation = Studio::SyntheticSourceReconciliation.new(
      actor: @owner, workspace: @workspace)
    @triage = Studio::SyntheticReviewTriage.new(actor: @owner, workspace: @workspace)
    @readiness = Studio::SyntheticReviewReadiness.new(
      actor: @owner, workspace: @workspace)
  end

  test "unreviewed synthetic claims block even an unapproved outline proposal" do
    before = Studio::SyntheticReviewDecision.count
    report = compare
    result = readiness(report)
    assert_equal report.fetch("comparisons").size, result.fetch("candidate_count")
    assert_equal 2, result.dig("resolution_counts", "not_reviewed")
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal false, result.fetch("scope_approved")
    assert_equal false, result.fetch("source_content_stored")
    assert_equal 0, result.fetch("billable_usd")
    assert_equal before, Studio::SyntheticReviewDecision.count
    refute_includes result.to_json, "contact"
    refute_includes result.to_json, "search"
  end

  test "exact owner triage permits ONLY planning an unapproved fictional outline review" do
    report = compare
    report.fetch("comparisons").each do |item|
      triage(report, item, "retain_for_review")
    end
    result = readiness(report)
    assert_equal true, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal 2, result.dig("resolution_counts", "retain_for_review")
    assert_equal 0, result.dig("resolution_counts", "not_reviewed")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal false, result.fetch("scope_approved")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal 0, ClientFact.where(workspace: @workspace).count
    assert_equal 0, result.fetch("external_calls")
  end

  test "needs-information and exclusion do not imply safe document readiness" do
    report = compare
    first, last = report.fetch("comparisons")
    triage(report, first, "needs_information")
    triage(report, last, "exclude_from_draft")
    result = readiness(report)
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal 1, result.dig("resolution_counts", "needs_information")
    assert_equal 1, result.dig("resolution_counts", "exclude_from_draft")
  end

  test "conflicting and unknown claims block review planning even after exclusion" do
    original = @incoming
    @incoming = source('conflict.json', '{"feature":"checkout","other":null}')
    report = compare
    assert_includes report.fetch("comparisons").map { |c| c.fetch("state") }, "conflicts"
    assert_includes report.fetch("comparisons").map { |c| c.fetch("state") }, "unknown"
    report.fetch("comparisons").each do |item|
      triage(report, item, "exclude_from_draft")
    end
    result = readiness(report)
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal false, result.fetch("document_generation_allowed")
  ensure
    @incoming = original
  end

  test "stale fingerprints, missing opt-in, production and foreign workspace are denied" do
    report = compare
    assert_raises(Studio::SyntheticReviewReadiness::Conflict) do
      readiness(report, expected_digest: "b" * 64)
    end
    assert_raises(Studio::SyntheticReviewReadiness::Denied) do
      @readiness.call(client: @client, intake: @intake, baseline: @baseline,
        incoming: @incoming, expected_digest: report.fetch("comparison_digest"))
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticReviewReadiness::Denied) { readiness(report) }
    end
    assert_raises(SecurityError) do
      Studio::SyntheticReviewReadiness.new(actor: @other_owner, workspace: @workspace)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { readiness(report) }
  end

  private

  def source(filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    found = @registry.register_preview!(client: @client, intake: @intake, report: report)
    { source_id: found.id, filename: filename, bytes: bytes }
  end

  def compare
    @reconciliation.call(client: @client, intake: @intake,
      baseline: @baseline, incoming: @incoming, explicit_synthetic: true)
  end

  def readiness(report, expected_digest: report.fetch("comparison_digest"))
    @readiness.call(client: @client, intake: @intake,
      baseline: @baseline, incoming: @incoming, expected_digest: expected_digest,
      explicit_synthetic: true)
  end

  def triage(report, item, resolution)
    @triage.call(client: @client, intake: @intake,
      baseline: @baseline, incoming: @incoming,
      expected_digest: report.fetch("comparison_digest"),
      incoming_fact_id: item.fetch("incoming_fact_id"), resolution: resolution,
      confirmation: "REVIEW-SYNTHETIC-#{report.fetch('comparison_digest').first(12)}",
      explicit_synthetic: true)
  end
end
