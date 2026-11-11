require "test_helper"

class StudioAiBudgetAdmissionTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(6)
    password = "synthetic-zero-budget-test-password"
    @owner = User.create!(email: "budget-owner-#{suffix}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @foreign_owner = User.create!(email: "budget-foreign-#{suffix}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic budget A", slug: "budget-a-#{suffix}")
    @foreign_ws = Workspace.create!(owner_user: @foreign_owner,
      name: "Synthetic budget B", slug: "budget-b-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @foreign_owner, role: "owner", status: "active")
    client = @ws.clients.create!(display_name: "Fictional budget client")
    @intake = @ws.project_intakes.create!(client: client, title: "Fictional billing",
      project_type: "website", goal: "Offline test, not chargeable.",
      demo_consent_at: Time.current)
  end

  test "default off denies; explicit offline allows only a no-cost decision" do
    assert_raises(Studio::AiBudgetAdmission::Denied) { admit }
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["clarify"])
    result = admit
    assert_equal "offline_admitted", result.fetch(:status)
    assert_equal "offline_template", result.fetch(:provider)
    assert_equal "offline", result.fetch(:requested_mode)
    assert_equal false, result.fetch(:external_call_permitted)
    assert_equal false, result.fetch(:billing_permitted)
    assert_equal 0, result.fetch(:tokens_reserved)
    assert_equal 0, result.fetch(:usd_reserved)
    assert_equal 7, result.size
  end

  test "positive budget preferences and apparent consent never permit a billable provider" do
    @ws.studio_ai_policies.create!(mode: "reviewed_provider", purposes: ["clarify"],
      external_consent: true, token_cap_per_call: 100_000,
      token_cap_per_day: 300_000, usd_cap_per_call: 500, usd_cap_per_month: 5000)
    assert_equal "reviewed_provider_unavailable", admit.fetch(:requested_mode)
    [
      { provider: "reviewed_provider" },
      { provider: "openai" },
      { estimated_tokens: 1 },
      { estimated_tokens: -1 },
      { estimated_tokens: "0" },
      { estimated_tokens: nil },
      { estimated_usd: 0.01 },
      { estimated_usd: -0.01 },
      { estimated_usd: Float::INFINITY },
      { estimated_usd: Float::NAN },
      { estimated_usd: "0" },
      { estimated_usd: nil },
      { data_class: "confidential" },
      { purpose: "export_secrets" },
      { purpose: nil }
    ].each do |change|
      assert_raises(Studio::AiBudgetAdmission::Denied) do
        admit(**change)
      end
    end
  end

  test "project permissions can only narrow workspace and revoke immediately" do
    root = @ws.studio_ai_policies.create!(mode: "off", purposes: ["clarify"])
    project = @ws.studio_ai_policies.create!(project_intake: @intake,
      mode: "reviewed_provider", purposes: ["clarify"], external_consent: true)
    assert_raises(Studio::AiBudgetAdmission::Denied) { admit }
    root.update!(mode: "offline")
    assert_equal "offline", admit.fetch(:requested_mode)
    project.update!(mode: "off")
    assert_raises(Studio::AiBudgetAdmission::Denied) { admit }
    project.update!(mode: "offline")
    active = gate
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { active.admit!(**request) }
  end

  test "foreign tenant and production are blocked before any cost is accepted" do
    assert_raises(SecurityError) do
      Studio::AiBudgetAdmission.new(actor: @foreign_owner,
        workspace: @ws, intake: @intake)
    end
    assert_raises(SecurityError) do
      Studio::AiBudgetAdmission.new(actor: @owner,
        workspace: @foreign_ws, intake: @intake)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::AiBudgetAdmission::Denied) { gate }
    end
  end

  private

  def request
    { purpose: "clarify", data_class: "synthetic", provider: "offline_template",
      estimated_tokens: 0, estimated_usd: 0 }
  end

  def admit(**opts)
    gate.admit!(**request.merge(opts))
  end

  def gate
    Studio::AiBudgetAdmission.new(actor: @owner, workspace: @ws, intake: @intake)
  end
end
