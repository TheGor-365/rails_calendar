require "test_helper"

class StudioSyntheticProjectCardWorkflowTest < ActiveSupport::TestCase
  setup do
    salt = SecureRandom.hex(5)
    pass = "rc039-fictional-test-only-password"
    @owner = User.create!(email: "rc039-cards-owner-#{salt}@example.test",
      password: pass, password_confirmation: pass, role: "owner")
    @foreign_owner = User.create!(email: "rc039-cards-other-#{salt}@example.test",
      password: pass, password_confirmation: pass, role: "owner")
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Fictional cards", slug: "cards-#{salt}")
    @foreign_workspace = Workspace.create!(owner_user: @foreign_owner,
      name: "Foreign fictional cards", slug: "cards-other-#{salt}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @foreign_owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Private synthetic client")
    @wrong_client = @workspace.clients.create!(display_name: "Different synthetic client")
    @foreign_client = @foreign_workspace.clients.create!(display_name: "Foreign synthetic client")
    @intake = @workspace.project_intakes.create!(client: @client,
      title: "Confidential fictional project title", project_type: "website",
      goal: "Only fictional metadata is allowed in this study.",
      demo_consent_at: Time.current)
    @foreign_intake = @foreign_workspace.project_intakes.create!(client: @foreign_client,
      title: "Foreign fictional intake", project_type: "website",
      goal: "An unrelated fictional scope in another workspace.",
      demo_consent_at: Time.current)
    @workflow = Studio::SyntheticProjectCardWorkflow.new(
      actor: @owner, workspace: @workspace)
  end

  test "owner may create a deterministic metadata-only card exactly once" do
    counts = [ClientFact.count, ProjectMilestone.count, Consultation.count]
    first = create_card
    second = create_card
    assert_equal first, second
    assert_equal "backlog", first.fetch("state")
    assert_equal 0, first.fetch("version")
    assert_equal "requirements_spec", first.fetch("artifact_key")
    assert_equal 1, Studio::SyntheticProjectCard.count
    assert_equal 0, Studio::SyntheticProjectCardTransition.count
    assert_equal [first], @workflow.list(client: @client, intake: @intake,
      explicit_synthetic: true)
    assert_equal counts, [ClientFact.count, ProjectMilestone.count, Consultation.count]
    assert_equal false, first.fetch("client_confirmed")
    assert_equal false, first.fetch("document_generation_allowed")
    assert_equal 0, first.fetch("external_calls")
    refute_includes first.to_json, @intake.title
    refute_includes first.to_json, @client.display_name
  end

  test "serialized owner transitions preserve an immutable audit with monotonically increasing versions" do
    card = create_card
    first = advance(card, from: "backlog", to: "in_review")
    assert_equal "in_review", first.fetch("state")
    assert_equal 1, first.fetch("version")
    second = advance(first, from: "in_review", to: "on_hold")
    assert_equal "on_hold", second.fetch("state")
    assert_equal 2, second.fetch("version")
    last = advance(second, from: "on_hold", to: "backlog")
    assert_equal "backlog", last.fetch("state")
    assert_equal 3, last.fetch("version")
    rows = Studio::SyntheticProjectCardTransition.order(:sequence).to_a
    assert_equal [1, 2, 3], rows.map(&:sequence)
    assert_equal [["backlog", "in_review"], ["in_review", "on_hold"],
                  ["on_hold", "backlog"]], rows.map { |r| [r.from_state, r.to_state] }
    assert rows.all? { |r| r.actor_user_id == @owner.id && r.client_id == @client.id }
    assert_equal false, last.fetch("document_generation_allowed")
    assert_equal false, last.fetch("task_delivery_approved")
  end

  test "stale optimistic version, unsupported jumps and missing opt-in fail closed" do
    before = create_card
    after = advance(before, from: "backlog", to: "in_review")
    assert_raises(Studio::SyntheticProjectCardWorkflow::Conflict) do
      advance(before, from: "backlog", to: "in_review")
    end
    assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) do
      advance(after, from: "in_review", to: "completed")
    end
    assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) do
      advance(after, from: "in_review", to: "in_review")
    end
    assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) do
      @workflow.create!(client: @client, intake: @intake,
        artifact_key: "requirements_spec")
    end
    assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) do
      @workflow.create!(client: @client, intake: @intake, artifact_key: "untrusted_key",
        explicit_synthetic: true)
    end
    assert_equal "in_review", Studio::SyntheticProjectCard.first.reload.state
    assert_equal 1, Studio::SyntheticProjectCardTransition.count
  end

  test "model rejects bypass updates and preserves history as append-only" do
    current = create_card
    card = Studio::SyntheticProjectCard.find(current.fetch("card_id"))
    assert_not card.update(state: "in_review")
    assert_equal "backlog", card.reload.state
    assert_not card.update(artifact_key: "architecture")
    assert_equal "requirements_spec", card.reload.artifact_key
    assert_not card.destroy
    assert Studio::SyntheticProjectCard.exists?(card.id)

    first = advance(current, from: "backlog", to: "in_review")
    row = Studio::SyntheticProjectCardTransition.first
    assert_not row.update(to_state: "on_hold")
    assert_not row.destroy
    assert_equal "in_review", card.reload.state
    assert_equal 1, first.fetch("version")
    assert_equal 1, Studio::SyntheticProjectCardTransition.count
  end

  test "wrong client foreign workspace and revoked owner cannot read or mutate cards" do
    card = create_card
    assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) do
      @workflow.list(client: @wrong_client, intake: @intake, explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      @workflow.list(client: @foreign_client, intake: @foreign_intake,
        explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticProjectCardWorkflow.new(
        actor: @foreign_owner, workspace: @workspace)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      advance(card, from: "backlog", to: "in_review")
    end
    assert_equal "backlog", Studio::SyntheticProjectCard.first.state
  end

  test "production and development predicates cannot authorize synthetic writes" do
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) { create_card }
    end
    Rails.env.stub(:test?, false) do
      assert_raises(Studio::SyntheticProjectCardWorkflow::Denied) { create_card }
    end
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  test "database composite keys block direct foreign-tenant SQL injection" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Studio::SyntheticProjectCard.transaction(requires_new: true) do
        Studio::SyntheticProjectCard.insert_all!([{
          workspace_id: @foreign_workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, created_by_id: @owner.id,
          artifact_key: "requirements_spec", state: "backlog",
          lock_version: 0, created_at: Time.current, updated_at: Time.current
        }])
      end
    end
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  test "database prevents approved status and forged transition graph" do
    card = create_card
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectCard.transaction(requires_new: true) do
        Studio::SyntheticProjectCard.where(id: card.fetch("card_id"))
          .update_all(state: "approved")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Studio::SyntheticProjectCardTransition.transaction(requires_new: true) do
        Studio::SyntheticProjectCardTransition.insert_all!([{
          studio_synthetic_project_card_id: card.fetch("card_id"),
          workspace_id: @workspace.id, client_id: @client.id,
          project_intake_id: @intake.id, actor_user_id: @owner.id,
          sequence: 1, from_state: "backlog", to_state: "completed",
          recorded_at: Time.current, created_at: Time.current,
          updated_at: Time.current
        }])
      end
    end
    assert_equal "backlog", Studio::SyntheticProjectCard.first.reload.state
    assert_equal 0, Studio::SyntheticProjectCardTransition.count
  end

  private

  def create_card
    @workflow.create!(client: @client, intake: @intake,
      artifact_key: "requirements_spec", explicit_synthetic: true)
  end

  def advance(card, from:, to:)
    @workflow.transition!(client: @client, intake: @intake,
      card_id: card.fetch("card_id"), expected_state: from,
      expected_version: card.fetch("version"), to_state: to,
      explicit_synthetic: true)
  end
end
