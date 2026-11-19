require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"
require "uri"

class E2ClientInvitationTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @prior_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"
    @owner = make_test_owner("e2-own-#{SecureRandom.hex(5)}@example.test")
    @owner_b = make_test_owner("e2-other-#{SecureRandom.hex(5)}@example.test")
    @client = make_test_client("e2-client-#{SecureRandom.hex(5)}@example.test")
    @client_b = make_test_client("e2-other-client-#{SecureRandom.hex(5)}@example.test")
    @workspace, _, _, caps = approved_profile_for(@owner)
    @workspace_b, _, _, = approved_profile_for(@owner_b)
    @offering = published_service(@workspace, caps.first)
    @seed = "Owner's unverified confidential synthetic requirements for a Rails form."
  end

  teardown do
    @prior_pilot.nil? ? ENV.delete("RC_LOCAL_CLIENT_REQUESTS_ENABLED") : ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
    @prior_ai.nil? ? ENV.delete("RC_GROK_ENABLED") : ENV["RC_GROK_ENABLED"] = @prior_ai
  end

  test "owner invitation is scoped, one-time digest only and never lists another owner seed" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.order(:id).last
    assert_equal @workspace, invitation.workspace
    assert_equal 64, raw.length
    assert_equal ClientRequestInvitation.digest_for(raw), invitation.token_digest
    refute_equal raw, invitation.token_digest
    assert_equal :invited, invitation.state
    get owner_invitations_path
    assert_response :success
    assert_select "#e2-invite-link", count: 0 # link available only immediately after issue
    sign_out
    login(@owner_b)
    get owner_invitations_path
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(invitation.seed_title)}/, count: 0
    post revoke_owner_invitation_path(invitation)
    assert_response :not_found
  end

  test "guest sees public preview only; verified claim leads to one editable canonical intake" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.order(:id).last
    sign_out

    assert_no_difference("ProjectIntake.count") do
      get client_invitation_path
      assert_response :success
      assert_select "form[action=?]", client_invitation_preview_path
      post client_invitation_preview_path, params: { invite_token: raw }
      assert_redirected_to client_invitation_preview_path
      get client_invitation_preview_path
      assert_response :success
      assert_select "body", text: /#{Regexp.escape(@seed)}/, count: 0
      assert_select "body", text: /#{Regexp.escape(@offering.published_version.title)}/
    end

    login(@client)
    assert_redirected_to client_invitation_preview_path
    assert_difference("ProjectIntake.count", 1) do
      assert_difference("IntakeServiceSelection.count", 1) do
        post claim_client_invitation_path, params: { demo_consent: "1" }
      end
    end
    intake = @client.client_project_intakes.last
    assert_redirected_to edit_client_request_path(intake)
    assert_equal @workspace.id, intake.workspace_id
    assert_equal [@offering.published_version_id], intake.selected_service_offering_versions.pluck(:id)
    assert_equal 0, intake.client_message_count
    assert_equal 1, intake.intake_brief_revisions.count
    owner_brief = intake.latest_brief_revision
    assert_equal "owner", owner_brief.author_role
    assert_equal({ "tasks" => %w[bugfix tests], "backend" => ["rails"] }, owner_brief.selections)
    assert_equal({ "deployment" => "client" }, owner_brief.decisions)
    assert_equal "Synthetic test job", owner_brief.notes
    assert_equal @client.id, invitation.reload.claimed_by_user_id
    assert_equal intake.id, invitation.project_intake_id
    get client_invitation_preview_path
    assert_response :success
    assert_select "a[href=?]", edit_client_request_path(intake)

    assert_no_difference("ProjectIntake.count") do
      post claim_client_invitation_path, params: { demo_consent: "1" }
      assert_redirected_to edit_client_request_path(intake)
    end
    assert_no_difference("IntakeMessage.count") do
      post submit_client_request_path(intake)
      assert_response :unprocessable_entity
    end
    patch client_request_path(intake), params: {
      project_intake: {
        title: "Client revised the test task", project_type: "rails_bugfix",
        goal: "Client now requests a synthetic form with two named acceptance scenarios."
      },
      fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
      brief: {
        selections: { tasks: ["bugfix"], backend: ["rails"], frontend: ["bootstrap"] },
        decisions: { deployment: "owner" }, notes: "Please improve the mobile form first."
      }
    }
    assert_redirected_to edit_client_request_path(intake)
    assert_equal 2, intake.intake_brief_revisions.count
    assert_equal "client", intake.latest_brief_revision.author_role
    assert_equal({ "frontend" => ["bootstrap"] }, intake.latest_brief_revision.selections.slice("frontend"))
    assert_equal({ "deployment" => "owner" }, intake.latest_brief_revision.decisions)
    assert_equal "owner", intake.intake_brief_revisions.find_by!(version: 1).author_role
    assert_equal %w[bugfix tests], intake.intake_brief_revisions.find_by!(version: 1).selections.fetch("tasks")
    assert_equal "Client revised the test task", intake.reload.title
    assert_equal @seed, invitation.reload.seed_goal
    assert_equal "unknown", invitation.fact_state("goal")
    assert_equal "confirmed", invitation.fact_state("title")

    assert_difference("IntakeMessage.count", 2) do
      post submit_client_request_path(intake)
    end
    assert_redirected_to client_request_path(intake)
    assert invitation.reload.submitted_at.present?
    assert_equal 1, intake.client_message_count
    assert_no_difference("IntakeMessage.count") { post submit_client_request_path(intake) }
  end

  test "different client cannot claim, alter or view someone else's invitation draft" do
    login(@owner)
    raw = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw }
    login(@client)
    post claim_client_invitation_path, params: { demo_consent: "1" }
    intake = @client.client_project_intakes.last
    sign_out
    login(@client_b)
    get client_request_path(intake)
    assert_response :not_found
    get edit_client_request_path(intake)
    assert_response :not_found
    patch client_request_path(intake), params: { project_intake: { title: "Forgery" } }
    assert_response :not_found
    post claim_client_invitation_path, params: { demo_consent: "1" }
    assert_response :conflict
    assert_equal @client.id, ClientRequestInvitation.last.claimed_by_user_id
    assert_equal 1, ClientRequestInvitation.last.project_intake.intake_service_selections.count
  end

  test "expired revoked and invalid invitations do not create intakes" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.last
    invitation.update!(expires_at: 1.minute.ago)
    sign_out
    assert_no_difference("ProjectIntake.count") do
      post client_invitation_preview_path, params: { invite_token: raw }
      assert_response :gone
      post client_invitation_preview_path, params: { invite_token: "a" * 64 }
      assert_response :not_found
      post client_invitation_preview_path, params: { invite_token: "wrong" }
      assert_response :not_found
    end

    login(@owner)
    raw2 = issue_invitation
    second = ClientRequestInvitation.last
    post revoke_owner_invitation_path(second)
    assert_redirected_to owner_invitations_path
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw2 }
    assert_response :gone
    assert second.reload.revoked_at.present?
  end

  test "cross-owner published versions cannot be embedded in an owner draft" do
    login(@owner)
    other, _, _, caps = approved_profile_for(@owner_b, version: 2)
    foreign = published_service(other, caps.first)
    assert_no_difference("ClientRequestInvitation.count") do
      post owner_invitations_path, params: {
        proposal: proposal, service_version_ids: [foreign.published_version_id]
      }
      assert_response :unprocessable_entity
    end
  end

  private

  def proposal
    { seed_title: "Fictional Rails form change", seed_project_type: "rails_bugfix", seed_goal: @seed }
  end

  def issue_invitation
    post owner_invitations_path, params: {
      proposal: proposal.merge(
        brief_selections: { tasks: %w[bugfix tests], backend: ["rails"] },
        brief_decisions: { deployment: "client" },
        brief_notes: "Synthetic test job"
      ),
      service_version_ids: [@offering.published_version_id]
    }
    assert_redirected_to owner_invitations_path
    follow_redirect!
    assert_response :success
    element = css_select("#e2-invite-link").first
    assert element, "one-time owner copyable link missing"
    url = element["value"]
    match = URI(url).fragment.to_s.match(/\Atoken=([0-9a-f]{64})\z/)
    assert match, "token should appear only in fragment"
    match[1]
  end

  def published_service(workspace, capability)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capability, title: "Fix a synthetic Rails form")
    )
    version = offering.latest_version
    version.update!(approved_at: Time.current)
    offering.update!(approved_version: version, published_version: version)
    offering
  end

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "owner" ? workspace_path :
                         (ClientRequestInvitation.exists? && response.headers["Location"].include?("invite") ?
                           client_invitation_preview_path : client_home_path))
  end

  def sign_out
    delete sign_out_path
    assert_redirected_to root_path
  end
end
