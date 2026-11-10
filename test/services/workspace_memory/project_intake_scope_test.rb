require "test_helper"

class WorkspaceMemoryProjectIntakeScopeTest < ActiveSupport::TestCase
  setup do
    @alice = new_owner("workspace-alice@example.test")
    @bob = new_owner("workspace-bob@example.test")
    @a = Workspace.create!(owner_user: @alice, name: "Synthetic A", slug: "studio-a")
    @b = Workspace.create!(owner_user: @bob, name: "Synthetic B", slug: "studio-b")
    WorkspaceMembership.create!(workspace: @a, user: @alice, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @b, user: @bob, role: "owner", status: "active")
    @client_a = @a.clients.create!(display_name: "Fake client A")
    @client_b = @b.clients.create!(display_name: "Fake client B")
    @scope = WorkspaceMemory::ProjectIntakeScope.new(actor: @alice, workspace: @a)
  end

  test "creates only scoped synthetic intakes, legacy is not silently claimed" do
    intake = @scope.create_draft!(
      client: @client_a, title: "Synthetic landing", project_type: "website",
      goal: "Collect fictional enquiries only."
    )
    assert_equal @a.id, intake.workspace_id
    assert_equal @client_a.id, intake.client_id
    assert_equal intake.id, @scope.find!(id: intake.id, client: @client_a).id
    assert_equal [intake.id], @scope.list(client: @client_a).pluck(:id)

    legacy = ProjectIntake.create!(
      title: "Unassigned synthetic legacy", project_type: "rails_bugfix",
      goal: "Reproduce a completely synthetic issue.",
      demo_consent_at: Time.current
    )
    assert_nil legacy.workspace_id
    assert_raises(ActiveRecord::RecordNotFound) { @scope.find!(id: legacy.id) }
    assert_not_includes @scope.list.pluck(:id), legacy.id
  end

  test "cross tenant client writes and reads are denied" do
    assert_raises(SecurityError) do
      @scope.create_draft!(
        client: @client_b, title: "Wrong tenant", project_type: "website",
        goal: "Attempt to bind foreign client."
      )
    end
    other = @b.project_intakes.create!(
      client: @client_b, title: "Other test", project_type: "website",
      goal: "Fictional source only", demo_consent_at: Time.current
    )
    assert_raises(ActiveRecord::RecordNotFound) { @scope.find!(id: other.id) }
    assert_raises(SecurityError) { @scope.find!(id: other.id, client: @client_b) }
    refute ProjectIntake.new(workspace: @a, client: @client_b,
                             title: "invalid", project_type: "website",
                             goal: "Fictional test goal", demo_consent_at: Time.current).valid?
  end

  test "revoked membership disables existing scope and unrelated owner" do
    assert_raises(SecurityError) do
      WorkspaceMemory::ProjectIntakeScope.new(actor: @bob, workspace: @a)
    end
    @a.workspace_memberships.find_by!(user: @alice).update!(status: "revoked")
    assert_raises(SecurityError) { @scope.list }
    assert_raises(SecurityError) { @scope.find!(id: -1) }
  end

  private

  def new_owner(email)
    p = "synthetic-not-real-password-12345"
    User.create!(email: email, password: p, password_confirmation: p, role: "owner")
  end
end
