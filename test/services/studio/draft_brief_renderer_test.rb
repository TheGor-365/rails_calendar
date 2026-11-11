require "test_helper"

class StudioDraftBriefRendererTest < ActiveSupport::TestCase
  setup do
    pw = "synthetic-renderer-owner-password-12345"
    @owner = User.create!(email: "brief-renderer@example.test", role: "owner",
                          password: pw, password_confirmation: pw)
    @workspace = Workspace.create!(owner_user: @owner, name: "Renderer A", slug: "render-a")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional customer")
    @intake = WorkspaceMemory::ProjectIntakeScope.new(actor: @owner, workspace: @workspace).create_draft!(
      client: @client, title: "Demo <script>unsafe</script>", project_type: "website",
      goal: "Collect test enquiries from test users."
    )
    @report = Studio::SourceInspector.new.call(
      filename: "input.md", bytes: "# Synthetic project\n## Goals\n- [ ] Form test\n"
    )
  end

  test "renders deterministic unapproved markdown with provenance and safe escaped source" do
    renderer = Studio::DraftBriefRenderer.new
    first = renderer.call(intake: @intake, report: @report, actor: @owner)
    second = renderer.call(intake: @intake, report: @report, actor: @owner)
    assert_equal first, second
    assert_includes first, "# Draft discovery brief — NOT APPROVED"
    assert_includes first, @report.fetch("sha256")
    assert_includes first, "Synthetic project"
    assert_includes first, "Form test"
    refute_includes first, "<script>unsafe</script>"
    assert_includes first, "&lt;script&gt;"
    refute_includes first, "Approved price:"
    assert_includes first, "No original file or private content was stored"
  end

  test "cannot render a foreign-owned source brief" do
    wrong = User.create!(email: "renderer-outsider@example.test", role: "owner",
                         password: "synthetic-outsider-password-12345",
                         password_confirmation: "synthetic-outsider-password-12345")
    assert_raises(SecurityError) do
      Studio::DraftBriefRenderer.new.call(intake: @intake, report: @report, actor: wrong)
    end
    assert_raises(ArgumentError) do
      Studio::DraftBriefRenderer.new.call(intake: @intake, report: {}, actor: @owner)
    end
  end
end
