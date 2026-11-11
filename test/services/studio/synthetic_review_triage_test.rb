require "test_helper"

class StudioSyntheticReviewTriageTest < ActiveSupport::TestCase
  setup do
    n = SecureRandom.hex(6)
    pass = "fictional-review-test-password"
    @owner = User.create!(email: "review-owner-#{n}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @other = User.create!(email: "review-foreign-#{n}@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Fictional owner review", slug: "rv-#{n}")
    @foreign = Workspace.create!(owner_user: @other, name: "Fictional foreign review",
      slug: "rvo-#{n}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional customer")
    @wrong_client = @ws.clients.create!(display_name: "Different fictional customer")
    @intake = @ws.project_intakes.create!(client: @client, title: "Fictional project",
      project_type: "website", goal: "Fictional synthetic-only operator notes.",
      demo_consent_at: Time.current)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
    @a = source("baseline.json", '{"scope":"search","unknown":null}')
    @b = source("incoming.json", '{"scope":"checkout","unknown":null}')
    @preview = Studio::SyntheticSourceReconciliation.new(actor: @owner, workspace: @ws)
    @triage = Studio::SyntheticReviewTriage.new(actor: @owner, workspace: @ws)
  end

  test "conflict human triage produces immutable metadata receipt, not verified facts" do
    report = preview
    candidate = report.fetch("comparisons").find { |c| c.fetch("state") == "conflicts" }
    assert candidate
    old_facts = ClientFact.count
    result = triage(report, candidate, "needs_information")
    assert_equal result, triage(report, candidate, "needs_information")
    assert_equal "synthetic_owner_triage_only", result.fetch("record_type")
    assert_equal false, result.fetch("approved")
    assert_equal false, result.fetch("source_content_stored")
    assert_equal 1, Studio::SyntheticReviewDecision.count
    assert_equal old_facts, ClientFact.count
    row = Studio::SyntheticReviewDecision.first
    assert_equal @ws.id, row.workspace_id
    assert_equal @intake.id, row.project_intake_id
    assert_equal "conflicts", row.candidate_state
    assert_not row.update(resolution: "exclude_from_draft")
    assert_not row.destroy
    assert_raises(Studio::SyntheticReviewTriage::Conflict) do
      triage(report, candidate, "exclude_from_draft")
    end
    refute_includes row.attributes.to_json, "checkout"
    refute_includes row.attributes.to_json, "search"
  end

  test "unknown/null cannot be retained as an accepted claim" do
    report = preview
    item = report.fetch("comparisons").find { |c| c.fetch("state") == "unknown" }
    assert_raises(Studio::SyntheticReviewTriage::Denied) do
      triage(report, item, "retain_for_review")
    end
    assert_equal "needs_information", triage(report, item, "needs_information").fetch("resolution")
  end

  test "changed comparison digest, wrong confirmation and forged fact ID fail closed" do
    report = preview
    candidate = report.fetch("comparisons").first
    assert_raises(Studio::SyntheticReviewTriage::Denied) do
      triage(report, candidate, "needs_information", confirmation: "YES")
    end
    assert_raises(Studio::SyntheticReviewTriage::Conflict) do
      triage(report, candidate, "needs_information", expected_digest: "a" * 64,
             confirmation: "REVIEW-SYNTHETIC-#{'a' * 12}")
    end
    assert_raises(Studio::SyntheticReviewTriage::Denied) do
      triage(report, candidate.merge("incoming_fact_id" => "fact-" + ("0" * 24)),
             "needs_information")
    end
    assert_equal 0, Studio::SyntheticReviewDecision.count
  end

  test "other client/source, foreign owner, revoked membership and production denied" do
    wrong = @ws.project_intakes.create!(client: @wrong_client,
      title: "Different fictional intake", project_type: "website",
      goal: "Another totally fictional project scope.", demo_consent_at: Time.current)
    report = preview
    candidate = report.fetch("comparisons").first
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      @triage.call(client: @wrong_client, intake: wrong, baseline: @a, incoming: @b,
        expected_digest: report.fetch("comparison_digest"),
        incoming_fact_id: candidate.fetch("incoming_fact_id"),
        resolution: "needs_information",
        confirmation: confirm(report), explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticReviewTriage.new(actor: @other, workspace: @ws)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticReviewTriage::Denied) do
        triage(report, candidate, "needs_information")
      end
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { triage(report, candidate, "needs_information") }
    assert_equal 0, Studio::SyntheticReviewDecision.count
  end

  test "SQL foreign tenant/source and check constraint prevent forged triage records" do
    report = preview
    candidate = report.fetch("comparisons").first
    assert_raises(ActiveRecord::InvalidForeignKey) do
      # A rejected PostgreSQL statement poisons the surrounding transaction.
      # Roll back the expected violation to a savepoint before further SQL.
      Studio::SyntheticReviewDecision.transaction(requires_new: true) do
        Studio::SyntheticReviewDecision.insert_all!([{
          workspace_id: @foreign.id, client_id: @client.id, project_intake_id: @intake.id,
          baseline_source_id: @a.fetch(:source_id), incoming_source_id: @b.fetch(:source_id),
          reviewed_by_id: @owner.id, comparison_digest: report.fetch("comparison_digest"),
          incoming_fact_id: candidate.fetch("incoming_fact_id"), candidate_state: "unknown",
          resolution: "needs_information", reviewed_at: Time.current,
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_equal 0, Studio::SyntheticReviewDecision.count
  end

  private

  def source(filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    found = @registry.register_preview!(client: @client, intake: @intake, report: report)
    { source_id: found.id, filename: filename, bytes: bytes }
  end

  def preview
    @preview.call(client: @client, intake: @intake, baseline: @a, incoming: @b,
                  explicit_synthetic: true)
  end

  def confirm(report)
    "REVIEW-SYNTHETIC-#{report.fetch('comparison_digest').first(12)}"
  end

  def triage(report, candidate, resolution, expected_digest: report.fetch("comparison_digest"),
             confirmation: confirm(report))
    @triage.call(client: @client, intake: @intake, baseline: @a, incoming: @b,
      expected_digest: expected_digest, incoming_fact_id: candidate.fetch("incoming_fact_id"),
      resolution: resolution, confirmation: confirmation, explicit_synthetic: true)
  end
end
