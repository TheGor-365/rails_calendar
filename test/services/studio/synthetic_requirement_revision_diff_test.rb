require "test_helper"

class StudioSyntheticRequirementRevisionDiffTest < ActiveSupport::TestCase
  setup do
    tag = SecureRandom.hex(5)
    password = "synthetic-revision-diff-password"
    @owner = User.create!(email: "diff-owner-#{tag}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @other_owner = User.create!(email: "diff-foreign-#{tag}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @ws = Workspace.create!(owner_user: @owner, name: "Fictional diff",
      slug: "diff-#{tag}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner,
      role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional diff client")
    @other_client = @ws.clients.create!(display_name: "Different fictional client")
    @intake = @ws.project_intakes.create!(client: @client,
      title: "Fictional revision study", project_type: "website",
      goal: "Synthetic-only in-memory revision evidence", demo_consent_at: Time.current)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
    @reconciliation = Studio::SyntheticSourceReconciliation.new(actor: @owner, workspace: @ws)
    @triage = Studio::SyntheticReviewTriage.new(actor: @owner, workspace: @ws)
    @service = Studio::SyntheticRequirementRevisionDiff.new(actor: @owner, workspace: @ws)
    @baseline = source('base.json', '{}')
  end

  test "changed whole-source digest does not invent changes to identical localized claims" do
    previous = snapshot(@baseline, source('one.json', '{"feature":"search","scope":"mobile"}'))
    current = snapshot(@baseline, source('two.json',
      '{"feature":"search","scope":"mobile","extra":"accessibility"}'))
    retain_all(previous)
    retain_all(current)

    facts_before = ClientFact.count
    result = compare(previous, current)
    assert_equal result, compare(previous, current)
    assert_equal true, result.fetch("eligible_for_unapproved_synthetic_diff_review")
    assert_equal 3, result.fetch("delta_count")
    assert_equal 2, result.dig("delta_counts", "unchanged_unverified")
    assert_equal 1, result.dig("delta_counts", "newly_retained_unverified")
    assert_equal 0, result.dig("delta_counts", "changed_unverified")
    assert result.fetch("deltas").all? { |row|
      row.fetch("requires_owner_and_client_review") &&
        row.fetch("may_auto_approve") == false &&
        row.fetch("may_auto_supersede") == false
    }
    assert_equal false, result.fetch("requirement_approved")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal false, result.fetch("persisted")
    assert_equal facts_before, ClientFact.count
    refute_includes result.to_json, '"search"'
    refute_includes result.to_json, '"mobile"'
    refute_includes result.to_json, '"accessibility"'
  end

  test "changed claim at same locator requires review and does not supersede" do
    previous = snapshot(@baseline, source('one.json', '{"feature":"search"}'))
    current = snapshot(@baseline, source('two.json', '{"feature":"checkout"}'))
    retain_all(previous)
    retain_all(current)

    result = compare(previous, current)
    assert_equal 1, result.dig("delta_counts", "changed_unverified")
    assert_equal false, result.fetch("automatic_supersession")
    assert_equal false, result.fetch("scope_approved")
    assert_equal false, result.fetch("document_generation_allowed")
  end

  test "no longer retained is not an automatic deletion or proof of removal" do
    previous = snapshot(@baseline, source('one.json', '{"feature":"search","scope":"mobile"}'))
    current = snapshot(@baseline, source('two.json', '{"feature":"search"}'))
    retain_all(previous)
    retain_all(current)

    result = compare(previous, current)
    assert_equal 1, result.dig("delta_counts", "no_longer_retained_unverified")
    assert_equal false, result.fetch("automatic_deletion")
    assert_equal false, result.fetch("document_generation_allowed")
  end

  test "unreviewed or needs-information snapshot blocks the diff entirely" do
    previous = snapshot(@baseline, source('one.json', '{"feature":"search"}'))
    current = snapshot(@baseline, source('two.json', '{"feature":"checkout"}'))
    retain_all(previous)
    result = compare(previous, current)
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_diff_review")
    assert_equal "owner_triage_or_coverage_incomplete", result.fetch("blocked_reason")
    assert_equal 0, result.fetch("delta_count")
    assert_equal [], result.fetch("deltas")

    candidate = current.fetch(:comparison).fetch("comparisons").first
    triage(current, candidate, "needs_information")
    result = compare(previous, current)
    assert_equal false, result.fetch("eligible_for_unapproved_synthetic_diff_review")
    assert_equal 0, result.fetch("delta_count")
  end

  test "wrong source digest, foreign client, revoked owner and production deny" do
    previous = snapshot(@baseline, source('one.json', '{"feature":"search"}'))
    current = snapshot(@baseline, source('two.json', '{"feature":"search"}'))
    retain_all(previous)
    retain_all(current)

    stale = current.merge(expected_digest: "f" * 64)
    assert_raises(Studio::SyntheticReviewReadiness::Conflict) do
      compare(previous, stale)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticRequirementRevisionDiff.new(actor: @other_owner, workspace: @ws)
    end
    # The forged client is in this workspace, but the source+intake pair
    # belongs to another client. Scoped normalizer denies the lookup.
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      @service.call(client: @other_client, intake: @intake,
        previous: previous.except(:comparison), current: current.except(:comparison),
        explicit_synthetic: true)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticRequirementRevisionDiff::Denied) do
        compare(previous, current)
      end
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { compare(previous, current) }
  end

  private

  def source(filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    registered = @registry.register_preview!(client: @client, intake: @intake, report: report)
    { source_id: registered.id, filename: filename, bytes: bytes }
  end

  def snapshot(baseline, incoming)
    comparison = @reconciliation.call(client: @client, intake: @intake,
      baseline: baseline, incoming: incoming, explicit_synthetic: true)
    { baseline: baseline, incoming: incoming,
      expected_digest: comparison.fetch("comparison_digest"),
      comparison: comparison }
  end

  def triage(snapshot, candidate, resolution)
    @triage.call(client: @client, intake: @intake,
      baseline: snapshot.fetch(:baseline), incoming: snapshot.fetch(:incoming),
      expected_digest: snapshot.fetch(:expected_digest),
      incoming_fact_id: candidate.fetch("incoming_fact_id"),
      resolution: resolution,
      confirmation: "REVIEW-SYNTHETIC-#{snapshot.fetch(:expected_digest).first(12)}",
      explicit_synthetic: true)
  end

  def retain_all(snapshot)
    snapshot.fetch(:comparison).fetch("comparisons").each do |row|
      triage(snapshot, row, "retain_for_review")
    end
  end

  def compare(previous, current)
    @service.call(client: @client, intake: @intake,
      previous: previous.except(:comparison), current: current.except(:comparison),
      explicit_synthetic: true)
  end
end
