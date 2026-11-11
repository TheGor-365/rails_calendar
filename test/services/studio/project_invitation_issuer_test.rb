require "test_helper"

class StudioProjectInvitationIssuerTest < ActiveSupport::TestCase
  setup do
    pass = "synthetic-invite-service-password-12345"
    @owner = User.create!(email: "invite-owner@example.test", role: "owner",
                          password: pass, password_confirmation: pass)
    @other = User.create!(email: "invite-other@example.test", role: "owner",
                          password: pass, password_confirmation: pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Invite Test A", slug: "invites-a")
    @other_workspace = Workspace.create!(owner_user: @other, name: "Invite Test B", slug: "invites-b")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @other_workspace, user: @other, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Synthetic A")
    @second = @workspace.clients.create!(display_name: "Synthetic B")
    @outside = @other_workspace.clients.create!(display_name: "Synthetic C")
    @intake = new_intake(@workspace, @client)
    @other_intake = new_intake(@workspace, @second)
    @foreign_intake = new_intake(@other_workspace, @outside)
    @issuer = Studio::ProjectInvitationIssuer.new(actor: @owner, workspace: @workspace)
  end

  test "token alone cannot be used for login; pending, expired and revoked grants all deny" do
    issued = @issuer.issue!(client: @client, intake: @intake, recipient_email: "Synthetic@Example.TEST")
    record = issued.invitation
    assert_equal Digest::SHA256.hexdigest(issued.token), record.token_digest
    assert_not record.redeemable?
    assert_raises(SecurityError) { @issuer.accept!(token: issued.token, email: "synthetic@example.test") }
    travel 3.days do
      assert record.expired?
      assert_not record.redeemable?
      assert_raises(SecurityError) { @issuer.accept!(token: issued.token, email: "synthetic@example.test") }
    end
    @issuer.revoke!(client: @client, intake: @intake, id: record.id)
    assert_equal "revoked", record.reload.status
    assert_raises(SecurityError) { @issuer.accept!(token: issued.token, email: "synthetic@example.test") }
  end

  test "rejects forged scopes, cross-tenants and revoked memberships" do
    assert_raises(SecurityError) do
      Studio::ProjectInvitationIssuer.new(actor: @other, workspace: @workspace)
    end
    assert_raises(SecurityError) do
      @issuer.issue!(client: @outside, intake: @foreign_intake, recipient_email: "a@example.test")
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      @issuer.issue!(client: @second, intake: @intake, recipient_email: "a@example.test")
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      @issuer.list!(client: @client, intake: @other_intake)
    end

    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      @issuer.issue!(client: @client, intake: @intake, recipient_email: "a@example.test")
    end
  end

  test "database constraints deny forged cross-tenant and granted-state invitations" do
    now = Time.current
    common = {
      workspace_id: @workspace.id, client_id: @second.id,
      project_intake_id: @intake.id, issued_by_id: @owner.id,
      token_digest: Digest::SHA256.hexdigest("fixture"),
      recipient_digest: Digest::SHA256.hexdigest("recipient"),
      role: "reviewer", status: "pending",
      expires_at: 48.hours.from_now, created_at: now, updated_at: now
    }
    assert_raises(ActiveRecord::InvalidForeignKey) { ProjectInvitation.insert_all!([common]) }
  end

  test "database denies shortcut from pending to granted state" do
    now = Time.current
    common = {
      workspace_id: @workspace.id, client_id: @client.id,
      project_intake_id: @intake.id, issued_by_id: @owner.id,
      token_digest: Digest::SHA256.hexdigest("fixture-two"),
      recipient_digest: Digest::SHA256.hexdigest("recipient-two"),
      role: "reviewer", status: "active",
      expires_at: 48.hours.from_now, created_at: now, updated_at: now
    }
    assert_raises(ActiveRecord::StatementInvalid) { ProjectInvitation.insert_all!([common]) }
  end

  test "mutation of identity and deletion are blocked" do
    record = @issuer.issue!(client: @client, intake: @intake, recipient_email: "fixture@example.test").invitation
    assert_not record.update(client_id: @second.id)
    assert_not record.destroy
    assert_equal "pending", record.reload.status
  end

  private

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Synthetic", project_type: "website",
      goal: "A fictional project for invitation tests.", demo_consent_at: Time.current)
  end
end
