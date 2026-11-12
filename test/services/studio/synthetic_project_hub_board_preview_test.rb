require "test_helper"

class StudioSyntheticProjectHubBoardPreviewTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(5)
    password = "rc039-fictional-board-test-only"
    @owner = User.create!(email: "hub-owner-#{suffix}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @other_owner = User.create!(email: "hub-outsider-#{suffix}@example.test",
      password: password, password_confirmation: password, role: "owner")
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Fictional board workspace", slug: "hub-#{suffix}")
    @other_workspace = Workspace.create!(owner_user: @other_owner,
      name: "Foreign board workspace", slug: "hub-other-#{suffix}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @other_workspace, user: @other_owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Fictional board client")
    @other_client = @workspace.clients.create!(display_name: "Another fictional client")
    @foreign_client = @other_workspace.clients.create!(display_name: "Foreign fictional client")
    @intake = @workspace.project_intakes.create!(client: @client,
      title: "A secret fictional project title", project_type: "website",
      goal: "This fictional goal must never be copied into board payloads.",
      demo_consent_at: Time.current)
    @service = Studio::SyntheticProjectHubBoardPreview.new(
      actor: @owner, workspace: @workspace)
  end

  test "deterministic four-lane project board contains nine gated cards" do
    result = preview
    assert_equal result, preview
    assert_equal "rc039-synthetic-project-board.v1", result.fetch("schema_version")
    assert_equal "FICTIONAL_READ_ONLY_PROJECT_HUB", result.fetch("classification")
    assert_equal %w[discovery definition planning handoff],
      result.fetch("lanes").map { |lane| lane.fetch("key") }
    assert_equal 9, result.fetch("card_count")
    assert_equal 9, result.fetch("blocked_card_count")
    assert_equal 9, result.fetch("cards").map { |c| c.fetch("key") }.uniq.length
    assert result.fetch("cards").all? { |card|
      card.fetch("generation_status") == "blocked" &&
        card.fetch("status") == "blocked_unverified" &&
        card.fetch("prerequisites").any? &&
        !card.fetch("artifact_created") &&
        !card.fetch("timeline_scheduled") &&
        card.fetch("requires_client_confirmation")
    }
    assert_equal [], result.dig("project_calendar", "scheduled_items")
    assert_equal true, result.dig("project_calendar", "independent_of_consultations")
    assert_equal false, result.fetch("document_generation_allowed")
    assert_equal false, result.fetch("drag_and_drop_allowed")
    assert_equal false, result.fetch("persisted")
  end

  test "dependencies are explicit only unverified evidence, not approved tasks" do
    result = preview
    edges = result.fetch("dependency_edges")
    assert_equal result.fetch("cards").sum { |c| c.fetch("prerequisites").length }, edges.length
    assert edges.all? { |edge|
      edge.fetch("relationship") == "unmet_prerequisite" &&
        result.fetch("cards").any? { |c|
          c.fetch("key") == edge.fetch("to_card") &&
            c.fetch("prerequisites").include?(edge.fetch("from_evidence"))
        }
    }
    finance = result.fetch("cards").find { |c| c.fetch("key") == "financial_scenarios" }
    assert_equal %w[roadmap_reviewed rates_confirmed costs_confirmed],
      finance.fetch("prerequisites")
    assert_equal false, result.fetch("scope_approved")
    assert_equal false, result.fetch("client_confirmed")
    assert_equal 0, result.fetch("external_calls")
    assert_equal 0, result.fetch("billable_usd")
  end

  test "data minimization and isolation do not write projects milestones or consultations" do
    before = [ProjectIntake.count, ProjectMilestone.count, Consultation.count,
              Studio::SyntheticReviewDecision.count, ClientFact.count]
    result = preview
    assert_equal before, [ProjectIntake.count, ProjectMilestone.count,
      Consultation.count, Studio::SyntheticReviewDecision.count, ClientFact.count]
    refute_includes result.to_json, @intake.title
    refute_includes result.to_json, @intake.goal
    refute_includes result.to_json, @client.display_name
    assert_equal [], result.dig("project_calendar", "scheduled_items")
    assert_equal false, result.fetch("automatic_task_transitions")
  end

  test "same-workspace swapped client and foreign workspace both deny" do
    assert_raises(Studio::SyntheticProjectHubBoardPreview::Denied) do
      @service.call(client: @other_client, intake: @intake, explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      @service.call(client: @foreign_client, intake: @intake, explicit_synthetic: true)
    end
    assert_raises(SecurityError) do
      Studio::SyntheticProjectHubBoardPreview.new(
        actor: @other_owner, workspace: @workspace)
    end
  end

  test "missing opt-in, production and revoked owner all fail closed" do
    assert_raises(Studio::SyntheticProjectHubBoardPreview::Denied) do
      @service.call(client: @client, intake: @intake)
    end
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::SyntheticProjectHubBoardPreview::Denied) { preview }
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { preview }
  end

  private

  def preview
    @service.call(client: @client, intake: @intake, explicit_synthetic: true)
  end
end
