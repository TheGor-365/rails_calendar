require "test_helper"

class StudioClientOnboardingHttpTest < ActionDispatch::IntegrationTest
  setup do
    @password = "synthetic-owner-password-for-client-test"
    @client_password = "synthetic-client-password-12345678"
    @owner = User.create!(email: "scope-owner@example.test", role: "owner",
                          password: @password, password_confirmation: @password)
    @other = User.create!(email: "scope-other@example.test", role: "owner",
                          password: @password, password_confirmation: @password)
    @ws = Workspace.create!(owner_user: @owner, name: "Client-onboarding A", slug: "client-onboard-a")
    @foreign_ws = Workspace.create!(owner_user: @other, name: "Client-onboarding B", slug: "client-onboard-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @other, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional Client")
    @other_client = @ws.clients.create!(display_name: "Fictional Other Client")
    @foreign_client = @foreign_ws.clients.create!(display_name: "Fictional Foreign Client")
    @intake = make_intake(@ws, @client, "Fictional scoped project")
    @other_intake = make_intake(@ws, @other_client, "Different customer project")
    @foreign_intake = make_intake(@foreign_ws, @foreign_client, "Foreign project")
    @issuer = Studio::ProjectInvitationIssuer.new(actor: @owner, workspace: @ws)
    @invitation = @issuer.issue!(client: @client, intake: @intake,
                                 recipient_email: "receiver@example.test")
    ActionMailer::Base.deliveries.clear
  end

  test "token alone, wrong mailbox, absent consent, or unverified code cannot create client account" do
    assert_no_difference({"Studio::ClientAccount.count" => 0, "Studio::ClientProjectGrant.count" => 0}) do
      signup
    end
    assert_response :unprocessable_entity

    confirm_mailbox
    assert_no_difference({"Studio::ClientAccount.count" => 0, "Studio::ClientProjectGrant.count" => 0}) do
      signup(consent_confirmation: "no")
    end
    assert_response :unprocessable_entity

    assert_no_difference({"Studio::ClientAccount.count" => 0, "Studio::ClientProjectGrant.count" => 0}) do
      signup(email: "attacker@example.test")
    end
    assert_response :unprocessable_entity
  end

  test "verified mailbox + password + explicit consent creates isolated session and one project-only grant" do
    confirm_mailbox
    assert_difference "Studio::ClientAccount.count", 1 do
      assert_difference "Studio::ClientProjectGrant.count", 1 do
        signup
      end
    end
    assert_response :created
    grant = Studio::ClientProjectGrant.sole
    account = Studio::ClientAccount.sole
    assert account.authenticate(@client_password)
    assert_equal "studio_review_v1", grant.consent_policy
    assert_equal @client.id, grant.client_id
    assert_equal @intake.id, grant.project_intake_id
    assert_equal "active", grant.status
    assert_equal "active", account.status
    assert_equal false, @invitation.invitation.reload.redeemable?
    assert_equal "pending", @invitation.invitation.status
    assert_equal 0, WorkspaceMembership.where(role: "client").count
    assert_equal 0, User.where(role: "client").count
    refute account.attributes.values.include?("receiver@example.test")
    refute account.attributes.values.include?(@invitation.token)

    get "/studio/client_projects"
    assert_response :success
    data = JSON.parse(response.body).fetch("projects")
    assert_equal [grant.id], data.pluck("grant_id")
    assert_equal ["Fictional scoped project"], data.pluck("title")
    assert_not_includes response.body, "raw_source"
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))

    get "/studio/client_projects/#{grant.id}"
    assert_response :success
    assert_equal false, JSON.parse(response.body).fetch("downloadable")
    get "/studio/client_projects/9999999"
    assert_response :not_found

    # Owner-only existing endpoints remain inaccessible after client signup.
    get "#{base_path}/sources"
    assert_redirected_to sign_in_path
    get "#{base_path}/invitations"
    assert_redirected_to sign_in_path

    # Invitation has been consumed. It cannot create another account or grant.
    assert_no_difference({"Studio::ClientAccount.count" => 0, "Studio::ClientProjectGrant.count" => 0}) do
      signup
    end
    assert_response :unprocessable_entity

    delete "/studio/client_sessions"
    assert_response :no_content
    get "/studio/client_projects"
    assert_response :not_found
  end

  test "existing client must authenticate again before accepting a second mailbox-proven invitation" do
    confirm_mailbox
    signup
    assert_response :created
    delete "/studio/client_sessions"
    assert_response :no_content

    post "/studio/client_sessions",
         params: { recipient_email: "receiver@example.test", password: "incorrect-password" }
    assert_response :unauthorized
    get "/studio/client_projects"
    assert_response :not_found

    post "/studio/client_sessions",
         params: { recipient_email: "Receiver@Example.TEST", password: @client_password }
    assert_response :success

    next_invitation = @issuer.issue!(client: @other_client, intake: @other_intake,
                                     recipient_email: "receiver@example.test")
    post "/studio/client_projects/accept",
         params: { invitation_token: next_invitation.token,
                   consent_policy: "studio_review_v1", consent_confirmation: "yes" }
    assert_response :unprocessable_entity

    verify_invitation(next_invitation)
    post "/studio/client_projects/accept",
         params: { invitation_token: next_invitation.token,
                   consent_policy: "studio_review_v1", consent_confirmation: "yes" }
    assert_response :created
    assert_equal 2, Studio::ClientProjectGrant.where(
      studio_client_account_id: Studio::ClientAccount.sole.id).count

    get "/studio/client_projects"
    assert_response :success
    assert_equal 2, JSON.parse(response.body).fetch("projects").size

    post "/studio/client_projects/accept",
         params: { invitation_token: next_invitation.token,
                   consent_policy: "studio_review_v1", consent_confirmation: "yes" }
    assert_response :unprocessable_entity
  end

  test "revoking accepted invitation removes immediately visible grant and cannot be replayed" do
    confirm_mailbox
    signup
    assert_response :created
    grant = Studio::ClientProjectGrant.sole
    @issuer.revoke!(client: @client, intake: @intake, id: @invitation.invitation.id)
    assert_equal "revoked", @invitation.invitation.reload.status
    assert_equal "revoked", grant.reload.status
    get "/studio/client_projects"
    assert_response :success
    assert_equal [], JSON.parse(response.body).fetch("projects")
    get "/studio/client_projects/#{grant.id}"
    assert_response :not_found
    get "#{base_path}/sources"
    assert_redirected_to sign_in_path
    assert_no_difference "Studio::ClientProjectGrant.count" do
      post "/studio/client_projects/accept",
           params: { invitation_token: @invitation.token,
                     consent_policy: "studio_review_v1", consent_confirmation: "yes" }
    end
    assert_response :unprocessable_entity
  end

  test "workspace and account suspension disable access without deleting grants" do
    confirm_mailbox
    signup
    assert_response :created
    @ws.update!(state: "suspended")
    get "/studio/client_projects"
    assert_response :success
    assert_equal [], JSON.parse(response.body).fetch("projects")

    @ws.update!(state: "internal")
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get "/studio/client_projects"
    assert_response :success
    assert_equal [], JSON.parse(response.body).fetch("projects")

    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "active")
    Studio::ClientAccount.sole.update!(status: "suspended")
    get "/studio/client_projects"
    assert_response :not_found
  end

  test "production gate rejects all client account, login, and project routes even when env flag is set" do
    Studio::ClientOnboarding.stub(:enabled?, false) do
      signup
      assert_response :not_found
      post "/studio/client_sessions",
           params: { recipient_email: "receiver@example.test", password: @client_password }
      assert_response :not_found
      get "/studio/client_projects"
      assert_response :not_found
      post "/studio/client_projects/accept", params: { invitation_token: @invitation.token }
      assert_response :not_found
    end
    assert_equal 0, Studio::ClientAccount.count
  end

  test "PostgreSQL denies forged tenant/client association and double invitation grant" do
    confirm_mailbox
    signup
    assert_response :created
    existing = Studio::ClientProjectGrant.sole
    now = Time.current
    values = {
      studio_client_account_id: existing.studio_client_account_id,
      project_invitation_id: existing.project_invitation_id,
      workspace_id: @ws.id, client_id: @other_client.id,
      project_intake_id: @intake.id, role: "reviewer", status: "active",
      consent_policy: "studio_review_v1", consented_at: now,
      accepted_at: now, created_at: now, updated_at: now
    }
    foreign_issuer = Studio::ProjectInvitationIssuer.new(actor: @other, workspace: @foreign_ws)
    foreign_invite = foreign_issuer.issue!(client: @foreign_client, intake: @foreign_intake,
                                          recipient_email: "other@example.test")
    # Composite FK denies wrong workspace/client even through raw SQL insert.
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::ClientProjectGrant.insert_all!([values.merge(project_invitation_id: foreign_invite.invitation.id)])
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      Studio::ClientProjectGrant.insert_all!([values.merge(client_id: @client.id)])
    end
  end

  private

  def signup(email: "receiver@example.test", consent_confirmation: "yes")
    post "/studio/client_accounts",
         params: { invitation_token: @invitation.token,
                   recipient_email: email, password: @client_password,
                   consent_policy: "studio_review_v1",
                   consent_confirmation: consent_confirmation }
  end

  def confirm_mailbox
    verify_invitation(@invitation)
  end

  def verify_invitation(issued)
    email = "receiver@example.test"
    post "/studio/invitations/email_proofs",
         params: { invitation_token: issued.token, recipient_email: email }
    assert_response :accepted
    message = ActionMailer::Base.deliveries.last
    code = message.body.decoded[/code: ([0-9]{6})/, 1]
    assert_match(/\A[0-9]{6}\z/, code)
    post "/studio/invitations/email_proofs/confirm",
         params: { invitation_token: issued.token, recipient_email: email,
                   verification_code: code }
    assert_response :success
  end

  def base_path
    "/workspaces/#{@ws.id}/clients/#{@client.id}/project_intakes/#{@intake.id}"
  end

  def make_intake(ws, client, title)
    ws.project_intakes.create!(client: client, title: title, project_type: "website",
      goal: "Only synthetic data for studio client security tests.",
      demo_consent_at: Time.current)
  end
end
