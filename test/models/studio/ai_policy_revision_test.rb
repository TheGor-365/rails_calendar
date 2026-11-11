require "test_helper"

class StudioAiPolicyRevisionTest < ActiveSupport::TestCase
  setup do
    nonce = SecureRandom.hex(5)
    password = "rc037-synthetic-audit-actor-password"
    @owner = User.create!(email: "ai-revision-owner-#{nonce}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @other = User.create!(email: "ai-revision-other-#{nonce}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic audit workspace",
      slug: "ai-audit-#{nonce}")
    @foreign = Workspace.create!(owner_user: @other, name: "Foreign audit workspace",
      slug: "ai-audit-other-#{nonce}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other, role: "owner", status: "active")
    client = @ws.clients.create!(display_name: "Only a fictional test client")
    @intake = @ws.project_intakes.create!(client: client,
      title: "Fictional audited preferences", project_type: "website",
      goal: "Fictional project data only; no external AI.",
      demo_consent_at: Time.current)
  end

  test "create and update append scoped HMAC revisions; unchanged save does not" do
    policy = @ws.studio_ai_policies.new(mode: "offline", purposes: ["clarify"])
    policy.audit_actor = @owner
    assert_difference "Studio::AiPolicyRevision.count", 1 do
      policy.save!
    end
    first = policy.revisions.sole
    assert_equal 1, first.revision
    assert_equal "created", first.action
    assert_equal "owner_ui", first.origin
    assert_equal @owner.id, first.actor_user_id
    assert_equal Studio::AiPolicyRevision::GENESIS, first.previous_digest
    assert_equal ["clarify"], first.settings.fetch("purposes")
    assert_equal true, Studio::AiPolicyRevision.verify_chain!(policy: policy)
    assert_not_includes first.attributes.to_json, @owner.email
    assert_not_includes first.attributes.to_json, "Fictional audited preferences"

    assert_no_difference "Studio::AiPolicyRevision.count" do
      policy.save!
    end
    assert_difference "Studio::AiPolicyRevision.count", 1 do
      policy.update!(mode: "off", purposes: [])
    end
    second = policy.revisions.order(:revision).last
    assert_equal 2, second.revision
    assert_equal "updated", second.action
    assert_equal first.event_digest, second.previous_digest
    assert_equal "off", second.settings.fetch("mode")
    assert Studio::AiPolicyRevision.verify_chain!(policy: policy)
  end

  test "internal model changes are logged but never falsely attributed to owner" do
    policy = @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    event = policy.revisions.sole
    assert_nil event.actor_user_id
    assert_equal "internal_unattributed", event.origin
    assert Studio::AiPolicyRevision.verify_chain!(policy: policy)
  end

  test "audit actor must be active exact workspace owner" do
    policy = @ws.studio_ai_policies.new(mode: "offline", purposes: ["clarify"])
    policy.audit_actor = @other
    assert_not policy.valid?
    assert_equal 0, Studio::AiPolicyRevision.count
    policy.audit_actor = @owner
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_not policy.valid?
    assert_equal 0, Studio::AiPolicyRevision.count
  end

  test "audit revisions resist Rails update and delete, tampering fails verification" do
    policy = @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    event = policy.revisions.sole
    assert_not event.update(settings: { "mode" => "external" })
    assert_not event.destroy
    assert Studio::AiPolicyRevision.verify_chain!(policy: policy)
    event.update_columns(event_digest: "a" * 64)
    assert_raises(SecurityError) { Studio::AiPolicyRevision.verify_chain!(policy: policy) }
  end

  test "database composite FK blocks a forged revision attached to a foreign policy" do
    own_policy = @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    foreign_policy = @foreign.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    first = own_policy.revisions.sole
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::AiPolicyRevision.insert_all!([{
          workspace_id: @ws.id, studio_ai_policy_id: foreign_policy.id,
          revision: 2, action: "updated", origin: "internal_unattributed",
          settings: first.settings, previous_digest: first.event_digest,
          event_digest: "c" * 64, recorded_at: Time.current,
          created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_equal 2, Studio::AiPolicyRevision.count
  end
end
