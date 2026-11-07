require "test_helper"

class ProjectIntakeFlowTest < ActionDispatch::IntegrationTest
  setup do
    @old_demo = ENV["RC_INTAKE_PUBLIC_DEMO"]
    @old_grok = ENV["RC_GROK_ENABLED"]
    ENV["RC_GROK_ENABLED"] = "false"
    ENV.delete("RC_INTAKE_PUBLIC_DEMO")
  end

  teardown do
    ENV["RC_INTAKE_PUBLIC_DEMO"] = @old_demo
    ENV["RC_GROK_ENABLED"] = @old_grok
  end

  test "public intake is closed by default but admin may use synthetic demonstration" do
    get new_project_intake_url
    assert_redirected_to admin_login_url

    sign_in
    get new_project_intake_url
    assert_response :success
    assert_select "input[name='demo_consent']"
  end

  test "consent and server validations prevent accidental data collection" do
    sign_in
    assert_no_difference "ProjectIntake.count" do
      post project_intakes_url, params: {
        project_intake: { title: "Example bakery", project_type: "website", goal: "A fictional site with a menu" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /Consent/

    assert_no_difference "ProjectIntake.count" do
      post project_intakes_url, params: {
        project_intake: { title: "Too short", project_type: "malicious", goal: "abc" },
        demo_consent: "1"
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin creates synthetic intake, interviews and reviews a versioned specification" do
    sign_in
    create_demo_intake
    intake = ProjectIntake.last
    assert_equal "interviewing", intake.status
    assert_equal 1, intake.intake_messages.count
    assert_redirected_to project_intake_url(intake)

    get project_intake_url(intake)
    assert_response :success
    assert_select "#intake-conversation li", count: 1

    post reply_project_intake_url(intake),
         params: { answer: "The goal is a sample menu and online quote request without payments." }
    assert_redirected_to project_intake_url(intake)
    assert_equal %w[assistant client assistant], intake.intake_messages.order(:id).pluck(:role)
    assert_equal 0, IntakeAiQuota.count, "default demo must never spend AI tokens"

    post draft_spec_admin_project_intake_url(intake)
    assert_redirected_to project_intake_url(intake)
    spec = intake.intake_spec_versions.last
    assert_equal 1, spec.version
    assert_equal "template", spec.source
    assert_equal "draft_spec", intake.reload.status

    get project_intake_url(intake)
    assert_response :success
    assert_select "section[aria-label='Technical specification'] h2", text: "Draft technical specification"
    assert_select "ol li", minimum: 1

    post approve_spec_admin_project_intake_url(intake)
    assert_redirected_to project_intake_url(intake)
    assert spec.reload.approved?
    assert_equal "owner_approved", intake.reload.status

    post acknowledge_project_intake_url(intake)
    assert_redirected_to project_intake_url(intake)
    assert spec.reload.client_reviewed_at.present?
    assert_equal "client_reviewed", intake.reload.status
  end

  test "a guest cannot open another browser session's client project" do
    ENV["RC_INTAKE_PUBLIC_DEMO"] = "true"
    create_demo_intake
    owned = ProjectIntake.last

    foreign = ProjectIntake.create!(
      title: "Other visitor", project_type: "website",
      goal: "Synthetic mock site for other visitor",
      demo_consent_at: Time.current
    )
    get project_intake_url(owned)
    assert_response :success
    get project_intake_url(foreign)
    assert_response :not_found

    post reply_project_intake_url(foreign), params: { answer: "Attacker message" }
    assert_response :not_found
    assert_equal 0, foreign.intake_messages.count
  end

  test "a guest cannot generate or approve a technical specification" do
    ENV["RC_INTAKE_PUBLIC_DEMO"] = "true"
    create_demo_intake
    intake = ProjectIntake.last

    post draft_spec_admin_project_intake_url(intake)
    assert_redirected_to admin_login_url
    post approve_spec_admin_project_intake_url(intake)
    assert_redirected_to admin_login_url
    assert_equal 0, intake.intake_spec_versions.count
  end

  test "invalid chat input is rejected without Grok charges or stored messages" do
    sign_in
    create_demo_intake
    intake = ProjectIntake.last

    assert_no_difference "IntakeMessage.count" do
      post reply_project_intake_url(intake), params: { answer: "X" * 1400 }
    end
    assert_response :unprocessable_entity
    assert_equal 0, IntakeAiQuota.count
  end

  private

  def create_demo_intake
    post project_intakes_url, params: {
      project_intake: {
        title: "Fictional bakery website",
        project_type: "website",
        goal: "Help visitors find the menu and submit a fictional catering enquiry"
      },
      demo_consent: "1"
    }
  end

  def sign_in
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
