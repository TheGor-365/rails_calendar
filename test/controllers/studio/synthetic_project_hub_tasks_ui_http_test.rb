require "test_helper"

class StudioSyntheticProjectHubTasksUiHttpTest < ActionDispatch::IntegrationTest
  setup do
    salt = SecureRandom.hex(5)
    @password = "rc039-h-fictional-owner-password"
    @owner = User.create!(email: "rc039-h-owner-#{salt}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @foreign_owner = User.create!(email: "rc039-h-foreign-#{salt}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @workspace = Workspace.create!(owner_user: @owner,
      name: "Private fictional task board", slug: "rc039-h-#{salt}")
    @foreign_workspace = Workspace.create!(owner_user: @foreign_owner,
      name: "Foreign fictional task board", slug: "rc039-h-other-#{salt}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @foreign_owner,
      role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "SENSITIVE FICTIONAL CLIENT NAME")
    @other_client = @workspace.clients.create!(display_name: "OTHER CLIENT")
    @intake = make_intake(@workspace, @client)
    @foreign_client = @foreign_workspace.clients.create!(display_name: "FOREIGN CLIENT")
    @foreign_intake = make_intake(@foreign_workspace, @foreign_client)
  end

  test "owner gets separate six fictional tasks and nine artifacts with no private text or mutation" do
    sign_in(@owner)
    assert_no_difference ["Studio::SyntheticProjectTask.count",
                          "Studio::SyntheticProjectTaskEvent.count",
                          "Studio::SyntheticProjectCard.count", "ProjectMilestone.count",
                          "Consultation.count", "ClientFact.count"] do
      get preview_path
    end
    assert_response :success
    assert_select "li.rc-hub-card", 9
    assert_select "li.rc-hub-task", 6
    assert_select "section#rc_hub_tasks[aria-labelledby='rc_hub_tasks_title']", 1
    assert_select "form[action='#{tasks_path}']", 6
    assert_select "form input[name='task_key']", 6
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    refute_includes response.body, @client.display_name
    refute_includes response.body, @intake.title
    refute_includes response.body, @intake.goal
    refute_includes response.body, "Real client approved"
  end

  test "fixed task creation is idempotent; priority and versioned lifecycle update through HTML" do
    sign_in(@owner)
    assert_difference "Studio::SyntheticProjectTask.count", 1 do
      post tasks_path, params: {
        task_key: "scope_review", state: "completed", priority: "1",
        client_approved: "true", source: "UNTRUSTED_PRIVATE_BYTES"
      }
    end
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    row = Studio::SyntheticProjectTask.sole
    assert_equal "proposed", row.state
    assert_equal 3, row.priority
    assert_no_difference "Studio::SyntheticProjectTask.count" do
      post tasks_path, params: { task_key: "scope_review" }
    end
    assert_redirected_to "#{preview_path}#rc_hub_tasks"

    get preview_path
    assert_select "[data-task-key='scope_review'] input[name='expected_version'][value='0']", 2
    assert_select "[data-task-key='scope_review'] select[name='to_state']", 1
    assert_select "[data-task-key='scope_review'] select[name='priority']", 1
    refute_includes response.body, "UNTRUSTED_PRIVATE_BYTES"

    assert_difference "Studio::SyntheticProjectTaskEvent.count", 1 do
      patch state_path(row.id), params: {
        expected_state: "proposed", expected_version: "0", to_state: "ready",
        approved: "true"
      }
    end
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    assert_equal "ready", row.reload.state
    assert_equal 1, row.lock_version

    assert_difference "Studio::SyntheticProjectTaskEvent.count", 1 do
      patch priority_path(row.id), params: {
        expected_state: "ready", expected_version: "1", priority: "1"
      }
    end
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    assert_equal 1, row.reload.priority
    assert_equal 2, row.lock_version
    get preview_path
    assert_select "[data-task-key='scope_review']", text: /Priority 1/
    assert_select "[data-task-key='scope_review']", text: /Revision 2/
    assert_equal 9, Nokogiri::HTML(response.body).css("li.rc-hub-card").size
    assert_equal 2, Studio::SyntheticProjectTaskEvent.count
    assert_equal 0, Studio::SyntheticProjectCard.count
  end

  test "stale task state and illegal input return scoped live board without reflecting inputs" do
    sign_in(@owner)
    row = create_task("scope_review")
    patch state_path(row.id), params: {
      expected_state: "proposed", expected_version: "0", to_state: "ready"
    }
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch state_path(row.id), params: {
        expected_state: "proposed", expected_version: "0", to_state: "ready",
        source: "FORGED_CLIENT_SOURCE"
      }
    end
    assert_response :conflict
    assert_select "section[role='alert']", text: /Engineering task changed/
    assert_select "[data-task-key='scope_review']", text: /Revision 1/
    assert_select "[data-task-key='scope_review'] input[name='expected_version'][value='1']", 2
    assert_not_includes response.body, "FORGED_CLIENT_SOURCE"

    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch state_path(row.id), params: {
        expected_state: "ready", expected_version: "1", to_state: "approved"
      }
    end
    assert_response :unprocessable_entity
    assert_select "section[role='alert']", text: /transition denied/

    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch priority_path(row.id), params: {
        expected_state: "ready", expected_version: "1", priority: "0"
      }
    end
    assert_response :unprocessable_entity
    assert_equal "ready", row.reload.state
    assert_equal 3, row.priority
  end

  test "fictional dependency blocks readiness, forbids cycles and does not affect calendar" do
    sign_in(@owner)
    prerequisite = create_task("scope_review")
    dependent = create_task("solution_design")
    baseline = [ProjectMilestone.count, Consultation.count, Studio::SyntheticProjectCard.count]
    assert_difference "Studio::SyntheticProjectTaskDependency.count", 1 do
      post dependencies_path, params: {
        dependent_task_id: dependent.id, prerequisite_task_id: prerequisite.id,
        due_on: "2026-11-12", client_confirmed: "true"
      }
    end
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    get preview_path
    assert_select "[data-task-key='solution_design']", text: /Scope review — Proposed/
    assert_select "[data-task-key='solution_design']", text: /Waiting for 1/
    assert_select "[data-task-key='solution_design'] select[name='to_state']", 0

    assert_no_difference "Studio::SyntheticProjectTaskDependency.count" do
      post dependencies_path, params: {
        dependent_task_id: prerequisite.id, prerequisite_task_id: dependent.id
      }
    end
    assert_response :unprocessable_entity
    assert_select "section[role='alert']", text: /dependency rejected/

    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch state_path(dependent.id), params: {
        expected_state: "proposed", expected_version: "0", to_state: "ready"
      }
    end
    assert_response :unprocessable_entity
    assert_equal "proposed", dependent.reload.state
    assert_equal baseline, [ProjectMilestone.count, Consultation.count, Studio::SyntheticProjectCard.count]

    [["proposed", 0, "ready"], ["ready", 1, "in_progress"],
     ["in_progress", 2, "completed"]].each do |state, version, target|
      patch state_path(prerequisite.id), params: {
        expected_state: state, expected_version: version.to_s, to_state: target
      }
      assert_redirected_to "#{preview_path}#rc_hub_tasks"
    end
    patch state_path(dependent.id), params: {
      expected_state: "proposed", expected_version: "0", to_state: "ready"
    }
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    assert_equal "ready", dependent.reload.state
  end

  test "guests, foreign owners, swapped clients and revoked membership cannot read or change tasks" do
    get preview_path
    assert_redirected_to sign_in_path
    assert_no_difference "Studio::SyntheticProjectTask.count" do
      post tasks_path, params: { task_key: "scope_review" }
    end
    assert_redirected_to sign_in_path

    sign_in(@foreign_owner)
    get preview_path
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectTask.count" do
      post tasks_path, params: { task_key: "scope_review" }
    end
    assert_response :not_found

    sign_in(@owner)
    row = create_task("scope_review")
    wrong_path = "/workspaces/#{@workspace.id}/clients/#{@other_client.id}/project_intakes/#{@intake.id}/project_hub/preview"
    get wrong_path
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch "#{wrong_path}/tasks/#{row.id}/state",
        params: { expected_state: "proposed", expected_version: "0", to_state: "ready" }
    end
    assert_response :not_found
    foreign_path = "/workspaces/#{@foreign_workspace.id}/clients/#{@foreign_client.id}/project_intakes/#{@foreign_intake.id}/project_hub/preview"
    get foreign_path
    assert_response :not_found

    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    get preview_path
    assert_response :not_found
    assert_no_difference "Studio::SyntheticProjectTaskEvent.count" do
      patch state_path(row.id),
        params: { expected_state: "proposed", expected_version: "0", to_state: "ready" }
    end
    assert_response :not_found
  end

  test "production/non-test hard denial and enabled Rails CSRF protect new task actions" do
    sign_in(@owner)
    Rails.env.stub(:production?, true) do
      get preview_path
      assert_response :not_found
      post tasks_path, params: { task_key: "scope_review" }
      assert_response :not_found
    end
    Rails.env.stub(:test?, false) do
      get preview_path
      assert_response :not_found
      post tasks_path, params: { task_key: "scope_review" }
      assert_response :not_found
    end
    previous = ActionController::Base.allow_forgery_protection
    previous_origin = ActionController::Base.forgery_protection_origin_check
    begin
      ActionController::Base.allow_forgery_protection = true
      ActionController::Base.forgery_protection_origin_check = true
      get preview_path
      assert_response :success
      assert_no_difference "Studio::SyntheticProjectTask.count" do
        assert_raises(ActionController::InvalidAuthenticityToken) do
          post tasks_path, params: { task_key: "scope_review" }
        end
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous
      ActionController::Base.forgery_protection_origin_check = previous_origin
    end
  end

  private

  def make_intake(ws, client)
    ws.project_intakes.create!(client: client, title: "SECRET INTEND TITLE",
      project_type: "website", goal: "PRIVATE FICTIONAL GOAL HIDDEN FROM BOARD.",
      demo_consent_at: Time.current)
  end

  def preview_path
    rc039_synthetic_project_hub_preview_path(@workspace, @client, @intake)
  end

  def tasks_path
    rc039_synthetic_project_hub_preview_tasks_path(@workspace, @client, @intake)
  end

  def state_path(id)
    rc039_synthetic_project_hub_preview_task_state_path(@workspace, @client, @intake, id)
  end

  def priority_path(id)
    rc039_synthetic_project_hub_preview_task_priority_path(@workspace, @client, @intake, id)
  end

  def dependencies_path
    rc039_synthetic_project_hub_preview_task_dependencies_path(@workspace, @client, @intake)
  end

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: @password }
    assert_redirected_to consultations_path
  end

  def create_task(key)
    post tasks_path, params: { task_key: key }
    assert_redirected_to "#{preview_path}#rc_hub_tasks"
    Studio::SyntheticProjectTask.find_by!(project_intake_id: @intake.id, task_key: key)
  end
end
