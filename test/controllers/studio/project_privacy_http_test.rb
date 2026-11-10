require "test_helper"

class StudioProjectPrivacyHttpTest < ActionDispatch::IntegrationTest
  setup do
    @password = "synthetic-studio-private-token-password"
    @alice = User.create!(email: "slice-b-owner@example.test", role: "owner",
                          password: @password, password_confirmation: @password)
    @bob = User.create!(email: "slice-b-other@example.test", role: "owner",
                        password: @password, password_confirmation: @password)
    @a = Workspace.create!(owner_user: @alice, name: "Synthetic Slice B A", slug: "slice-b-tenant-a")
    @b = Workspace.create!(owner_user: @bob, name: "Synthetic Slice B B", slug: "slice-b-tenant-b")
    WorkspaceMembership.create!(workspace: @a, user: @alice, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @b, user: @bob, role: "owner", status: "active")
    @client = @a.clients.create!(display_name: "Synthetic Customer A")
    @client_two = @a.clients.create!(display_name: "Synthetic Customer B")
    @foreign_client = @b.clients.create!(display_name: "Synthetic Customer C")
    @intake = make_intake(@a, @client)
    @intake_two = make_intake(@a, @client_two)
    @foreign_intake = make_intake(@b, @foreign_client)
    @report = Studio::SourceInspector.new.call(
      filename: "synthetic.md", bytes: "# Fictional draft\n- [ ] Offline only\n"
    )
    @source = Studio::ProjectSourceRegistry.new(actor: @alice, workspace: @a)
      .register_preview!(client: @client, intake: @intake, report: @report)
  end

  test "metadata list is owner scoped and never serves raw contents" do
    get "#{base_path}/sources"
    assert_redirected_to sign_in_path

    sign_in(@bob)
    get "#{base_path}/sources"
    assert_response :not_found
    get "#{base_path}/sources/#{@source.id}/download"
    assert_response :not_found

    sign_out
    sign_in(@alice)
    get "#{base_path}/sources"
    assert_response :success
    assert_equal [@source.id], JSON.parse(response.body).fetch("sources").pluck("id")
    assert_equal false, JSON.parse(response.body).fetch("sources").first.fetch("downloadable")
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_no_match(/Fictional draft/, response.body)

    get "#{base_path}/sources/#{@source.id}/download"
    assert_response :not_found
    get "#{base_path}/sources/999999999/download"
    assert_response :not_found
  end

  test "same workspace wrong client ID or intake ID are indistinguishably denied" do
    sign_in(@alice)
    get "#{base_path(client: @client_two)}/sources"
    assert_response :not_found
    get "#{base_path(intake: @intake_two)}/sources"
    assert_response :not_found
    get "#{base_path(client: @foreign_client)}/sources"
    assert_response :not_found
    get "#{base_path(workspace: @b, client: @foreign_client, intake: @foreign_intake)}/sources"
    assert_response :not_found
  end

  test "invitation issuance creates a digest-only, non-redeemable, time-limited record" do
    sign_in(@alice)
    post "#{base_path}/invitations", params: { recipient_email: " Recipient@Example.TEST " }
    assert_response :created
    payload = JSON.parse(response.body)
    token = payload.fetch("token")
    invitation = ProjectInvitation.find(payload.fetch("invitation_id"))
    assert_match(/\A[0-9a-f]{64}\z/, token)
    assert_equal Digest::SHA256.hexdigest(token), invitation.token_digest
    assert_equal "pending", invitation.status
    assert_equal false, payload.fetch("redeemable")
    assert_not invitation.redeemable?
    assert_equal "reviewer", invitation.role
    assert invitation.expires_at < 49.hours.from_now
    assert_not invitation.attributes.key?("recipient_email")
    assert_not invitation.attributes.key?("token")
    assert_not invitation.attributes.values.include?("recipient@example.test")
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")

    get "#{base_path}/invitations"
    assert_response :success
    assert_equal [invitation.id], JSON.parse(response.body).fetch("invitations").pluck("id")
    assert_not_includes response.body, token
    assert_not_includes response.body, "recipient@example.test"

    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path}/invitations", params: { recipient_email: "recipient@example.test" }
    end
    assert_response :unprocessable_entity
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path}/invitations", params: { recipient_email: "invalid" }
    end
    assert_response :unprocessable_entity
  end

  test "invitation cross-client and cross-workspace writes are denied" do
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path}/invitations", params: { recipient_email: "one@example.test" }
    end
    assert_redirected_to sign_in_path

    sign_in(@bob)
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path}/invitations", params: { recipient_email: "one@example.test" }
    end
    assert_response :not_found

    sign_out
    sign_in(@alice)
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path(client: @client_two)}/invitations", params: { recipient_email: "one@example.test" }
    end
    assert_response :not_found
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path(intake: @intake_two)}/invitations", params: { recipient_email: "one@example.test" }
    end
    assert_response :not_found
  end

  test "only original owner can revoke an invitation; revocation strips future eligibility" do
    sign_in(@alice)
    post "#{base_path}/invitations", params: { recipient_email: "revoke@example.test" }
    invitation_id = JSON.parse(response.body).fetch("invitation_id")

    sign_out
    sign_in(@bob)
    delete "#{base_path}/invitations/#{invitation_id}"
    assert_response :not_found
    assert_equal "pending", ProjectInvitation.find(invitation_id).status

    sign_out
    sign_in(@alice)
    delete "#{base_path(client: @client_two)}/invitations/#{invitation_id}"
    assert_response :not_found
    delete "#{base_path}/invitations/#{invitation_id}"
    assert_response :no_content
    assert_equal "revoked", ProjectInvitation.find(invitation_id).status
    assert_not ProjectInvitation.find(invitation_id).redeemable?
  end

  test "revoked membership denies source reads and invitation writes immediately" do
    sign_in(@alice)
    @a.workspace_memberships.find_by!(user: @alice).update!(status: "revoked")
    get "#{base_path}/sources"
    assert_response :not_found
    assert_no_difference "ProjectInvitation.count" do
      post "#{base_path}/invitations", params: { recipient_email: "locked@example.test" }
    end
    assert_response :not_found
  end

  private

  def base_path(workspace: @a, client: @client, intake: @intake)
    "/workspaces/#{workspace.id}/clients/#{client.id}/project_intakes/#{intake.id}"
  end

  def make_intake(workspace, client)
    workspace.project_intakes.create!(
      client: client, title: "Synthetic source only",
      project_type: "website", goal: "A fictional goal for access isolation tests.",
      demo_consent_at: Time.current
    )
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
