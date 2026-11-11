require "test_helper"

class StudioOfflineAiDispatcherTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(6)
    password = "fictional-policy-only-test-password"
    @owner = User.create!(email: "ai-owner-#{suffix}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @other = User.create!(email: "ai-other-#{suffix}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @ws = Workspace.create!(owner_user: @owner,
      name: "Fictional Studio AI policy", slug: "ai-policy-#{suffix}")
    @foreign_ws = Workspace.create!(owner_user: @other,
      name: "Fictional foreign Studio", slug: "other-ai-policy-#{suffix}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_ws, user: @other, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional client only")
    @intake = new_intake(@ws, @client)
    @other_intake = new_intake(@foreign_ws, @foreign_ws.clients.create!(display_name: "Other fictional client"))
  end

  test "default denies all operations, even a caller requesting offline" do
    result = dispatcher.call(purpose: "document_plan", data_class: "synthetic")
    assert_equal "denied", result.fetch(:status)
    assert_equal "workspace_policy_off", result.fetch(:reason)
    assert_equal 0, result.fetch(:external_calls)
  end

  test "owner-configured offline scope produces only an unapproved deterministic proposal" do
    allow_workspace!
    first = dispatcher.call(purpose: "document_plan", data_class: "synthetic",
                            evidence: { "source_inspected" => true })
    second = dispatcher.call(purpose: "document_plan", data_class: "synthetic",
                             evidence: { "source_inspected" => true })
    assert_equal first, second
    assert_equal "offline_proposal", first.fetch(:status)
    assert_equal "ready_to_propose", first.dig(:output, "artifacts", 0, "status")
    assert_equal true, first.fetch(:human_review_required)
    assert_equal false, first.fetch(:source_bytes_accessed)
    assert_equal false, first.fetch(:production_ready)
    assert_equal "none", first.fetch(:provider)
    assert_equal "0.000000", first.fetch(:usd)
    assert_equal 0, first.fetch(:tokens)
    assert_equal 0, first.fetch(:external_calls)
    assert_equal 1, @ws.studio_ai_execution_receipts.count
    assert_equal first.fetch(:receipt_id), @ws.studio_ai_execution_receipts.first.id
  end

  test "project override may deny but cannot enable a disabled workspace" do
    @ws.studio_ai_policies.create!(project_intake: @intake, mode: "offline",
      allowed_purposes: ["document_plan"], allowed_data_classes: ["synthetic"])
    assert_equal "workspace_policy_off",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:reason)
    allow_workspace!
    assert_equal "offline_proposal",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:status)
    @ws.studio_ai_policies.where(project_intake: @intake).first.update!(mode: "off")
    assert_equal "project_restriction",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:reason)
  end

  test "allowlists and spend hard-deny outrank project or request choice" do
    allow_workspace!
    assert_equal "external_calls_hard_disabled",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic",
        requested_mode: "reviewed_provider").fetch(:reason)
    assert_equal "external_calls_hard_disabled",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic",
        estimated_usd: 0.01).fetch(:reason)
    assert_equal "external_calls_hard_disabled",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic",
        estimated_tokens: 1).fetch(:reason)
    assert_equal "purpose_or_data_class_not_supported",
      dispatcher.call(purpose: "unknown", data_class: "synthetic").fetch(:reason)
    assert_equal "purpose_or_data_class_not_supported",
      dispatcher.call(purpose: "document_plan", data_class: "private_client").fetch(:reason)
    @ws.studio_ai_policies.first.update!(allowed_purposes: [])
    assert_equal "purpose_restricted",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:reason)
  end

  test "invalid inputs and foreign tenant are rejected, not logged or promoted" do
    allow_workspace!
    assert_raises(ArgumentError) do
      dispatcher.call(purpose: "document_plan", data_class: "synthetic",
                      evidence: { "source_inspected" => "yes" })
    end
    assert_raises(SecurityError) do
      Studio::OfflineAiDispatcher.new(actor: @other, workspace: @ws, intake: @intake)
    end
    assert_raises(SecurityError) do
      Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @other_intake)
    end
    stale = dispatcher
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      stale.call(purpose: "document_plan", data_class: "synthetic")
    end
  end

  test "policy model and database reject foreign project and unsafe values" do
    policy = Studio::AiPolicy.new(workspace: @ws, project_intake: @other_intake,
      mode: "offline", allowed_purposes: ["document_plan"], allowed_data_classes: ["synthetic"])
    assert_not policy.valid?
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::AiPolicy.insert_all!([{
        workspace_id: @ws.id, project_intake_id: @other_intake.id,
        mode: "offline", allowed_purposes: ["document_plan"],
        allowed_data_classes: ["synthetic"], created_at: Time.current, updated_at: Time.current
      }])
    end
    assert_not Studio::AiPolicy.new(workspace: @ws, mode: "offline",
      allowed_purposes: ["dangerous"], allowed_data_classes: ["synthetic"]).valid?
    assert_not Studio::AiPolicy.new(workspace: @ws, mode: "offline",
      allowed_purposes: ["document_plan"], allowed_data_classes: ["private_client"]).valid?
    assert_not Studio::AiPolicy.new(workspace: @ws, mode: "offline",
      allowed_purposes: [], allowed_data_classes: [], per_call_usd_cap: -1).valid?
  end

  test "production and non-opted development never execute even local planning" do
    allow_workspace!
    Rails.env.stub(:production?, true) do
      Rails.env.stub(:test?, false) do
        assert_equal "nonproduction_only",
          dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:reason)
      end
    end
  end

  test "forged SQL allowlist rows cannot bypass the policy validator" do
    Studio::AiPolicy.insert_all!([{
      workspace_id: @ws.id, project_intake_id: nil,
      mode: "offline", allowed_purposes: ["document_plan", "unreviewed_external"],
      allowed_data_classes: ["synthetic"],
      created_at: Time.current, updated_at: Time.current
    }])
    assert_equal "invalid_policy",
      dispatcher.call(purpose: "document_plan", data_class: "synthetic").fetch(:reason)
  end

  test "only the nonbillable registry model is available" do
    entry = Studio::AiModelRegistry.lookup(purpose: "document_plan", data_class: "synthetic")
    assert_equal "none", entry.fetch(:provider)
    assert_equal false, entry.fetch(:external)
    assert_equal false, entry.fetch(:billable)
    assert_nil Studio::AiModelRegistry.lookup(purpose: "document_plan", data_class: "client_private")
    assert_equal ["offline_document_plan_v1"], Studio::AiModelRegistry.list.map { |model| model.fetch(:key) }
  end

  test "offline zero reservations are append-only, scoped and idempotent" do
    allow_workspace!
    one = dispatcher.call(purpose: "document_plan", data_class: "synthetic",
                          evidence: { "source_inspected" => true })
    two = dispatcher.call(purpose: "document_plan", data_class: "synthetic",
                          evidence: { "source_inspected" => true })
    assert_equal one.fetch(:receipt_id), two.fetch(:receipt_id)
    assert_equal 1, @ws.studio_ai_execution_receipts.count
    receipt = @ws.studio_ai_execution_receipts.first
    assert_equal 0, receipt.tokens_reserved
    assert_equal 0, receipt.tokens_used
    assert_equal 0, receipt.usd_reserved
    assert_equal 0, receipt.usd_used
    assert_not receipt.update(state: "running")
    assert_not receipt.destroy
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::AiExecutionReceipt.insert_all!([{
        workspace_id: @ws.id, project_intake_id: @other_intake.id,
        requested_by_id: @owner.id, request_fingerprint: "b" * 64,
        purpose: "document_plan", registry_key: "offline_document_plan_v1",
        state: "completed_offline", completed_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      }])
    end
  end

  private

  def dispatcher
    Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @intake)
  end

  def allow_workspace!
    @ws.studio_ai_policies.create!(mode: "offline",
      allowed_purposes: ["document_plan"], allowed_data_classes: ["synthetic"])
  end

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Fictional offline test",
      project_type: "website", goal: "Fictional, synthetic no-client-data input",
      demo_consent_at: Time.current)
  end
end
