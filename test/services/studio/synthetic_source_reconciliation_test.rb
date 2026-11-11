require "test_helper"

class StudioSyntheticSourceReconciliationTest < ActiveSupport::TestCase
  setup do
    n = SecureRandom.hex(5)
    password = "synthetic-rc038-compare-test-password"
    @owner = User.create!(email: "reconcile-#{n}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @stranger = User.create!(email: "reconcile-other-#{n}@example.test", role: "owner",
      password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner, name: "Fictional compare workspace",
      slug: "reconcile-#{n}")
    @foreign = Workspace.create!(owner_user: @stranger, name: "Other synthetic workspace",
      slug: "reconcile-foreign-#{n}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @stranger, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional client A")
    @other_client = @workspace.clients.create!(display_name: "Fictional client B")
    @intake = new_intake(@workspace, @client)
    @other_intake = new_intake(@workspace, @other_client)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @workspace)
    @preview = Studio::SyntheticSourceReconciliation.new(actor: @owner, workspace: @workspace)
  end

  test "deterministic exact matches are only corroboration, never approved" do
    bytes = "# Fictional\n- [ ] Add contact form\n- [ ] Test upload\n"
    baseline = source(@registry, @client, @intake, "a.md", bytes)
    incoming = source(@registry, @client, @intake, "a.md", bytes)
    original_count = ClientFact.count
    first = reconcile(baseline, incoming)
    assert_equal first, reconcile(baseline, incoming)
    assert_equal "rc038-reconciliation.v1", first.fetch("schema_version")
    assert_equal "complete", first.fetch("coverage")
    assert_equal 2, first.dig("counts", "corroborates")
    assert_equal 0, first.dig("counts", "conflicts")
    assert_equal 0, first.fetch("automatic_supersedes")
    assert_equal false, first.fetch("persisted")
    assert_equal false, first.fetch("approved")
    assert_equal 0, first.fetch("external_calls")
    assert first.fetch("comparisons").all? { |c|
      c.fetch("may_auto_approve") == false && c.fetch("requires_human_review")
    }
    assert_equal original_count, ClientFact.count
  end

  test "JSON pointer changes create review conflicts, unknowns and new claims" do
    old_body = '{"scope":"search","budget":null,"obsolete":"old"}'
    new_body = '{"scope":"checkout","budget":null,"added":"new"}'
    old_ref = source(@registry, @client, @intake, "a.json", old_body)
    new_ref = source(@registry, @client, @intake, "b.json", new_body)
    report = reconcile(old_ref, new_ref)
    by_locator = report.fetch("comparisons").index_by { |c| c.fetch("incoming_locator") }
    assert_equal "conflicts", by_locator.fetch("/scope").fetch("state")
    assert_equal "same_locator_different_claim", by_locator.fetch("/scope").fetch("reason_code")
    assert_equal "unknown", by_locator.fetch("/budget").fetch("state")
    assert_equal "new", by_locator.fetch("/added").fetch("state")
    assert_equal 1, report.fetch("baseline_not_observed_count")
    assert_equal 0, report.fetch("automatic_supersedes")
    assert_equal true, report.fetch("human_decision_required")
  end

  test "an incomplete baseline makes absence unknown, not a new verified requirement" do
    old_body = (1..55).map { |i| "Fictional statement #{i}" }.join("\n") + "\n"
    new_body = "Unmatched fictional new statement\n"
    old_ref = source(@registry, @client, @intake, "a.txt", old_body)
    new_ref = source(@registry, @client, @intake, "b.txt", new_body)
    report = reconcile(old_ref, new_ref)
    assert_equal "partial", report.fetch("coverage")
    assert_equal "unknown", report.fetch("comparisons").first.fetch("state")
    assert_equal 0, report.dig("counts", "new")
    assert_equal 0, report.fetch("automatic_supersedes")
  end

  test "inexact markdown replacement never silently supersedes or approves" do
    old = "# Fictional\n- [ ] Add a contact form\n"
    newer = "# Fictional\n- [ ] Add an appointment form\n"
    a = source(@registry, @client, @intake, "old.md", old)
    b = source(@registry, @client, @intake, "next.md", newer)
    result = reconcile(a, b)
    assert_equal ["conflicts"], result.fetch("comparisons").map { |x| x.fetch("state") }
    assert_equal 0, result.fetch("automatic_supersedes")
    assert result.fetch("comparisons").first.fetch("baseline_fact_id")
  end

  test "foreign workspace, wrong client, revoked owner and quarantine fail closed" do
    body = "Fictional claim only\n"
    a = source(@registry, @client, @intake, "a.txt", body)
    other = source(@registry, @other_client, @other_intake, "b.txt", body)
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      reconcile(a, other)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticSourceReconciliation.new(actor: @stranger, workspace: @workspace)
    end
    assert_raises(ArgumentError) do
      @preview.call(client: @client, intake: @intake,
        baseline: { source_id: a[:source_id], filename: "a.txt", bytes: body, extra: "unsafe" },
        incoming: a, explicit_synthetic: true)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { reconcile(a, a) }
  end

  test "production and absent explicit opt-in are denied without writes" do
    a = source(@registry, @client, @intake, "a.txt", "Only fictional text\n")
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      @preview.call(client: @client, intake: @intake, baseline: a, incoming: a)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticSourceNormalizer::Denied) { reconcile(a, a) }
    end
  end

  test "identical text at another JSON pointer never corroborates an unrelated fact" do
    old_body = '{"project":"same text"}'
    new_body = '{"budget":"same text"}'
    a = source(@registry, @client, @intake, "old.json", old_body)
    b = source(@registry, @client, @intake, "new.json", new_body)
    result = reconcile(a, b)
    assert_equal "unknown", result.fetch("comparisons").first.fetch("state")
    assert_equal "same_text_different_locator",
                 result.fetch("comparisons").first.fetch("reason_code")
    assert_equal 0, result.dig("counts", "corroborates")
    assert_equal 0, result.fetch("automatic_supersedes")
  end

  private

  def reconcile(a, b)
    @preview.call(client: @client, intake: @intake, baseline: a, incoming: b,
                  explicit_synthetic: true)
  end

  def source(registry, client, intake, filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    item = registry.register_preview!(client: client, intake: intake, report: report)
    { source_id: item.id, filename: filename, bytes: bytes }
  end

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Fictional compare",
      project_type: "website", goal: "This is a fictional, non-client requirement.",
      demo_consent_at: Time.current)
  end
end
