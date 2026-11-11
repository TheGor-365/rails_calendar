require "test_helper"
require "tempfile"

class StudioProjectSourceQuarantineHttpTest < ActionDispatch::IntegrationTest
  setup do
    @pass = "synthetic-quarantine-owner-password-12345"
    @owner = User.create!(email: "scan-owner@example.test", role: "owner",
      password: @pass, password_confirmation: @pass)
    @other_owner = User.create!(email: "scan-other@example.test", role: "owner",
      password: @pass, password_confirmation: @pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic Quarantine A", slug: "quarantine-a")
    @foreign_ws = Workspace.create!(owner_user: @other_owner, name: "Synthetic Quarantine B", slug: "quarantine-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @other_owner, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Synthetic A")
    @client_b = @ws.clients.create!(display_name: "Synthetic B")
    @foreign_client = @foreign_ws.clients.create!(display_name: "Synthetic C")
    @intake = intake(@ws, @client)
    @intake_b = intake(@ws, @client_b)
    @foreign_intake = intake(@foreign_ws, @foreign_client)
    @keys = []
  end

  teardown do
    store = Studio::PrivateSourceStorage.new
    @keys.each { |key| store.delete!(key: key) }
  end

  test "synthetic upload stays quarantined, then owner can download only after attested scan" do
    sign_in(@owner)
    Tempfile.create(["fictional", ".md"]) do |file|
      file.write("# A purely fictional plan\n- [ ] Check scope\n")
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "application/octet-stream")
      assert_difference "ProjectSourceBlob.count", 1 do
        post "#{base}/sources", params: { source_file: upload }
      end
    end
    assert_response :created
    payload = JSON.parse(response.body)
    id = payload.fetch("source_id")
    assert_equal "quarantined", payload.fetch("state")
    assert_equal false, payload.fetch("downloadable")
    blob = ProjectSourceBlob.find_by!(project_source_id: id)
    @keys << blob.object_key
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_not_includes response.body, "fictional plan"

    get "#{base}/sources/#{id}/download"
    assert_response :not_found
    synthetic_scan!(id, state: "clean")
    assert blob.reload.downloadable?

    get "#{base}/sources"
    assert_response :success
    assert_equal true, JSON.parse(response.body).fetch("sources").sole.fetch("downloadable")
    get "#{base}/sources/#{id}/download"
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, "purely fictional plan"
    assert_match(/attachment/, response.headers.fetch("Content-Disposition"))
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_not_includes response.headers.to_s, blob.object_key
  end

  test "guest, other tenant, swapped client or intake and revoked membership cannot read clean bytes" do
    source = staged_clean
    get "#{base}/sources/#{source.id}/download"
    assert_redirected_to sign_in_path
    sign_in(@other_owner)
    get "#{base}/sources/#{source.id}/download"
    assert_response :not_found
    sign_out
    sign_in(@owner)
    get "#{base(client: @client_b)}/sources/#{source.id}/download"
    assert_response :not_found
    get "#{base(intake: @intake_b)}/sources/#{source.id}/download"
    assert_response :not_found
    get "#{base(ws: @foreign_ws, client: @foreign_client, intake: @foreign_intake)}/sources/#{source.id}/download"
    assert_response :not_found
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get "#{base}/sources/#{source.id}/download"
    assert_response :not_found
  end

  test "missing scanner or infected verdict blocks access" do
    source = stage_source
    assert_raises(Studio::ProjectSourcePipeline::Denied) do
      pipeline.scan!(client: @client, intake: @intake, source_id: source.id)
    end
    assert_equal "failed", source.project_source_blob.reload.scan_state
    sign_in(@owner)
    denied(source)
    synthetic_scan!(source.id, state: "infected")
    assert_equal "infected", source.project_source_blob.reload.scan_state
    denied(source)
  end

  test "missing object and tampered content remain forbidden despite clean prior scan" do
    source = staged_clean
    store = Studio::PrivateSourceStorage.new
    key = source.project_source_blob.object_key
    store.delete!(key: key)
    sign_in(@owner)
    denied(source)
    store.upload!(key: key, bytes: "# tampered\n")
    denied(source)
    assert_equal "revoked", source.project_source_blob.reload.scan_state
  end

  test "expiry blocks a previously clean attachment" do
    source = staged_clean
    sign_in(@owner)
    travel 8.days do
      sign_in(@owner) # owner session expires before the file; test the file gate
      denied(source)
    end
  end

  test "mismatched declared MIME is rejected without a blob" do
    sign_in(@owner)
    Tempfile.create(["fictional", ".md"]) do |file|
      file.write("# synthetic fixture\n")
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "application/pdf")
      assert_no_difference "ProjectSourceBlob.count" do
        post "#{base}/sources", params: { source_file: upload }
      end
    end
    assert_response :unprocessable_entity
  end

  private

  def pipeline(scanner: nil)
    Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @ws, scanner: scanner)
  end

  def stage_source
    source = pipeline.stage!(client: @client, intake: @intake, filename: "synthetic.md",
      bytes: "# synthetic testing only\n")
    @keys << source.project_source_blob.object_key
    source
  end

  def synthetic_scan!(id, state:)
    scanner = Object.new
    scanner.define_singleton_method(:scan!) do |_bytes|
      Studio::ClamAvScanner::Verdict.new(state: state, engine: "synthetic-test-scanner")
    end
    pipeline(scanner: scanner).scan!(client: @client, intake: @intake, source_id: id)
  end

  def staged_clean
    source = stage_source
    synthetic_scan!(source.id, state: "clean")
    source
  end

  def denied(source)
    get "#{base}/sources/#{source.id}/download"
    assert_response :not_found
  end

  def base(ws: @ws, client: @client, intake: @intake)
    "/workspaces/#{ws.id}/clients/#{client.id}/project_intakes/#{intake.id}"
  end

  def intake(ws, client)
    ws.project_intakes.create!(client: client, title: "Synthetic", project_type: "website",
      goal: "A fictional project used only in tests.", demo_consent_at: Time.current)
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @pass }
    assert_redirected_to consultations_path
  end

  def sign_out
    delete sign_out_path
    assert_response :redirect
  end
end
