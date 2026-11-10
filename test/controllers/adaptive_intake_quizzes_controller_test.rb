require "test_helper"

class AdaptiveIntakeQuizzesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @intake = ProjectIntake.create!(
      title: "Fictional Bakery Adaptive Preview",
      project_type: "website",
      goal: "Build an illustrative website that collects fictional leads.",
      demo_consent_at: Time.current
    )
  end

  test "adaptive preview and saved review are owner only, not legacy admin" do
    get adaptive_project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
    get review_adaptive_project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
    assert_no_difference "IntakeAnswer.count" do
      patch adaptive_project_intake_quiz_answer_path(@intake, question_key: "business_goals"),
            params: { quiz: { revision: "0", selected_options: ["leads"] } }
    end
    assert_redirected_to sign_in_path

    post admin_session_path, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_response :redirect
    get adaptive_project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
  end

  test "owner sees adaptive preview, old two-question quiz remains unchanged" do
    sign_in_owner
    get adaptive_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /What should this work achieve/
    assert_select "form"
    assert_select "input[name='quiz[revision]'][value='0']"

    get project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /main desired outcome/
    assert_select ".rc-quiz-progress__header", text: /0 \/ 2 answers saved/
    get project_intake_path(@intake)
    assert_response :success
    assert_select "a", text: /Open adaptive Quiz/
  end

  test "saves and resumes immutable adaptive answers" do
    sign_in_owner
    assert_difference ["IntakeAnswer.count", "IntakeAnswerRevision.count"], 1 do
      patch_answer("business_goals", %w[leads reliability], revision: "0")
    end
    assert_redirected_to adaptive_project_intake_quiz_path(@intake, step: "audiences")
    answer = @intake.intake_answers.find_by!(question_key: "business_goals")
    assert_equal %w[leads reliability], answer.selected_options
    assert_equal 1, answer.revision
    assert_equal Intake::AdaptiveQuestionCatalog::VERSION,
                 answer.intake_answer_revisions.sole.snapshot["catalog_version"]
    assert_equal "What should this work achieve?",
                 answer.intake_answer_revisions.sole.snapshot["question_title"]
    assert_equal({ "leads" => "More enquiries", "reliability" => "Better reliability" },
                 answer.intake_answer_revisions.sole.snapshot.fetch("selected_labels"))

    get adaptive_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /Who will use or benefit from it/
    get adaptive_project_intake_quiz_path(@intake, step: "business_goals")
    assert_response :success
    assert_select "input[name='quiz[revision]'][value='1']"
    assert_select "input[type='checkbox'][value='leads'][checked]"
  end

  test "website checkout is only writable when its parent answer selects catalogue" do
    sign_in_owner
    get adaptive_project_intake_quiz_path(@intake, step: "website_checkout")
    assert_response :not_found
    assert_no_difference "IntakeAnswer.count" do
      patch_answer("website_checkout", ["checkout"], revision: "0")
    end
    assert_response :not_found

    patch_answer("website_pages", ["catalogue"], revision: "0")
    assert_redirected_to adaptive_project_intake_quiz_path(@intake, step: "website_checkout")
    get adaptive_project_intake_quiz_path(@intake, step: "website_checkout")
    assert_response :success
    assert_select "h1", text: /What must the catalogue support/
    patch_answer("website_checkout", ["checkout"], revision: "0")
    assert_equal ["checkout"], @intake.intake_answers.find_by!(question_key: "website_checkout").selected_options
  end

  test "changing a parent excludes hidden child from review but keeps history" do
    sign_in_owner
    patch_answer("website_pages", ["catalogue"], revision: "0")
    patch_answer("website_checkout", ["checkout"], revision: "0")
    assert_equal 1, @intake.intake_answers.find_by!(question_key: "website_checkout").revision

    assert_no_difference "IntakeAnswerRevision.count" do
      patch_answer("website_pages", ["landing"], revision: "1")
    end
    assert_response :unprocessable_entity
    assert_select "button[name='quiz[confirm_branch_change]'][value='1']"
    assert_equal ["catalogue"], @intake.intake_answers.find_by!(question_key: "website_pages").selected_options

    patch_answer("website_pages", ["landing"], revision: "1", confirmation: "1")
    assert_response :redirect
    get adaptive_project_intake_quiz_path(@intake, step: "website_checkout")
    assert_response :not_found
    assert_no_difference "IntakeAnswerRevision.count" do
      patch_answer("website_checkout", ["cart"], revision: "1")
    end
    assert_response :not_found

    get review_adaptive_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select ".rc-notice", text: /historic answer/
    assert_select ".rc-quiz-review-item", text: /What must the catalogue support/, count: 0
    child = @intake.intake_answers.find_by!(question_key: "website_checkout")
    assert_equal ["checkout"], child.selected_options
    assert_equal 1, child.intake_answer_revisions.count
    assert_equal 2, @intake.intake_answers.find_by!(question_key: "website_pages").revision
  end

  test "stale tab cannot silently overwrite a saved answer" do
    sign_in_owner
    patch_answer("business_goals", ["leads"], revision: "0")
    answer = @intake.intake_answers.find_by!(question_key: "business_goals")
    assert_no_difference "IntakeAnswerRevision.count" do
      patch_answer("business_goals", ["sales"], revision: "0")
    end
    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /changed in another tab/
    assert_equal ["leads"], answer.reload.selected_options
    assert_equal 1, answer.revision
  end

  test "invalid selections never save and keep the submitted other answer" do
    sign_in_owner
    assert_no_difference "IntakeAnswer.count" do
      patch adaptive_project_intake_quiz_answer_path(@intake, question_key: "business_goals"),
            params: { quiz: { revision: "0", selected_options: ["unlisted"], other_text: "Fictional detail" } }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='quiz[other_text]'][value='Fictional detail']"
    assert_select "[role='alert']"
  end

  test "feature priorities persist in snapshots and invalid priority writes are rejected" do
    sign_in_owner
    patch_answer("website_pages", %w[landing catalogue], revision: "0",
                 priorities: { "landing" => "must", "catalogue" => "should" })
    assert_response :redirect
    answer = @intake.intake_answers.find_by!(question_key: "website_pages")
    assert_equal({ "landing" => "must", "catalogue" => "should" }, answer.feature_priorities)
    assert_equal answer.feature_priorities,
                 answer.intake_answer_revisions.sole.snapshot.fetch("feature_priorities")

    assert_no_difference "IntakeAnswerRevision.count" do
      patch_answer("website_pages", ["landing"], revision: "1",
                   priorities: { "landing" => "unexpected" })
    end
    assert_response :unprocessable_entity
    assert_equal %w[landing catalogue], answer.reload.selected_options

    assert_no_difference "IntakeAnswerRevision.count" do
      patch_answer("website_pages", ["landing"], revision: "1", priorities: {})
    end
    assert_response :unprocessable_entity
  end

  test "all visible questions can be saved offline and review is a private draft" do
    sign_in_owner
    questions = Intake::AdaptiveQuestionCatalog.for("website")
    questions.each do |question|
      patch_answer(question.fetch(:key), [question.fetch(:options).keys.first], revision: "0", navigation: "review")
      assert_response :redirect
    end
    get review_adaptive_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select ".rc-quiz-review-ready", text: /All #{questions.size} visible questions saved/
    assert_select ".rc-quiz-review-item", count: questions.size
    assert_select "form[action*='submit']", count: 0
    assert_equal questions.size, @intake.intake_answers.count
    assert_equal questions.size, IntakeAnswerRevision.joins(:intake_answer)
                                             .where(intake_answers: { project_intake_id: @intake.id }).count
  end

  private

  def sign_in_owner
    password = "fictional-owner-test-password-12345"
    owner = User.create!(
      email: "adaptive-owner@example.test",
      role: "owner", password: password, password_confirmation: password
    )
    post account_session_path, params: { email: owner.email, password: password }
    assert_redirected_to consultations_path
  end

  def patch_answer(key, choices, revision:, navigation: "continue", confirmation: nil, priorities: nil)
    priorities ||= Intake::AdaptiveQuestionCatalog.prioritizable?(key) ? choices.index_with { "must" } : {}
    patch adaptive_project_intake_quiz_answer_path(@intake, question_key: key),
          params: { quiz: { revision: revision, selected_options: choices, navigation: navigation,
                            confirm_branch_change: confirmation, feature_priorities: priorities } }
  end
end
