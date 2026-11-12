require "test_helper"

class StudioOfflineRunHttpTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(5)
    @password = "rc037-synthetic-run-http-password"
    @owner = User.create!(email: "run-http-owner-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @foreign_owner = User.create!(email: "run-http-other-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic HTTP run workspace",
      slug: "run-http-#{suffix}")
    @foreign = Workspace.create!(owner_user: @foreign_owner, name: "Foreign HTTP run workspace",
      slug: "run-http-other-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @foreign_owner,
      role: "owner", status: "active")
    client = @ws.clients.create!(display_name: "Entirely fictional run client")
    @intake = @ws.project_intakes.create!(client: client,
      title: "Fictional offline run", project_type: "website",
      goal: "No external AI, customer documents or real cost.",
      demo_consent_at: Time.current)
    other_client = @foreign.clients.create!(display_name: "Foreign fictional client")
    other_intake = @foreign.project_intakes.create!(client: other_client,
      title: "Unrelated fictional project", project_type: "website",
      goal: "Completely synthetic and unrelated source.",
      demo_consent_at: Time.current)
    @source = source_for(workspace: @ws, client: client, intake: @intake, actor: @owner,
      contents: "# Synthetic allowed metadata source\n")
    @foreign_source = source_for(workspace: @foreign, client: other_client,
      intake: other_intake, actor: @foreign_owner,
      contents: "# Private foreign fictional source\n")
  end

  test "preview stays ephemeral; separate explicit record and one review persist with zero billable data" do
    sign_in(@owner)
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    assert_no_difference "Studio::OfflineRun.count" do
      post preview_path, params: { purpose: "clarify", source_ids: [@source.id.to_s] }
      assert_response :success
      assert_select "form[action='#{runs_path}']", 1
      assert_select "form[action='#{runs_path}'] input[name='source_ids[]'][value='#{@source.id}']", 1
    end

    assert_difference "Studio::OfflineRun.count", 1 do
      post runs_path, params: { purpose: "clarify", source_ids: [@source.id.to_s],
        provider: "openai", estimated_usd: "999", external_consent: "true" }
      assert_redirected_to settings_path
    end
    run = @ws.studio_offline_runs.sole
    assert_equal 1, run.version
    assert_equal 1, run.verified_payload!.fetch(:source_metadata_count)
    assert_equal 0, run.verified_payload!.fetch(:billable_usd)
    assert_equal false, run.verified_payload!.fetch(:auto_approved)
    assert_not_includes run.attributes.to_json, "Synthetic allowed metadata source"

    get settings_path
    assert_response :success
    assert_select "[aria-label='Synthetic run history']", text: /Version 1/
    assert_select "form[action='#{review_path(run)}']", 1
    assert_not_includes response.body, run.event_digest

    assert_difference "Studio::OfflineRunReview.count", 1 do
      post review_path(run), params: { decision: "reviewed_synthetic" }
      assert_redirected_to settings_path
    end
    review = run.reload.review
    assert_equal "reviewed_synthetic", review.decision
    assert review.verify!
    get settings_path
    assert_response :success
    assert_select "[aria-label='Synthetic run history']", text: /Reviewed synthetic/
    assert_select "form[action='#{review_path(run)}']", 0
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")

    assert_no_difference "Studio::OfflineRunReview.count" do
      post review_path(run), params: { decision: "discarded_synthetic" }
      assert_response :unprocessable_entity
    end
  end

  test "invalid source, forged decision and disabled policy do not persist" do
    sign_in(@owner)
    post runs_path, params: { purpose: "clarify" }
    assert_response :unprocessable_entity
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    [
      { source_ids: [@foreign_source.id.to_s] },
      { source_ids: [@source.id.to_s, @source.id.to_s] },
      { source_ids: ["/etc/passwd"] },
      { source_ids: "1" },
      { source_ids: (1..11).map(&:to_s) },
      { purpose: "steal_all_data" }
    ].each do |attrs|
      assert_no_difference "Studio::OfflineRun.count" do
        post runs_path, params: { purpose: "clarify" }.merge(attrs)
        assert_response :unprocessable_entity
      end
    end
    post runs_path, params: { purpose: "clarify" }
    assert_redirected_to settings_path
    run = @ws.studio_offline_runs.sole
    assert_no_difference "Studio::OfflineRunReview.count" do
      post review_path(run), params: { decision: "approve_client_scope" }
      assert_response :unprocessable_entity
    end
  end

  test "guest, foreign owner, revoked membership and production receive no access" do
    post runs_path, params: { purpose: "clarify" }
    assert_redirected_to sign_in_path
    sign_in(@foreign_owner)
    post runs_path, params: { purpose: "clarify" }
    assert_response :not_found
    post "/workspaces/#{@foreign.id}/project_intakes/#{@intake.id}/offline_runs",
      params: { purpose: "clarify" }
    assert_response :not_found
    delete sign_out_path

    sign_in(@owner)
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    post runs_path, params: { purpose: "clarify" }
    assert_redirected_to settings_path
    run = @ws.studio_offline_runs.sole
    Rails.env.stub(:production?, true) do
      post runs_path, params: { purpose: "clarify" }
      assert_response :not_found
      post review_path(run), params: { decision: "reviewed_synthetic" }
      assert_response :not_found
    end
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    post runs_path, params: { purpose: "clarify" }
    assert_response :not_found
    post review_path(run), params: { decision: "reviewed_synthetic" }
    assert_response :not_found
  end

  test "tampered stored output is never exposed on screen or accepted for review" do
    sign_in(@owner)
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    post runs_path, params: { purpose: "clarify" }
    assert_redirected_to settings_path
    run = @ws.studio_offline_runs.sole
    run.update_columns(output_payload: run.output_payload.merge("text" => "UNTRUSTED FORGED RESPONSE"))
    get settings_path
    assert_response :success
    assert_select "[aria-label='Synthetic run history']", text: /Integrity check failed/
    assert_select "form[action='#{review_path(run)}']", 0
    assert_not_includes response.body, "UNTRUSTED FORGED RESPONSE"
    post review_path(run), params: { decision: "reviewed_synthetic" }
    assert_response :not_found
  end

  private

  def source_for(workspace:, client:, intake:, actor:, contents:)
    inspection = Studio::SourceInspector.new.call(filename: "synthetic.md", bytes: contents)
    Studio::ProjectSourceRegistry.new(actor: actor, workspace: workspace)
      .register_preview!(client: client, intake: intake, report: inspection)
  end

  def settings_path
    "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/ai_settings"
  end

  def preview_path
    "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/offline_proposal"
  end

  def runs_path
    "/workspaces/#{@ws.id}/project_intakes/#{@intake.id}/offline_runs"
  end

  def review_path(run)
    "#{runs_path}/#{run.id}/review"
  end

  def sign_in(actor)
    post account_session_path, params: { email: actor.email, password: @password }
    assert_redirected_to consultations_path
  end
end
