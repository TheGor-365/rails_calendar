require "test_helper"

class StudioInvitationEmailProofsTest < ActionDispatch::IntegrationTest
  setup do
    @password = "mailbox-owner-synthetic-test-password"
    @alice = User.create!(email: "mailbox-owner@example.test", role: "owner",
                          password: @password, password_confirmation: @password)
    @bob = User.create!(email: "mailbox-foreign-owner@example.test", role: "owner",
                        password: @password, password_confirmation: @password)
    @workspace = Workspace.create!(owner_user: @alice, name: "Synthetic mailbox A", slug: "proof-a")
    @foreign = Workspace.create!(owner_user: @bob, name: "Synthetic mailbox B", slug: "proof-b")
    WorkspaceMembership.create!(workspace: @workspace, user: @alice, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @bob, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional recipient")
    @intake = @workspace.project_intakes.create!(client: @client, title: "Fictional verification",
      project_type: "website", goal: "Only a fictitious mailbox verification test.",
      demo_consent_at: Time.current)
    @issued = Studio::ProjectInvitationIssuer.new(actor: @alice, workspace: @workspace)
      .issue!(client: @client, intake: @intake, recipient_email: "receiver@example.test")
    ActionMailer::Base.deliveries.clear
  end

  test "valid invitation is not enough; email code is needed and confirmation grants no access" do
    assert_no_difference ["User.count", "WorkspaceMembership.count"] do
      post "/studio/invitations/email_proofs",
           params: { invitation_token: @issued.token, recipient_email: " Receiver@Example.Test " }
    end
    assert_response :accepted
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal 1, ActionMailer::Base.deliveries.length
    message = ActionMailer::Base.deliveries.last
    assert_equal ["receiver@example.test"], message.to
    code = message.body.decoded[/code: ([0-9]{6})/, 1]
    assert_match(/\A[0-9]{6}\z/, code)

    proof = @issued.invitation.reload.project_invitation_email_proof
    assert_equal false, proof.verified?
    assert_equal false, proof.access_granted?
    assert_equal 64, proof.challenge_digest.length
    assert_not_includes proof.attributes.values, code
    assert_not_includes proof.attributes.values, "receiver@example.test"
    assert_not_includes proof.attributes.values, @issued.token

    post "/studio/invitations/email_proofs/confirm",
         params: { invitation_token: @issued.token,
                   recipient_email: "receiver@example.test", verification_code: code }
    assert_response :success
    assert_equal({ "email_possession_confirmed" => true, "access_granted" => false },
                 JSON.parse(response.body))
    assert proof.reload.verified?
    assert_equal false, @issued.invitation.reload.redeemable?
    assert_equal "pending", @issued.invitation.status
    assert_equal 0, User.where(role: "client").count
    assert_equal 0, @workspace.workspace_memberships.where(role: "client").count

    get "/workspaces/#{@workspace.id}/clients/#{@client.id}/project_intakes/#{@intake.id}/sources"
    assert_redirected_to sign_in_path
    post "/studio/invitations/email_proofs/confirm",
         params: { invitation_token: @issued.token,
                   recipient_email: "receiver@example.test", verification_code: code }
    assert_response :unprocessable_entity
  end

  test "wrong recipient and invalid token get uniform response and no message" do
    post "/studio/invitations/email_proofs",
         params: { invitation_token: @issued.token, recipient_email: "attacker@example.test" }
    assert_response :accepted
    post "/studio/invitations/email_proofs",
         params: { invitation_token: SecureRandom.hex(32), recipient_email: "receiver@example.test" }
    assert_response :accepted
    assert_empty ActionMailer::Base.deliveries
    assert_nil @issued.invitation.reload.project_invitation_email_proof
  end

  test "duplicate request does not send unlimited codes or create another proof" do
    2.times do
      post "/studio/invitations/email_proofs",
           params: { invitation_token: @issued.token, recipient_email: "receiver@example.test" }
      assert_response :accepted
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal 1, ProjectInvitationEmailProof.where(project_invitation_id: @issued.invitation.id).count
  end

  test "incorrect code maxes out attempts without allowing even a correct code afterward" do
    post "/studio/invitations/email_proofs",
         params: { invitation_token: @issued.token, recipient_email: "receiver@example.test" }
    correct = ActionMailer::Base.deliveries.last.body.decoded[/code: ([0-9]{6})/, 1]
    wrong = correct == "000000" ? "000001" : "000000"
    service = Studio::InvitationMailboxProof.new
    5.times do
      assert_equal false, service.confirm!(token: @issued.token,
        email: "receiver@example.test", code: wrong)
    end
    proof = @issued.invitation.reload.project_invitation_email_proof
    assert_equal 5, proof.reload.failed_attempts
    assert_equal false, service.confirm!(token: @issued.token,
      email: "receiver@example.test", code: correct)
    assert_equal false, proof.reload.access_granted?
  end

  test "expiration and revocation prevent verification even with a correct email code" do
    post "/studio/invitations/email_proofs",
         params: { invitation_token: @issued.token, recipient_email: "receiver@example.test" }
    code = ActionMailer::Base.deliveries.last.body.decoded[/code: ([0-9]{6})/, 1]
    service = Studio::InvitationMailboxProof.new
    travel 12.minutes do
      assert_equal false, service.confirm!(token: @issued.token,
        email: "receiver@example.test", code: code)
    end
    assert_not @issued.invitation.reload.project_invitation_email_proof.verified?

    @issued.invitation.update!(status: "revoked")
    assert_equal false, service.confirm!(token: @issued.token,
      email: "receiver@example.test", code: code)
  end

  test "revoked workspace owner cannot initiate challenge" do
    @workspace.workspace_memberships.find_by!(user: @alice).update!(status: "revoked")
    post "/studio/invitations/email_proofs",
         params: { invitation_token: @issued.token, recipient_email: "receiver@example.test" }
    assert_response :accepted
    assert_empty ActionMailer::Base.deliveries
    assert_nil @issued.invitation.reload.project_invitation_email_proof
  end

  test "production-disabled gate rejects requests even with a valid bearer token" do
    Studio::InvitationMailboxProof.stub(:enabled?, false) do
      post "/studio/invitations/email_proofs",
           params: { invitation_token: @issued.token, recipient_email: "receiver@example.test" }
      assert_response :not_found
    end
    assert_empty ActionMailer::Base.deliveries
  end
end
