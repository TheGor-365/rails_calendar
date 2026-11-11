# RC-036 Stage 3 Slice L. All content and identities below are fictional.
# Fake scanner verdicts exist ONLY in Rails test; no development or customer
# attachment can be cleared by this smoke suite.
require "test_helper"
require "tempfile"

class Rc036LocalSmokeTest < ActionDispatch::IntegrationTest
  class TestOnlyScanner
    attr_reader :calls

    def initialize(state:)
      raise "Fake scan is permitted only in Rails test" unless Rails.env.test?

      @state = state
      @calls = 0
    end

    def scan!(_bytes)
      @calls += 1
      Studio::ClamAvScanner::Verdict.new(
        state: @state, engine: "fake-test-only-not-antivirus"
      )
    end

    def readiness!
      true # Mock protocol readiness ONLY. Never evidence of an AV database.
    end
  end

  setup do
    raise "Refuse non-test or S3 smoke mode" unless Rails.env.test? &&
      !Studio::PrivateSourceStorage.s3_backend?

    suffix = SecureRandom.hex(5)
    @password = "rc036-fictional-smoke-password-not-for-production"
    @owner = User.create!(email: "smoke-owner-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @outsider = User.create!(email: "smoke-outsider-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @workspace = Workspace.create!(owner_user: @owner,
      name: "RC036 Synthetic Smoke A", slug: "smoke-a-#{suffix}")
    @foreign = Workspace.create!(owner_user: @outsider,
      name: "RC036 Synthetic Smoke B", slug: "smoke-b-#{suffix}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @outsider,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional client A")
    @different_client = @workspace.clients.create!(display_name: "Fictional client B")
    @foreign_client = @foreign.clients.create!(display_name: "Fictional client C")
    @intake = new_intake(@workspace, @client)
    @different_intake = new_intake(@workspace, @different_client)
    @foreign_intake = new_intake(@foreign, @foreign_client)
    @storage = Studio::PrivateSourceStorage.new
    @keys = []
  end

  teardown do
    @keys.each { |key| @storage.delete!(key: key) }
  end

  test "MD upload to quarantine, queued worker fake clean, scoped HTTP and sanitized health" do
    sign_in(@owner)
    bytes = "# Fictional project\n- [ ] Review synthetic requirements\n"
    source = upload_source(bytes, ".md")
    blob = source.project_source_blob
    assert_equal Digest::SHA256.hexdigest(bytes), source.source_sha256
    assert_equal "quarantined", blob.scan_state
    refute blob.downloadable?
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))

    get download_path(source)
    assert_response :not_found

    post queue_path(source)
    assert_response :accepted
    assert_equal "queued", JSON.parse(response.body).fetch("state")
    assert_equal false, JSON.parse(response.body).fetch("downloadable")
    assert_equal "quarantined", blob.reload.scan_state
    task = blob.studio_source_scan_task
    assert_equal "queued", task.state

    scanner = TestOnlyScanner.new(state: "clean")
    queue = new_queue(scanner)
    assert_equal task.id, queue.enqueue!(
      client: @client, intake: @intake, source_id: source.id
    ).id
    assert_equal 1, queue.process_due!(limit: 2)
    assert_equal 0, queue.process_due!
    assert_equal 1, scanner.calls
    assert_equal "complete_clean", task.reload.state
    assert_equal "clean", blob.reload.scan_state

    get download_path(source)
    assert_response :success
    assert_equal bytes, response.body
    assert_equal "text/markdown", response.media_type
    assert_match(/attachment/, response.headers.fetch("Content-Disposition"))
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    refute_includes response.headers.to_s, blob.object_key

    report = Studio::SourceOperationalAudit.new(
      actor: @owner, workspace: @workspace, scanner: scanner
    ).call
    assert_equal 1, report.fetch(:queue).fetch(:states).fetch("complete_clean")
    assert_equal false, report.fetch(:clamav).fetch(:official_signature_provenance_verified)
    assert_equal false, report.fetch(:production_ready)
    redacted = JSON.generate(report)
    refute_includes redacted, blob.object_key
    refute_includes redacted, @owner.email
    refute_includes redacted, bytes

    sign_out
    get download_path(source)
    assert_redirected_to sign_in_path
    sign_in(@outsider)
    get download_path(source)
    assert_response :not_found
    sign_out
    sign_in(@owner)
    get download_path(source, client: @different_client)
    assert_response :not_found
    get download_path(source, intake: @different_intake)
    assert_response :not_found
    get download_path(source, workspace: @foreign,
      client: @foreign_client, intake: @foreign_intake)
    assert_response :not_found
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get download_path(source)
    assert_response :not_found
  end

  test "TXT fake infected verdict is terminal and never readable over HTTP" do
    sign_in(@owner)
    source = upload_source("synthetic harmful-signature fixture ONLY\n", ".txt")
    get download_path(source)
    assert_response :not_found
    post queue_path(source)
    assert_response :accepted
    scanner = TestOnlyScanner.new(state: "infected")
    queue = new_queue(scanner)
    assert_equal 1, queue.process_due!
    assert_equal 1, scanner.calls
    assert_equal "complete_infected", source.project_source_blob.studio_source_scan_task.reload.state
    assert_equal "infected", source.project_source_blob.reload.scan_state
    assert_not source.project_source_blob.downloadable?
    get download_path(source)
    assert_response :not_found
    assert_equal 0, queue.process_due!
  end

  test "JSON queued source expires without scanning; retention verifies physical removal" do
    sign_in(@owner)
    source = upload_source('{"name":"fictional-only","scope":"smoke"}', ".json")
    key = source.project_source_blob.object_key
    post queue_path(source)
    assert_response :accepted
    scanner = TestOnlyScanner.new(state: "clean")
    queue = new_queue(scanner)
    assert @storage.exists?(key: key)

    travel 8.days do
      assert_equal 1, queue.process_due!
      assert_equal "expired", source.project_source_blob.studio_source_scan_task.reload.state
      assert_equal 0, scanner.calls
      assert_raises(Studio::ProjectSourcePipeline::Denied) do
        Studio::ProjectSourcePipeline.new(
          actor: @owner, workspace: @workspace, storage: @storage, scanner: scanner
        ).download!(client: @client, intake: @intake, source_id: source.id)
      end
      report = Studio::SourceOperationalAudit.new(
        actor: @owner, workspace: @workspace, scanner: scanner
      ).call
      assert_equal 1, report.fetch(:storage_metadata).fetch(:expired_not_revoked)
      retention = Studio::ProjectSourceRetention.new(
        actor: @owner, workspace: @workspace, storage: @storage
      )
      assert_equal 1, retention.sweep_expired!
      assert_equal 0, retention.sweep_expired!
      assert_equal "revoked", source.project_source_blob.reload.scan_state
      refute @storage.exists?(key: key)
      assert_raises(Studio::PrivateSourceStorage::MissingObject) do
        @storage.read!(key: key)
      end
    end
  end

  test "archive signature cannot be smuggled as markdown into quarantine" do
    sign_in(@owner)
    before_count = ProjectSourceBlob.count
    post_source("PK\\x03\\x04test".b, ".md")
    assert_response :unprocessable_entity
    assert_equal before_count, ProjectSourceBlob.count
  end

  private

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client,
      title: "RC036 purely synthetic intake", project_type: "website",
      goal: "A fictional, non-client source-flow test", demo_consent_at: Time.current)
  end

  def post_source(bytes, extension)
    Tempfile.create(["rc036-smoke-", extension]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "application/octet-stream")
      post "#{base}/sources", params: { source_file: upload }
    end
  end

  def upload_source(bytes, extension)
    post_source(bytes, extension)
    assert_response :created
    id = JSON.parse(response.body).fetch("source_id")
    source = @workspace.project_sources.find(id)
    @keys << source.project_source_blob.object_key
    source
  end

  def new_queue(scanner)
    Studio::SourceScanQueue.new(
      actor: @owner, workspace: @workspace, storage: @storage, scanner: scanner
    )
  end

  def base(workspace: @workspace, client: @client, intake: @intake)
    "/workspaces/#{workspace.id}/clients/#{client.id}/project_intakes/#{intake.id}"
  end

  def queue_path(source)
    "#{base}/sources/#{source.id}/queue_scan"
  end

  def download_path(source, workspace: @workspace, client: @client, intake: @intake)
    "#{base(workspace: workspace, client: client, intake: intake)}/sources/#{source.id}/download"
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end

  def sign_out
    delete sign_out_path
    assert_response :redirect
  end
end
