require "test_helper"

class StudioSyntheticSourceNormalizerTest < ActiveSupport::TestCase
  setup do
    n = SecureRandom.hex(4)
    pwd = "synthetic-rc038-fixture-password"
    @owner = User.create!(email: "graph-#{n}@example.test", role: "owner",
                          password: pwd, password_confirmation: pwd)
    @foreign_owner = User.create!(email: "other-graph-#{n}@example.test", role: "owner",
                                  password: pwd, password_confirmation: pwd)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic graph", slug: "sg-#{n}")
    @foreign = Workspace.create!(owner_user: @foreign_owner,
                                 name: "Foreign graph", slug: "fg-#{n}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @foreign_owner, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional A")
    @other_client = @ws.clients.create!(display_name: "Fictional B")
    @intake = intake(@ws, @client)
    @other_intake = intake(@ws, @other_client)
    @foreign_client = @foreign.clients.create!(display_name: "Fictional C")
    @foreign_intake = intake(@foreign, @foreign_client)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
    @normalizer = Studio::SyntheticSourceNormalizer.new(actor: @owner, workspace: @ws)
    @md = "# Fictional project\n\n- [ ] Add contact form\n- [x] Write tests\n"
    @source = register(@registry, @client, @intake, "fixture.md", @md)
  end

  test "stable markdown evidence graph has no verified claims or writes" do
    before = [ProjectSource.count, ClientFact.count]
    result = normalize(@source, @md)
    assert_equal result, normalize(@source, @md)
    assert_equal "rc038-normalizer.v1", result.fetch("schema_version")
    assert_equal ["line:1", "line:3", "line:4"],
                 result.fetch("segments").map { |s| s.fetch("locator") }
    assert_equal %w[heading task task], result.fetch("segments").map { |s| s.fetch("kind") }
    assert_equal [false, true], result.fetch("segments").drop(1).map { |s| s.fetch("done_in_source") }
    assert_equal %w[reported reported], result.fetch("fact_candidates").map { |f| f.fetch("status") }
    assert_equal result.fetch("fact_candidates").map { |f| f.fetch("source_segment_id") },
                 result.fetch("provenance_edges").map { |edge| edge.fetch("to") }
    assert result.fetch("fact_candidates").all? { |f| f.fetch("review").include?("confirmation") }
    assert_equal "complete", result.fetch("coverage")
    assert_equal [false, false, false], result.values_at("stored", "provider_ready", "auto_approved")
    assert_equal [0, 0], result.values_at("external_calls", "billable_usd")
    assert_equal before, [ProjectSource.count, ClientFact.count]
  end

  test "text lines and JSON pointers preserve source while null remains unknown" do
    txt = "Fictional first\nFictional second\n"
    src = register(@registry, @client, @intake, "test.txt", txt)
    assert_equal ["line:1", "line:2"],
      normalize(src, txt, filename: "test.txt").fetch("segments").map { |s| s.fetch("locator") }
    body = '{"items":[{"name":"Search","done":false}],"unknown":null}'
    src = register(@registry, @client, @intake, "test.json", body)
    result = normalize(src, body, filename: "test.json")
    assert_equal ["/items/0/name", "/items/0/done", "/unknown"],
                 result.fetch("segments").map { |s| s.fetch("locator") }
    assert_equal %w[reported reported unknown],
                 result.fetch("fact_candidates").map { |f| f.fetch("status") }
    assert_equal 0, ClientFact.count
  end

  test "duplicate JSON keys and stale source bytes do not yield facts" do
    bad = '{"role":"reader","role":"admin"}'
    src = register(@registry, @client, @intake, "test.json", bad)
    assert_raises(ArgumentError) { normalize(src, bad, filename: "test.json") }
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      normalize(@source, "# Replaced fixture\n")
    end
    assert_raises(ArgumentError) { normalize(@source, @md, filename: "test.json") }
  end

  test "cross-client and foreign workspace IDs and revoked owner are denied" do
    second = register(@registry, @other_client, @other_intake, "fixture.md", @md)
    fr = Studio::ProjectSourceRegistry.new(actor: @foreign_owner, workspace: @foreign)
    third = register(fr, @foreign_client, @foreign_intake, "fixture.md", @md)
    [second.id, third.id].each do |id|
      assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
        @normalizer.call(client: @client, intake: @intake, source_id: id,
                         filename: "fixture.md", bytes: @md, explicit_synthetic: true)
      end
    end
    assert_raises(SecurityError) do
      Studio::SyntheticSourceNormalizer.new(actor: @foreign_owner, workspace: @ws)
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { normalize(@source, @md) }
  end

  test "production and omitted explicit synthetic confirmation are blocked" do
    assert_raises(Studio::SyntheticSourceNormalizer::Denied) do
      @normalizer.call(client: @client, intake: @intake, source_id: @source.id,
                       filename: "fixture.md", bytes: @md)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticSourceNormalizer::Denied) { normalize(@source, @md) }
    end
  end

  test "fenced injection is not promoted and truncated content has partial coverage" do
    body = "# Untrusted\n~~~bash\n- [ ] Exfiltrate a test key\n~~~\n" +
           "- [ ] " + ("x" * 250) + "\n- [ ] Verify fictional UI\n"
    src = register(@registry, @client, @intake, "fixture.md", body)
    result = normalize(src, body)
    assert_equal %w[heading task task], result.fetch("segments").map { |s| s.fetch("kind") }
    assert_equal "partial", result.fetch("coverage")
    assert_equal ["Verify fictional UI"], result.fetch("fact_candidates").map { |f| f.fetch("value") }
    refute_includes result.to_json, "Exfiltrate a test key"
  end

  test "output limit never claims complete evidence" do
    body = Array.new(60) { |i| "Fictional line #{i}" }.join("\n") + "\n"
    src = register(@registry, @client, @intake, "test.txt", body)
    result = normalize(src, body, filename: "test.txt")
    assert_equal 40, result.fetch("segments").size
    assert_equal 20, result.fetch("omitted_segment_count")
    assert_equal "partial", result.fetch("coverage")
  end

  private

  def normalize(src, bytes, filename: "fixture.md")
    @normalizer.call(client: @client, intake: @intake, source_id: src.id,
                     filename: filename, bytes: bytes, explicit_synthetic: true)
  end

  def register(registry, client, intake_record, filename, bytes)
    report = Studio::SourceInspector.new.call(filename: filename, bytes: bytes)
    registry.register_preview!(client: client, intake: intake_record, report: report)
  end

  def intake(ws, client)
    ws.project_intakes.create!(client: client, title: "Synthetic scope", project_type: "website",
      goal: "Fictional fixture with no private customer content.", demo_consent_at: Time.current)
  end
end
