require "test_helper"

class StudioSyntheticRequirementTracePreviewTest < ActiveSupport::TestCase
  setup do
    tag = SecureRandom.hex(5)
    password = "fictional-trace-test-only"
    @owner = User.create!(email: "trace-owner-#{tag}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @foreign_owner = User.create!(email: "trace-foreign-#{tag}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Fictional trace workspace", slug: "trace-#{tag}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner",
      status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional trace client")
    @intake = @workspace.project_intakes.create!(client: @client,
      title: "Fictional trace project", project_type: "website",
      goal: "Only fictional trace data in the isolated test database.",
      demo_consent_at: Time.current)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @workspace)
    @baseline = source("base.json", '{"project":"calendar"}')
    @incoming = source("next.json", '{"project":"calendar","feature":"search"}')
    @compare = Studio::SyntheticSourceReconciliation.new(actor: @owner,
      workspace: @workspace)
    @triage = Studio::SyntheticReviewTriage.new(actor: @owner, workspace: @workspace)
    @preview = Studio::SyntheticRequirementTracePreview.new(actor: @owner,
      workspace: @workspace)
  end

  test "untriaged candidates produce no trace and never approve or generate" do
    comparison = reconcile
    facts_before = ClientFact.count
    receipts_before = Studio::SyntheticReviewDecision.count

    result = trace(comparison)
    assert_equal 2, result.fetch("candidate_count")
    assert_equal 0, result.fetch("retained_trace_count")
    assert_equal [], result.fetch("trace_candidates")
    assert_equal 2, result.dig("resolution_counts", "not_reviewed")
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal false, result.fetch("requirement_approved")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal false, result.fetch("source_content_stored")
    assert_equal false, result.fetch("persisted")
    assert_equal 0, result.fetch("billable_usd")
    assert_equal facts_before, ClientFact.count
    assert_equal receipts_before, Studio::SyntheticReviewDecision.count
  end

  test "retained fictional claims have stable exact source and owner receipt references only" do
    comparison = reconcile
    comparison.fetch("comparisons").each { |row| review(comparison, row, "retain_for_review") }
    fact_count = ClientFact.count
    before = Studio::SyntheticReviewDecision.count

    result = trace(comparison)
    assert_equal result, trace(comparison)
    assert_equal 2, result.fetch("retained_trace_count")
    assert_equal true, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal %w[corroborates new],
      result.fetch("trace_candidates").map { |row| row.fetch("candidate_state") }
    assert_equal comparison.fetch("comparisons").map { |c| c.fetch("incoming_segment_id") },
      result.fetch("trace_candidates").map { |c| c.fetch("incoming_segment_id") }
    assert result.fetch("trace_candidates").all? { |row|
      row.fetch("incoming_source_id") == @incoming.fetch(:source_id) &&
        row.fetch("owner_triage_receipt_id").is_a?(Integer) &&
        row.fetch("requirement_status") == "unapproved_candidate"
    }
    assert_equal false, result.fetch("requirement_approved")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal fact_count, ClientFact.count
    assert_equal before, Studio::SyntheticReviewDecision.count
    refute_includes result.to_json, '"calendar"'
    refute_includes result.to_json, '"search"'
  end

  test "clarification and exclusion block outline readiness and omit excluded trace" do
    comparison = reconcile
    items = comparison.fetch("comparisons")
    review(comparison, items.first, "retain_for_review")
    review(comparison, items.last, "exclude_from_draft")

    result = trace(comparison)
    assert_equal 1, result.fetch("retained_trace_count")
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
    assert_equal false, result.fetch("document_generation_allowed")
  end

  test "source conflicts cannot become retained requirement candidates" do
    @incoming = source("conflict.json", '{"project":"checkout"}')
    comparison = reconcile
    row = comparison.fetch("comparisons").first
    assert_equal "conflicts", row.fetch("state")
    assert_raises(Studio::SyntheticReviewTriage::Denied) do
      review(comparison, row, "retain_for_review")
    end
    review(comparison, row, "needs_information")
    result = trace(comparison)
    assert_equal 0, result.fetch("retained_trace_count")
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_outline_review")
  end

  test "stale digest, foreign owner, revoked membership and production fail closed" do
    comparison = reconcile
    assert_raises(Studio::SyntheticReviewReadiness::Conflict) do
      trace(comparison, expected_digest: "c" * 64)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticRequirementTracePreview.new(actor: @foreign_owner,
        workspace: @workspace)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticReviewReadiness::Denied) do
        trace(comparison)
      end
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { trace(comparison) }
  end

  private

  def source(filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    row = @registry.register_preview!(client: @client, intake: @intake, report: report)
    { source_id: row.id, filename: filename, bytes: bytes }
  end

  def reconcile
    @compare.call(client: @client, intake: @intake, baseline: @baseline,
      incoming: @incoming, explicit_synthetic: true)
  end

  def trace(comparison, expected_digest: comparison.fetch("comparison_digest"))
    @preview.call(client: @client, intake: @intake, baseline: @baseline,
      incoming: @incoming, expected_digest: expected_digest, explicit_synthetic: true)
  end

  def review(comparison, candidate, resolution)
    @triage.call(client: @client, intake: @intake, baseline: @baseline,
      incoming: @incoming, expected_digest: comparison.fetch("comparison_digest"),
      incoming_fact_id: candidate.fetch("incoming_fact_id"), resolution: resolution,
      confirmation: "REVIEW-SYNTHETIC-#{comparison.fetch('comparison_digest').first(12)}",
      explicit_synthetic: true)
  end
end
