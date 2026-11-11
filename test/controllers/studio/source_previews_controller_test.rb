require "test_helper"
require "tempfile"

class StudioSourcePreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "synthetic-owner-private-password-12345"
    @alice = User.create!(email: "studio-alice@example.test", role: "owner",
                          password: @password, password_confirmation: @password)
    @bob = User.create!(email: "studio-bob@example.test", role: "owner",
                        password: @password, password_confirmation: @password)
    @a = Workspace.create!(owner_user: @alice, name: "Synthetic Project Studio A", slug: "preview-studio-a")
    @b = Workspace.create!(owner_user: @bob, name: "Synthetic Project Studio B", slug: "preview-studio-b")
    WorkspaceMembership.create!(workspace: @a, user: @alice, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @b, user: @bob, role: "owner", status: "active")
    ca = @a.clients.create!(display_name: "Synthetic client A")
    cb = @b.clients.create!(display_name: "Synthetic client B")
    @intake = WorkspaceMemory::ProjectIntakeScope.new(actor: @alice, workspace: @a).create_draft!(
      client: ca, title: "Synthetic Landing", project_type: "website",
      goal: "Create a fictional project brief for source preview."
    )
    @foreign = WorkspaceMemory::ProjectIntakeScope.new(actor: @bob, workspace: @b).create_draft!(
      client: cb, title: "Other Synthetic Project", project_type: "website",
      goal: "No customer information should cross this boundary."
    )
  end

  test "owner-only studio is not accessible to guests or other workspace owners" do
    get workspace_source_preview_path(@a, @intake)
    assert_redirected_to sign_in_path

    sign_in(@bob)
    get workspace_source_preview_path(@a, @intake)
    assert_response :not_found
    get workspace_source_preview_path(@b, @foreign)
    assert_response :success
    assert_select "h1", "Inspect a project source"
    assert_match(/private, no-store/, response.headers.fetch("Cache-Control"))

    sign_out
    sign_in(@alice)
    get workspace_source_preview_path(@a, @intake)
    assert_response :success
    assert_select "input[type='file'][name='source_file']"
    assert_select "turbo-frame#studio_preview"
  end

  test "synthetic markdown POST previews structure without creating persistent source data" do
    sign_in(@alice)
    initial = @intake.reload.attributes
    with_upload("# Fictional Brief\n## Scope\n- [ ] Contact form\n", ".md") do |upload|
      post workspace_source_preview_path(@a, @intake), params: { source_file: upload }
    end
    assert_response :success
    assert_select "h2", /Source outline/
    assert_select "strong", "Fictional Brief"
    assert_select "strong", "Scope"
    assert_select ".rc-record", /Contact form/
    assert_select ".rc-record", /Discovery brief/
    assert_select ".rc-notice", /untrusted evidence/
    assert_equal initial, @intake.reload.attributes
    assert_no_match(/<script>/, response.body)
  end

  test "owner can download an unapproved MD brief from a synthetic source" do
    sign_in(@alice)
    with_upload("# Fictional Roadmap\n## Scope\n- [ ] Document traceability\n", ".md") do |upload|
      post workspace_source_preview_path(@a, @intake),
           params: { source_file: upload, intent: "download" }
    end
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match(/attachment/, response.headers.fetch("Content-Disposition"))
    assert_match(/discovery-unapproved\.md/, response.headers.fetch("Content-Disposition"))
    assert_includes response.body, "# Draft discovery brief — NOT APPROVED"
    assert_includes response.body, "Document traceability"
    assert_includes response.body, "Source SHA256:"
    refute_includes response.body, "Approved price:"
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "nonallowlisted uploads or oversized content fail without persistence" do
    sign_in(@alice)
    with_upload("Fake PDF", ".pdf") do |upload|
      post workspace_source_preview_path(@a, @intake), params: { source_file: upload }
    end
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /Unsupported source format/

    with_upload("a" * (Studio::SourceInspector::MAX_BYTES + 1), ".md") do |upload|
      post workspace_source_preview_path(@a, @intake), params: { source_file: upload }
    end
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /too large/
  end

  test "legacy intake routes cannot expose a workspace-owned intake via ID guessing" do
    sign_in(@alice)
    get project_intake_path(@foreign)
    assert_response :not_found
    get project_intake_quiz_path(@foreign)
    assert_response :not_found
    get adaptive_project_intake_quiz_path(@foreign)
    assert_response :not_found
    post reply_project_intake_path(@intake), params: { answer: "Synthetic message" }
    assert_response :not_found
    post acknowledge_project_intake_path(@intake)
    assert_response :not_found

    get project_intake_path(@intake)
    assert_response :success
    assert_select "a[href='#{workspace_source_preview_path(@a, @intake)}']"
    get admin_project_intakes_path
    assert_response :success
    assert_select "body", text: /Other Synthetic Project/, count: 0
  end

  test "legacy administrator cannot edit a client-scoped project" do
    post admin_session_path, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_response :redirect
    get project_intake_path(@intake)
    assert_response :not_found
    post draft_spec_admin_project_intake_path(@intake)
    assert_response :not_found
  end


  test "preview refuses production even for owner; no unscanned bytes are parsed" do
    sign_in(@alice)
    Rails.env.stub(:production?, true) do
      get workspace_source_preview_path(@a, @intake)
      assert_response :not_found
      with_upload("# Purely fake\n", ".md") do |upload|
        post workspace_source_preview_path(@a, @intake), params: { source_file: upload }
      end
      assert_response :not_found
    end
    assert_equal 0, ProjectSourceBlob.count
  end

  test "untrusted markdown HTML is escaped and never persisted or converted to active JS" do
    sign_in(@alice)
    assert_no_difference "ProjectSourceBlob.count" do
      with_upload("# <img src=x onerror=alert(1)>\n- [ ] <script>alert(2)</script>\n", ".md") do |upload|
        post workspace_source_preview_path(@a, @intake), params: { source_file: upload }
      end
    end
    assert_response :success
    assert_match(/&lt;img src=x onerror=alert\(1\)&gt;/, response.body)
    assert_match(/&lt;script&gt;alert\(2\)&lt;\/script&gt;/, response.body)
    assert_no_match(/<img src=x onerror=/, response.body)
    assert_no_match(/<script>alert\(2\)<\/script>/, response.body)
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end

  def sign_out
    delete sign_out_path
    assert_response :redirect
  end

  def with_upload(contents, ext)
    Tempfile.create(["studio-fake", ext]) do |file|
      file.binmode
      file.write(contents)
      file.flush
      yield Rack::Test::UploadedFile.new(file.path, "application/octet-stream")
    end
  end
end
