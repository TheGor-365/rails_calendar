require "test_helper"

class WorkspaceMemoryRepositoryTest < ActiveSupport::TestCase
  setup do
    @owner = create_owner("workspace-owner@example.test")
    @other_owner = create_owner("other-workspace-owner@example.test")

    @workspace = Workspace.create!(
      owner_user: @owner, name: "Synthetic Owner Workspace", slug: "synthetic-owner"
    )
    @other_workspace = Workspace.create!(
      owner_user: @other_owner, name: "Other Isolated Workspace", slug: "other-isolated"
    )
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @other_workspace, user: @other_owner, role: "owner", status: "active")

    @client = @workspace.clients.create!(display_name: "Synthetic Customer A")
    @second = @workspace.clients.create!(display_name: "Synthetic Customer B")
    @outsider = @other_workspace.clients.create!(display_name: "Isolated Customer C")
    @repo = WorkspaceMemory::Repository.new(actor: @owner, workspace: @workspace)
  end

  test "stores source-attributed immutable revisions with separate client scope" do
    first = record_fact(client: @client, payload: { "value" => "Rails app" })
    second = record_fact(client: @client, payload: { "value" => "Rails 8 upgrade" })
    record_fact(client: @second, payload: { "value" => "Other client's stack" })

    assert_equal [1, 2], [first.revision, second.revision]
    facts = @repo.current_facts(client: @client)
    assert_equal false, facts.fetch("provider_ready")
    assert_equal "OWNER_INTERNAL_ONLY_DO_NOT_SEND_TO_PROVIDER", facts.fetch("classification")
    assert_equal "Rails 8 upgrade", facts.fetch("facts").sole.dig("value", "value")
    assert_equal [1, 2], @repo.history(client: @client, field_key: "current_stack").map { |r| r["revision"] }
    assert_raises(SecurityError) { @repo.provider_payload }

    assert_not first.update(status: "verified")
    assert_not first.destroy
    assert_equal "Rails app", first.reload.payload.fetch("value")
  end

  test "a new excluded revision cannot resurrect the old client fact" do
    record_fact(client: @client, payload: { "value" => "Historical preference" })
    @repo.record_fact!(
      client: @client, field_key: "current_stack", payload: { "value" => "redacted" },
      status: "excluded", sensitivity: "internal", source_ref: "owner_note:2"
    )
    assert_empty @repo.current_facts(client: @client).fetch("facts")
    assert_equal 2, @repo.history(client: @client, field_key: "current_stack").size
  end

  test "facts expire and never fall back to an older revision" do
    record_fact(client: @client, payload: { "value" => "Old preference" })
    @repo.record_fact!(
      client: @client, field_key: "current_stack", payload: { "value" => "Outdated preference" },
      expires_at: 1.day.ago, source_ref: "owner_note:expired"
    )
    assert_empty @repo.current_facts(client: @client).fetch("facts")
  end

  test "cross-tenant access and invalid memberships fail closed" do
    assert_raises(SecurityError) { @repo.current_facts(client: @outsider) }
    assert_raises(SecurityError) { @repo.history(client: @outsider, field_key: "current_stack") }
    assert_raises(SecurityError) do
      @repo.record_fact!(client: @outsider, field_key: "current_stack",
                         payload: { "value" => "inaccessible" }, source_ref: "forbidden")
    end
    assert_raises(SecurityError) do
      WorkspaceMemory::Repository.new(actor: @other_owner, workspace: @workspace)
    end

    invalid = ClientFact.new(
      workspace: @workspace, client: @outsider, recorded_by: @owner,
      field_key: "current_stack", revision: 1, payload: { "value" => "bad" },
      status: "reported", sensitivity: "internal", purpose: "discovery",
      source_kind: "owner_note", source_ref: "synthetic"
    )
    assert_not invalid.valid?
    assert_includes invalid.errors[:workspace_id], "does not match client"

    membership = WorkspaceMembership.new(
      workspace: @workspace, user: @other_owner, role: "owner", status: "active"
    )
    assert_not membership.valid?
  end

  test "revoking membership or suspending workspace immediately removes read access" do
    member = @workspace.workspace_memberships.find_by!(user: @owner)
    member.update!(status: "revoked")
    assert_raises(SecurityError) { WorkspaceMemory::Repository.new(actor: @owner, workspace: @workspace) }

    member.update!(status: "active")
    @workspace.update!(state: "suspended")
    assert_raises(SecurityError) { WorkspaceMemory::Repository.new(actor: @owner, workspace: @workspace) }
  end

  test "consent events are append-only, opt-in defaults false and revocation wins" do
    assert_equal false, @repo.consent_state(client: @client, purpose: "external_ai")
    granted = @repo.record_consent!(
      client: @client, purpose: "external_ai", granted: true, source_ref: "test:explicit_grant"
    )
    assert @repo.consent_state(client: @client, purpose: "external_ai")
    @repo.record_consent!(
      client: @client, purpose: "external_ai", granted: false, source_ref: "test:revoked"
    )
    assert_equal false, @repo.consent_state(client: @client, purpose: "external_ai")
    assert_not granted.destroy
    assert_raises(SecurityError) { @repo.provider_payload }
    assert_raises(ArgumentError) { @repo.consent_state(client: @client, purpose: "anything") }
  end

  test "invalid payload and unsupported statuses are rejected without changing memory" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @repo.record_fact!(client: @client, field_key: "current_stack",
                         payload: { "value" => "X" * 4_000 }, source_ref: "invalid")
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      @repo.record_fact!(client: @client, field_key: "current_stack",
                         payload: { "value" => "guess" }, status: "approved",
                         source_ref: "invalid")
    end
    assert_empty @repo.history(client: @client, field_key: "current_stack")
  end

  private

  def create_owner(email)
    pass = "synthetic-owner-test-only-password-12345"
    User.create!(email: email, password: pass, password_confirmation: pass, role: "owner")
  end

  def record_fact(client:, payload:)
    @repo.record_fact!(
      client: client, field_key: "current_stack", payload: payload,
      status: "reported", sensitivity: "internal", purpose: "discovery",
      source_kind: "owner_note", source_ref: "synthetic:source"
    )
  end
end
