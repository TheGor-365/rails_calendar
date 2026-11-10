require "test_helper"

class StudioSourceScanQueueHttpTest < ActionDispatch::IntegrationTest
  setup do
    @password = "synthetic-queue-http-owner-password"
    @owner = User.create!(email: "queuehttp-owner@example.test", role: "owner",
      password: @password, password_confirmation: @password)
    @other = User.create!(email: "queuehttp-other@example.test", role: "owner",
      password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner, name: "Queue HTTP A", slug: "queue-http-a")
    @foreign_ws = Workspace.create!(owner_user: @other, name: "Queue HTTP B", slug: "queue-http-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @other, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Test Queue")
    @intake = @ws.project_intakes.create!(client: @client, title: "Synthetic queued source",
      project_type: "website", goal: "No real client content", demo_consent_at: Time.current)
    @other_client = @ws.clients.create!(display_name: "Other")
    @other_intake = @ws.project_intakes.create!(client: @other_client, title: "Other synthetic",
      project_type: "website", goal: "No real client content", demo_consent_at: Time.current)
    @store = Studio::PrivateSourceStorage.new
    @source = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @ws, storage: @store)
      .stage!(client: @client, intake: @intake, filename: "http.md",
              bytes: "# Synthetic queued HTTP\n")
  end

  teardown do
    @store.delete!(key: @source.project_source_blob.object_key)
  end

  test "guest and other workspace cannot queue, owner gets pending only" do
    post queue_path
    assert_redirected_to sign_in_path
    sign_in(@other)
    post queue_path
    assert_response :not_found
    delete sign_out_path
    sign_in(@owner)
    post queue_path(intake: @other_intake)
    assert_response :not_found
    post queue_path
    assert_response :accepted
    payload = JSON.parse(response.body)
    assert_equal "queued", payload.fetch("state")
    assert_equal 0, payload.fetch("attempts")
    assert_equal false, payload.fetch("downloadable")
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "quarantined", @source.project_source_blob.reload.scan_state
    assert_equal 1, Studio::SourceScanTask.count

    get "#{base}/sources/#{@source.id}/download"
    assert_response :not_found
  end

  test "production gate always denies queued work" do
    sign_in(@owner)
    Studio::PrivateSourceStorage.stub(:enabled?, false) do
      post queue_path
      assert_response :not_found
    end
    assert_equal 0, Studio::SourceScanTask.count
  end

  private

  def base
    "/workspaces/#{@ws.id}/clients/#{@client.id}/project_intakes/#{@intake.id}"
  end

  def queue_path(intake: @intake)
    "/workspaces/#{@ws.id}/clients/#{@client.id}/project_intakes/#{intake.id}/sources/#{@source.id}/queue_scan"
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end
end
