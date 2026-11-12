require "test_helper"

class StudioProjectScopeAdmissionTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(5)
    @password = "rc039-project-admission-owner-password"
    @owner = User.create!(email: "rc039-i-owner-#{suffix}@example.test",
      password: @password, password_confirmation: @password, role: "owner")
    @foreign_owner = User.create!(email: "rc039-i-foreign-#{suffix}@example.test",
      password: @password, password_confirmation: @password, role: "owner")
    @workspace = Workspace.create!(owner_user: @owner,
      name: "RC-039 fictional accepted project", slug: "rc039-i-#{suffix}")
    @foreign_workspace = Workspace.create!(owner_user: @foreign_owner,
      name: "RC-039 foreign project", slug: "rc039-i-outside-#{suffix}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @foreign_owner, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "PRIVATE FICTIONAL CUSTOMER")
    @other_client = @workspace.clients.create!(display_name: "UNRELATED CUSTOMER")
    @intake = make_intake(@workspace, @client)
    @wrong_intake = make_intake(@workspace, @other_client)
    @spec = make_spec(@intake, approved: true)
    @account, @grant, @invitation = make_grant(@workspace, @client, @intake,
                                               "person-#{suffix}@example.test")
    @admission = Studio::ProjectScopeAdmission.new(workspace: @workspace)
  end

  test "exact owner approved spec and explicit client acceptance admit internal locked project" do
    baseline = [ProjectMilestone.count, Consultation.count,
                Studio::SyntheticProjectCard.count, Studio::SyntheticProjectTask.count]
    assert_difference "Studio::ProjectScopeAcceptance.count", 1 do
      @accepted = accept
    end
    assert_equal @spec.id, @accepted.fetch("spec_version_id")
    assert_equal fingerprint, @accepted.fetch("document_sha256")
    assert_equal false, @accepted.fetch("production_scope_approved")
    assert_no_difference "Studio::ProjectScopeAcceptance.count" do
      assert_equal @accepted, accept
    end

    assert_difference "Studio::Project.count", 1 do
      @project = activate
    end
    assert_equal @spec.id, @project.fetch("spec_version_id")
    assert_equal "internal_scope_locked", @project.fetch("status")
    assert_equal false, @project.fetch("client_portal_enabled")
    assert_equal false, @project.fetch("client_delivery_approved")
    assert_equal false, @project.fetch("tasks_executable")
    assert_equal false, @project.fetch("project_calendar_enabled")
    assert_no_difference "Studio::Project.count" do
      assert_equal @project, activate
    end

    assert_equal @project, @admission.owner_summary!(
      actor: @owner, project_id: @project.fetch("project_id"), explicit_synthetic: true)
    assert_equal @project, @admission.client_summary!(
      actor: @account, grant: @grant, project_id: @project.fetch("project_id"), explicit_synthetic: true)
    assert_equal baseline, [ProjectMilestone.count, Consultation.count,
                            Studio::SyntheticProjectCard.count, Studio::SyntheticProjectTask.count]
    refute_includes @project.to_json, @client.display_name
    refute_includes @project.to_json, @intake.goal
    refute_includes @project.to_json, @spec.document.fetch("summary")
    assert_equal 0, Studio::SyntheticProjectTaskEvent.count
  end

  test "owner approval alone and consent to review alone cannot create a project" do
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.activate_project!(actor: @owner, client: @client, intake: @intake,
                                   acceptance_id: 99_999_999, explicit_synthetic: true)
    end
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.accept_spec!(
        actor: @account, grant: @grant, client: @client, intake: @intake,
        spec_id: @spec.id, presented_digest: fingerprint,
        explicit_confirmation: false, explicit_synthetic: true
      )
    end
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.accept_spec!(
        actor: @account, grant: @grant, client: @client, intake: @intake,
        spec_id: @spec.id, presented_digest: "0" * 64,
        explicit_confirmation: true, explicit_synthetic: true
      )
    end
    @spec.update!(owner_approved_at: nil)
    assert_raises(Studio::ProjectScopeAdmission::Denied) { accept }
    assert_equal 0, Studio::Project.count
    assert_equal 0, Studio::ProjectScopeAcceptance.count
  end

  test "scope is fixed to latest approved revision, and replacements invalidate old receipt" do
    first_receipt = accept
    new_doc = @spec.document.deep_dup
    new_doc["summary"] = "Revised and unapproved scope"
    newer = @intake.intake_spec_versions.create!(
      version: @spec.version + 1, source: "human", document: new_doc)
    assert_raises(Studio::ProjectScopeAdmission::Denied) { activate }
    assert_raises(Studio::ProjectScopeAdmission::Denied) { accept }
    newer.update!(owner_approved_at: Time.current)
    assert_raises(Studio::ProjectScopeAdmission::Conflict) do
      @admission.accept_spec!(
        actor: @account, grant: @grant, client: @client, intake: @intake,
        spec_id: newer.id,
        presented_digest: Studio::ProjectScopeFingerprint.call(newer.document),
        explicit_confirmation: true, explicit_synthetic: true
      )
    end
    assert_equal first_receipt.fetch("spec_version_id"), @spec.id
    assert_equal 0, Studio::Project.count
    assert_equal 1, Studio::ProjectScopeAcceptance.count
  end

  test "document tampering or stale fingerprint fails before project activation" do
    accept
    @spec.update!(document: @spec.document.merge("summary" => "CHANGED AFTER REVIEW"))
    assert_raises(Studio::ProjectScopeAdmission::Conflict) { activate }
    assert_equal 0, Studio::Project.count
    assert_equal 1, Studio::ProjectScopeAcceptance.count
    refute_equal fingerprint, Studio::ProjectScopeAcceptance.sole.document_sha256
  end

  test "foreign client, wrong intake, impersonation and foreign owner are refused" do
    outside_account, outside_grant, = make_grant(
      @workspace, @other_client, @wrong_intake, "outsider-#{SecureRandom.hex(5)}@example.test")
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.accept_spec!(
        actor: outside_account, grant: outside_grant,
        client: @client, intake: @intake, spec_id: @spec.id,
        presented_digest: fingerprint, explicit_confirmation: true, explicit_synthetic: true
      )
    end
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.accept_spec!(
        actor: outside_account, grant: @grant,
        client: @client, intake: @intake, spec_id: @spec.id,
        presented_digest: fingerprint, explicit_confirmation: true, explicit_synthetic: true
      )
    end

    accept
    assert_raises(SecurityError) do
      @admission.activate_project!(
        actor: @foreign_owner, client: @client, intake: @intake,
        acceptance_id: Studio::ProjectScopeAcceptance.sole.id, explicit_synthetic: true
      )
    end
    assert_raises(SecurityError) do
      @admission.owner_summary!(actor: @foreign_owner,
        project_id: 1, explicit_synthetic: true)
    end
    assert_equal 0, Studio::Project.count
  end

  test "revoked client grant, invitation or suspended identity immediately deny access and activation" do
    accept
    @grant.update!(status: "revoked")
    assert_raises(Studio::ProjectScopeAdmission::Denied) { activate }
    @grant.update_columns(status: "active") # test-only repair of fixture, not production advice
    @invitation.update!(status: "revoked")
    assert_raises(Studio::ProjectScopeAdmission::Denied) { activate }
    @invitation.update_columns(status: "pending") # isolated test fixture
    @account.update!(status: "suspended")
    assert_raises(Studio::ProjectScopeAdmission::Denied) { activate }
    assert_equal 0, Studio::Project.count
  end

  test "creation is blocked without active owner membership or if workspace suspended" do
    accept
    membership = @workspace.workspace_memberships.find_by!(user: @owner)
    membership.update!(status: "revoked")
    assert_raises(SecurityError) { activate }
    membership.update!(status: "active")
    @workspace.update!(state: "suspended")
    assert_raises(Studio::ProjectScopeAdmission::Denied) { activate }
    assert_equal 0, Studio::Project.count
  end

  test "immutable model scope and database composite constraints refuse forged associations" do
    accept
    activate
    receipt = Studio::ProjectScopeAcceptance.sole
    project = Studio::Project.sole
    assert_not receipt.update(document_sha256: "a" * 64)
    assert_not receipt.destroy
    assert_not project.update(status: "active")
    assert_not project.destroy
    assert_equal "internal_scope_locked", project.reload.status

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::Project.transaction(requires_new: true) do
        Studio::Project.insert_all!([{
          workspace_id: @workspace.id, client_id: @other_client.id,
          project_intake_id: @wrong_intake.id,
          intake_spec_version_id: @spec.id,
          studio_project_scope_acceptance_id: receipt.id,
          created_by_id: @owner.id, document_sha256: receipt.document_sha256,
          status: "internal_scope_locked", created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::Project.transaction(requires_new: true) do
        Studio::Project.where(id: project.id).update_all(status: "approved")
      end
    end
    assert_equal 1, Studio::Project.count
  end

  test "no admission or summary in production and non-test modes" do
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::ProjectScopeAdmission::Denied) { accept }
    end
    Rails.env.stub(:test?, false) do
      assert_raises(Studio::ProjectScopeAdmission::Denied) { accept }
    end
    assert_raises(Studio::ProjectScopeAdmission::Denied) do
      @admission.accept_spec!(
        actor: @account, grant: @grant, client: @client, intake: @intake,
        spec_id: @spec.id, presented_digest: fingerprint,
        explicit_confirmation: true, explicit_synthetic: false)
    end
    assert_equal 0, Studio::ProjectScopeAcceptance.count
    assert_equal 0, Studio::Project.count
  end

  test "scope fingerprint ignores hash insertion order but distinguishes document content" do
    first = @spec.document
    second = first.to_a.reverse.to_h
    assert_equal Studio::ProjectScopeFingerprint.call(first),
                 Studio::ProjectScopeFingerprint.call(second)
    changed = first.deep_dup
    changed.fetch("deliverables") << "Additional feature not in accepted version"
    refute_equal Studio::ProjectScopeFingerprint.call(first),
                 Studio::ProjectScopeFingerprint.call(changed)
  end

  private

  def make_intake(ws, client)
    ws.project_intakes.create!(client: client, title: "SYNTHETIC PRIVATE TITLE",
      project_type: "website", goal: "Private fictional scope for isolated security tests.",
      demo_consent_at: Time.current)
  end

  def make_spec(intake, approved:)
    intake.intake_spec_versions.create!(version: 1, source: "human",
      document: {
        "summary" => "Private verified scope text (never exported in project receipt)",
        "goals" => ["Collect leads"], "deliverables" => ["Simple fictional site"],
        "acceptance_criteria" => ["Human checks the owner-only demo"],
        "unknowns" => [], "exclusions" => ["Live payments"], "milestones" => []
      },
      owner_approved_at: approved ? Time.current : nil)
  end

  def make_grant(ws, client, intake, email)
    account = Studio::ClientAccount.create!(
      email_digest: Studio::ClientAccount.email_digest_for(email),
      password: "rc039-fictional-client-password")
    invitation = ProjectInvitation.create!(
      workspace: ws, client: client, project_intake: intake, issued_by: ws.owner_user,
      role: "reviewer", status: "pending",
      token_digest: Digest::SHA256.hexdigest("token-#{email}"),
      recipient_digest: Studio::ClientAccount.email_digest_for(email),
      expires_at: 3.hours.from_now)
    now = Time.current
    ProjectInvitationEmailProof.create!(project_invitation: invitation,
      challenge_digest: Digest::SHA256.hexdigest("proof-#{email}"),
      failed_attempts: 0, expires_at: 10.minutes.from_now, verified_at: now)
    grant = Studio::ClientProjectGrant.create!(
      client_account: account, project_invitation: invitation,
      workspace: ws, client: client, project_intake: intake,
      role: "reviewer", status: "active", consent_policy: "studio_review_v1",
      consented_at: now, accepted_at: now)
    [account, grant, invitation]
  end

  def fingerprint
    Studio::ProjectScopeFingerprint.call(@spec.document)
  end

  def accept
    @admission.accept_spec!(
      actor: @account, grant: @grant, client: @client, intake: @intake,
      spec_id: @spec.id, presented_digest: fingerprint,
      explicit_confirmation: true, explicit_synthetic: true)
  end

  def activate
    @admission.activate_project!(
      actor: @owner, client: @client, intake: @intake,
      acceptance_id: Studio::ProjectScopeAcceptance.where(project_intake_id: @intake.id).pick(:id) || 0,
      explicit_synthetic: true)
  end
end
