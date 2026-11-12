require "test_helper"

class OwnerOfflineWorkflowE2eTest < ActionDispatch::IntegrationTest
  setup do
    @prior_ai = ENV["RC_GROK_ENABLED"]
    @prior_public = ENV["RC_INTAKE_PUBLIC_DEMO"]
    ENV["RC_GROK_ENABLED"] = "false"
    ENV.delete("RC_INTAKE_PUBLIC_DEMO")
  end

  teardown do
    ENV["RC_GROK_ENABLED"] = @prior_ai
    ENV["RC_INTAKE_PUBLIC_DEMO"] = @prior_public
  end

  test "owner can complete synthetic request through approved version and milestones with AI OFF" do
    owner = User.create!(
      email: "offline-owner-journey@example.test", role: "owner",
      password: "safe-offline-journey-password-2026"
    )
    post account_session_path, params: {
      email: owner.email, password: "safe-offline-journey-password-2026"
    }
    assert_redirected_to workspace_path

    get workspace_path
    assert_response :success
    get new_project_intake_path
    assert_response :success

    assert_difference "ProjectIntake.count", 1 do
      post project_intakes_path, params: {
        project_intake: {
          title: "Synthetic bakery owner journey", project_type: "website",
          goal: "Create a fictional bakery website with an enquiry flow"
        }, demo_consent: "1"
      }
    end
    intake = ProjectIntake.order(:id).last
    assert_redirected_to project_intake_path(intake)
    assert_equal "interviewing", intake.status

    get project_intake_quiz_path(intake, step: "outcome")
    assert_response :success

    assert_difference ["IntakeAnswer.count", "IntakeAnswerRevision.count"], 2 do
      patch project_intake_quiz_answer_path(intake, question_key: "outcome"),
            params: {quiz: {selected_options: ["leads"]}}
      assert_redirected_to project_intake_quiz_path(intake, step: "features")

      patch project_intake_quiz_answer_path(intake, question_key: "features"),
            params: {quiz: {selected_options: %w[contact_form search], navigation: "review"}}
      assert_redirected_to review_project_intake_quiz_path(intake)
    end
    get review_project_intake_quiz_path(intake)
    assert_response :success
    assert_select ".rc-quiz-review-ready"
    assert_equal ["leads"], intake.intake_answers.find_by!(question_key: "outcome").selected_options

    assert_no_difference "IntakeAiQuota.count" do
      post reply_project_intake_path(intake),
           params: {answer: "Synthetic visitors should ask questions about menu items"}
      assert_redirected_to project_intake_path(intake)
    end
    assert_equal "template", intake.intake_messages.order(:id).last.role == "assistant" ? "template" : "unexpected"

    assert_no_difference "IntakeAiQuota.count" do
      post draft_spec_admin_project_intake_path(intake)
      assert_redirected_to project_intake_path(intake)
    end
    first = intake.latest_spec
    assert first.present?
    assert_equal "template", first.source
    assert_equal "draft_spec", intake.reload.status
    assert_nil first.owner_approved_at

    get edit_spec_admin_project_intake_path(intake)
    assert_response :success

    assert_difference "IntakeSpecVersion.count", 1 do
      patch revise_spec_admin_project_intake_path(intake), params: {
        expected_version: first.version,
        review: {
          summary: "Owner-reviewed fictional bakery requirements",
          goals: "Provide information and example enquiries",
          deliverables: "Landing page\nEnquiry form",
          acceptance_criteria: "Demo form tested on mobile",
          unknowns: "Fictional brand palette",
          exclusions: "Real payments"
        }
      }
    end
    assert_redirected_to project_intake_path(intake)
    revised = intake.latest_spec
    assert_equal first.version + 1, revised.version
    assert_equal "human", revised.source
    assert_nil revised.owner_approved_at
    assert_equal "template", first.reload.source

    post approve_spec_admin_project_intake_path(intake)
    assert_redirected_to project_intake_path(intake)
    assert revised.reload.approved?
    assert_equal revised.id, intake.published_spec.id

    assert_difference "ProjectMilestone.count", 3 do
      post plan_admin_project_intake_path(intake), params: {
        start_date: "2026-11-18", confirm_plan: "1"
      }
    end
    assert_redirected_to project_intake_path(intake)
    assert intake.project_milestones.order(:position).all? { |m| m.status == "proposed" }
    get project_intake_path(intake)
    assert_response :success
    assert_select "#private-project-calendar"
    assert_equal 0, IntakeAiQuota.count

    delete sign_out_path
    assert_redirected_to root_path
    get project_intake_path(intake)
    assert_response :not_found
    get edit_spec_admin_project_intake_path(intake)
    assert_redirected_to admin_login_path
  end
end
