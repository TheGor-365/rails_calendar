require "test_helper"

class IntakeSpecHumanReviewTest < ActionDispatch::IntegrationTest
  setup do
    @old_demo = ENV["RC_INTAKE_PUBLIC_DEMO"]
    @old_grok = ENV["RC_GROK_ENABLED"]
    ENV["RC_GROK_ENABLED"] = "false"
    ENV["RC_INTAKE_PUBLIC_DEMO"] = "true"
    sign_in
    post project_intakes_url, params: {
      project_intake: {
        title: "Synthetic site",
        project_type: "website",
        goal: "Provide a fictional example company landing page"
      },
      demo_consent: "1"
    }
    @intake = ProjectIntake.last
    post reply_project_intake_url(@intake), params: { answer: "Target visitors need an example contact form" }
    post draft_spec_admin_project_intake_url(@intake)
    @first_spec = @intake.latest_spec
  end

  teardown do
    ENV["RC_INTAKE_PUBLIC_DEMO"] = @old_demo
    ENV["RC_GROK_ENABLED"] = @old_grok
  end

  test "owner edits draft into next version without mutating previous AI provenance" do
    get edit_spec_admin_project_intake_url(@intake)
    assert_response :success
    assert_select "form input[name='expected_version'][value=?]", @first_spec.version.to_s

    assert_difference "IntakeSpecVersion.count", 1 do
      patch revise_spec_admin_project_intake_url(@intake), params: {
        expected_version: @first_spec.version,
        review: edited_document
      }
    end
    assert_redirected_to project_intake_url(@intake)
    revision = @intake.reload.latest_spec
    assert_equal 2, revision.version
    assert_equal "human", revision.source
    assert_equal "Revised goals approved by developer", revision.document["summary"]
    assert_equal ["Show available services", "Let visitors request a quote"], revision.document["deliverables"]
    assert_equal "template", @first_spec.reload.source
    assert_equal "draft_spec", @intake.status

    post approve_spec_admin_project_intake_url(@intake)
    assert_redirected_to project_intake_url(@intake)
    assert_equal revision.id, @intake.published_spec.id
  end

  test "stale revision and overlong content rejected without mutation" do
    assert_no_difference "IntakeSpecVersion.count" do
      patch revise_spec_admin_project_intake_url(@intake), params: {
        expected_version: 999, review: edited_document
      }
    end
    assert_response :conflict

    assert_no_difference "IntakeSpecVersion.count" do
      patch revise_spec_admin_project_intake_url(@intake), params: {
        expected_version: @first_spec.version,
        review: edited_document.merge(summary: "x" * 1201)
      }
    end
    assert_response :unprocessable_entity
    assert_equal @first_spec.id, @intake.latest_spec.id
  end

  test "published version remains available when later internal draft is generated" do
    post approve_spec_admin_project_intake_url(@intake)
    published = @intake.published_spec
    assert published.approved?

    post draft_spec_admin_project_intake_url(@intake)
    assert_equal "draft_spec", @intake.reload.status
    assert_operator @intake.latest_spec.version, :>, published.version
    assert_equal published.id, @intake.published_spec.id
  end

  test "unsigned guest cannot edit or publish the proposal" do
    delete admin_logout_url
    get edit_spec_admin_project_intake_url(@intake)
    assert_redirected_to admin_login_url
    patch revise_spec_admin_project_intake_url(@intake), params: {
      expected_version: @first_spec.version, review: edited_document
    }
    assert_redirected_to admin_login_url
    assert_equal 1, @intake.intake_spec_versions.count
  end

  private

  def edited_document
    {
      summary: "Revised goals approved by developer",
      goals: "Generate a safe example",
      deliverables: "Show available services\nLet visitors request a quote",
      acceptance_criteria: "Preview works on mobile",
      unknowns: "Approved brand palette",
      exclusions: "Live checkout"
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
