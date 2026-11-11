require "test_helper"

class StudioOfflineAiDispatcherTest < ActiveSupport::TestCase
  setup do
    nonce = SecureRandom.hex(5)
    pwd = "rc037-synthetic-dispatcher-test-password"
    @owner = User.create!(email: "rc037-owner-#{nonce}@example.test", role: "owner",
      password: pwd, password_confirmation: pwd)
    @outsider = User.create!(email: "rc037-foreign-#{nonce}@example.test", role: "owner",
      password: pwd, password_confirmation: pwd)
    @workspace = Workspace.create!(owner_user: @owner, name: "RC037 synthetic A", slug: "rc037-a-#{nonce}")
    @foreign = Workspace.create!(owner_user: @outsider, name: "RC037 synthetic B", slug: "rc037-b-#{nonce}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @outsider, role: "owner", status: "active")
    client = @workspace.clients.create!(display_name: "Fictional customer only")
    @intake = @workspace.project_intakes.create!(client: client, title: "Fictional project",
      project_type: "website", goal: "Purely synthetic internal offline fixtures.",
      demo_consent_at: Time.current)
  end

  test "off by default; explicit workspace offline permits zero-cost deterministic output" do
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "clarify") }
    @workspace.studio_ai_policies.create!(mode: "offline", purposes: %w[clarify source_outline])
    output = dispatcher.call(purpose: "clarify")
    assert_equal "offline_template", output[:provider_executed]
    assert_equal "offline", output[:mode_executed]
    assert_equal 0, output[:external_calls]
    assert_equal 0, output[:tokens_billed]
    assert_equal 0, output[:billable_usd]
    assert_equal false, output[:auto_approved]
    assert_equal "UNVERIFIED_SYNTHETIC_ONLY", output[:input_classification]
    refute_includes output.to_json, @owner.email
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "document_proposal") }
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "clarify", data_class: "client") }
  end

  test "project cannot override a workspace hard deny or restricted purpose" do
    root = @workspace.studio_ai_policies.create!(mode: "off", purposes: ["clarify"])
    project = @workspace.studio_ai_policies.create!(project_intake: @intake,
      mode: "reviewed_provider", purposes: %w[clarify document_proposal], external_consent: true)
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "clarify") }
    root.update!(mode: "offline")
    assert_equal "offline", dispatcher.call(purpose: "clarify")[:mode_executed]
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "document_proposal") }
    project.update!(mode: "off")
    assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher.call(purpose: "clarify") }
  end

  test "reviewed provider preference never permits a network or billable call" do
    @workspace.studio_ai_policies.create!(mode: "reviewed_provider", purposes: ["clarify"],
      external_consent: true, token_cap_per_call: 1000, usd_cap_per_month: 100)
    result = dispatcher.call(purpose: "clarify")
    assert_equal "reviewed_provider_unavailable", result[:provider_requested]
    assert_equal "offline_template", result[:provider_executed]
    assert_equal 0, result[:external_calls]
    assert_equal 0, result[:billable_usd]
    assert_equal false, Studio::OfflineAiDispatcher::PROVIDERS.fetch("reviewed_provider")[:available]
  end

  test "foreign owner and revoked membership fail closed" do
    @workspace.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    assert_raises(SecurityError) do
      Studio::OfflineAiDispatcher.new(actor: @outsider, workspace: @workspace, intake: @intake)
    end
    assert_raises(Studio::OfflineAiDispatcher::Denied) do
      Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @foreign, intake: @intake)
    end
    active = dispatcher
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { active.call(purpose: "clarify") }
  end

  test "postgres prevents duplicate defaults and forged cross-workspace project link" do
    @workspace.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    attrs = {
      workspace_id: @workspace.id, mode: "offline", purposes: ["clarify"],
      token_cap_per_call: 0, token_cap_per_day: 0,
      usd_cap_per_call: 0, usd_cap_per_month: 0, external_consent: false,
      created_at: Time.current, updated_at: Time.current
    }
    assert_raises(ActiveRecord::RecordNotUnique) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::AiPolicy.insert_all!([attrs])
      end
    end
    other_client = @foreign.clients.create!(display_name: "Other fictional")
    other_intake = @foreign.project_intakes.create!(client: other_client,
      title: "Foreign fictional", project_type: "website",
      goal: "Another synthetic unrelated scenario", demo_consent_at: Time.current)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::AiPolicy.insert_all!([attrs.merge(project_intake_id: other_intake.id)])
      end
    end
  end

  test "invalid configurations and production gate fail closed" do
    refute @workspace.studio_ai_policies.new(mode: "offline", purposes: ["bad"]).valid?
    refute @workspace.studio_ai_policies.new(mode: "offline", purposes: ["clarify", "clarify"]).valid?
    refute @workspace.studio_ai_policies.new(mode: "invalid", purposes: ["clarify"]).valid?
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::OfflineAiDispatcher::Denied) { dispatcher }
    end
  end

  private

  def dispatcher
    Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @workspace, intake: @intake)
  end
end
