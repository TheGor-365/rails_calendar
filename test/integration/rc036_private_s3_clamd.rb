# Explicit integration suite: NOT discovered by default "bin/rails test".
# CI must opt in with RC_STUDIO_S3_INTEGRATION_TEST=true and a loopback S3
# endpoint plus a genuine clamd socket. No real customer data or secrets.
require "test_helper"
require "tempfile"
require "net/http"

class Rc036PrivateS3ClamdIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    unless ENV["RC_STUDIO_S3_INTEGRATION_TEST"] == "true" &&
           Studio::PrivateSourceStorage.s3_backend? && Rails.env.test?
      raise "RC-036 integration must run explicitly with isolated S3 and clamd"
    end

    @pass = "synthetic-s3-clamd-only-password-12345"
    @owner = User.create!(email: "s3-owner@example.test", role: "owner",
      password: @pass, password_confirmation: @pass)
    @outsider = User.create!(email: "s3-outsider@example.test", role: "owner",
      password: @pass, password_confirmation: @pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic S3 only", slug: "s3-clamd-test")
    @foreign_workspace = Workspace.create!(owner_user: @outsider, name: "Foreign S3", slug: "s3-foreign-test")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @outsider, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional client A")
    @other_client = @workspace.clients.create!(display_name: "Fictional client B")
    @intake = new_intake(@workspace, @client)
    @other_intake = new_intake(@workspace, @other_client)
    @storage = Studio::PrivateSourceStorage.new
    @keys = []
  end

  teardown do
    @keys.each { |key| @storage.delete!(key: key) }
  end

  test "real MinIO and clamd: quarantine, clean verdict, scoped HTTP attachment, anonymous S3 denied" do
    sign_in(@owner)
    upload_md("# Synthetic approved-for-test text\n", "application/octet-stream")
    assert_response :created
    source_id = JSON.parse(response.body).fetch("source_id")
    blob = ProjectSourceBlob.find_by!(project_source_id: source_id)
    @keys << blob.object_key
    assert_equal "quarantined", blob.scan_state

    get "#{base}/sources/#{source_id}/download"
    assert_response :not_found
    post "#{base}/sources/#{source_id}/scan"
    assert_response :success
    assert_equal "clean", JSON.parse(response.body).fetch("scan_state")
    assert blob.reload.downloadable?

    get "#{base}/sources/#{source_id}/download"
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, "Synthetic approved-for-test text"
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_match(/attachment/, response.headers.fetch("Content-Disposition"))
    refute_includes response.body, blob.object_key

    endpoint = URI(ENV.fetch("RC_STUDIO_S3_ENDPOINT"))
    anonymous = URI("#{endpoint}/#{ENV.fetch("RC_STUDIO_S3_BUCKET")}/#{blob.object_key}")
    assert_equal "403", Net::HTTP.get_response(anonymous).code,
      "An unsigned anonymous S3 GET must not expose quarantine bytes"

    delete sign_out_path
    get "#{base}/sources/#{source_id}/download"
    assert_redirected_to sign_in_path
    sign_in(@outsider)
    get "#{base}/sources/#{source_id}/download"
    assert_response :not_found
    delete sign_out_path
    sign_in(@owner)
    get "#{base(client: @other_client)}/sources/#{source_id}/download"
    assert_response :not_found
    get "#{base(intake: @other_intake)}/sources/#{source_id}/download"
    assert_response :not_found
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get "#{base}/sources/#{source_id}/download"
    assert_response :not_found
  end

  test "real clamd rejects the standard EICAR antivirus test string" do
    # Public-domain industry-standard synthetic antivirus test string.
    eicar = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
    assert_equal 68, eicar.bytesize
    sign_in(@owner)
    upload_txt(eicar, "application/octet-stream")
    assert_response :created
    source_id = JSON.parse(response.body).fetch("source_id")
    blob = ProjectSourceBlob.find_by!(project_source_id: source_id)
    @keys << blob.object_key

    get "#{base}/sources/#{source_id}/download"
    assert_response :not_found
    post "#{base}/sources/#{source_id}/scan"
    assert_response :success
    assert_equal "infected", JSON.parse(response.body).fetch("scan_state")
    assert_not blob.reload.downloadable?
    get "#{base}/sources/#{source_id}/download"
    assert_response :not_found
  end

  test "S3 retention sweep removes expired private object and keeps revoked metadata" do
    source = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @workspace).stage!(
      client: @client, intake: @intake, filename: "synthetic.md",
      bytes: "# Synthetic retention check\n"
    )
    blob = source.project_source_blob
    @keys << blob.object_key
    assert_includes @storage.read!(key: blob.object_key), "retention check"

    travel 8.days do
      sweeper = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @workspace,
        storage: @storage)
      assert_equal 1, sweeper.sweep_expired!
      assert_equal "revoked", blob.reload.scan_state
      assert_raises(Studio::PrivateSourceStorage::MissingObject) { @storage.read!(key: blob.object_key) }
      assert_equal 0, sweeper.sweep_expired!
    end
  end

  private

  def base(workspace: @workspace, client: @client, intake: @intake)
    "/workspaces/#{workspace.id}/clients/#{client.id}/project_intakes/#{intake.id}"
  end

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Fictional S3 test",
      project_type: "website", goal: "Only synthetic data for isolated S3 and clamd integration.",
      demo_consent_at: Time.current)
  end

  def upload_md(body, mime)
    upload_fixture(body, "synthetic.md", mime)
  end

  def upload_txt(body, mime)
    upload_fixture(body, "synthetic.txt", mime)
  end

  def upload_fixture(body, filename, mime)
    Tempfile.create(["studio-ci-", File.extname(filename)]) do |file|
      file.binmode
      file.write(body)
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, mime)
      post "#{base}/sources", params: { source_file: upload }
    end
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @pass }
    assert_redirected_to consultations_path
  end
end
