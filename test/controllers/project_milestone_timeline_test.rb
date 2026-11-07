require "test_helper"

class ProjectMilestoneTimelineTest < ActionDispatch::IntegrationTest
  setup do
    old = ENV["RC_GROK_ENABLED"]
    ENV["RC_GROK_ENABLED"] = "false"
    @intake = ProjectIntake.create!(
      title: "Fictional website example", project_type: "website",
      goal: "Synthetic business website with an example menu and quote inquiry",
      demo_consent_at: Time.current, status: "owner_approved"
    )
    document, = Intake::Grok.new(@intake).draft_spec
    @spec = @intake.intake_spec_versions.create!(
      document: document, version: 1, source: "template", owner_approved_at: Time.current
    )
    ENV["RC_GROK_ENABLED"] = old
  end

  test "only a signed-in owner can materialize a private calendar for a reviewed specification" do
    assert_no_difference ["ProjectMilestone.count", "Consultation.count"] do
      post plan_admin_project_intake_url(@intake),
           params: { start_date: "2026-11-09", confirm_plan: "1" }
    end
    assert_redirected_to admin_login_url

    sign_in
    assert_difference "ProjectMilestone.count", 3 do
      assert_no_difference "Consultation.count" do
        post plan_admin_project_intake_url(@intake),
             params: { start_date: "2026-11-09", confirm_plan: "1" }
      end
    end
    assert_redirected_to project_intake_url(@intake)
    rows = @intake.project_milestones.order(:position).to_a
    assert_equal [1, 2, 3], rows.map(&:position)
    assert_equal [2, 5, 2], rows.map(&:suggested_work_days)
    assert_equal Date.new(2026, 11, 9), rows[0].start_on
    assert_equal Date.new(2026, 11, 10), rows[0].end_on
    assert_equal Date.new(2026, 11, 11), rows[1].start_on
    assert_equal Date.new(2026, 11, 17), rows[1].end_on
    assert_equal Date.new(2026, 11, 18), rows[2].start_on
    assert_equal Date.new(2026, 11, 19), rows[2].end_on
    assert rows.all? { |m| m.status == "proposed" && m.intake_spec_version_id == @spec.id }

    get project_intake_url(@intake)
    assert_response :success
    assert_select "#private-project-calendar"
    assert_select "#intake-month-grid"
    assert_select "time[datetime='2026-11-19']", minimum: 1
  end

  test "the same approved specification cannot generate the timeline twice" do
    sign_in
    post plan_admin_project_intake_url(@intake),
         params: { start_date: "2026-11-07", confirm_plan: "1" }
    assert_redirected_to project_intake_url(@intake)
    assert_equal Date.new(2026, 11, 9), @intake.project_milestones.order(:position).first.start_on

    assert_no_difference "ProjectMilestone.count" do
      post plan_admin_project_intake_url(@intake),
           params: { start_date: "2026-12-01", confirm_plan: "1" }
    end
    assert_response :conflict
  end

  test "invalid date or missing explicit confirmation has no effect" do
    sign_in
    ["2026-02-31", "foo", ""].each do |invalid|
      assert_no_difference "ProjectMilestone.count" do
        post plan_admin_project_intake_url(@intake),
             params: { start_date: invalid, confirm_plan: "1" }
      end
      assert_response :unprocessable_entity
    end

    assert_no_difference "ProjectMilestone.count" do
      post plan_admin_project_intake_url(@intake),
           params: { start_date: "2026-11-09" }
    end
    assert_response :unprocessable_entity
  end

  test "unapproved specification cannot create a timeline" do
    sign_in
    @spec.update!(owner_approved_at: nil)
    assert_no_difference "ProjectMilestone.count" do
      post plan_admin_project_intake_url(@intake),
           params: { start_date: "2026-11-09", confirm_plan: "1" }
    end
    assert_response :conflict
  end

  private

  def sign_in
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
