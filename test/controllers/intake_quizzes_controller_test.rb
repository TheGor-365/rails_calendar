require "test_helper"

class IntakeQuizzesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @intake = ProjectIntake.create!(
      title: "Fictional Bakery Website", project_type: "website",
      goal: "Create a fictional website to explain baked goods and collect enquiries",
      demo_consent_at: Time.current
    )
  end

  test "quiz is private without owner or administrator session" do
    get project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: ["contact_form"] } }
    assert_redirected_to sign_in_path

    sign_in_as_legacy_admin
    get project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
  end

  test "save revise and review typed answers with immutable revisions" do
    sign_in_as_owner
    get project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "form"

    assert_difference "IntakeAnswer.count", 1 do
      patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
            params: { quiz: { selected_options: ["leads"], comment: "Fictional test" } }
    end
    assert_redirected_to project_intake_quiz_path(@intake, step: "features")

    answer = @intake.intake_answers.find_by!(question_key: "outcome")
    assert_equal ["leads"], answer.selected_options
    assert_equal 1, answer.revision
    assert_equal 1, answer.intake_answer_revisions.count

    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["leads"], comment: "Fictional test" } }
    assert_equal 1, answer.reload.revision

    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["sales"], other_text: "New demo note" } }
    assert_equal 2, answer.reload.revision
    assert_equal 2, answer.intake_answer_revisions.count
    assert_equal ["leads"], answer.intake_answer_revisions.order(:revision).first.snapshot["selected_options"]

    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: %w[contact_form search], comment: "Fictional pages" } }
    assert_redirected_to review_project_intake_quiz_path(@intake)
    assert_equal %w[contact_form search], @intake.intake_answers.find_by!(question_key: "features").selected_options

    get review_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /Review your selections/
  end

  test "invalid options rejected and an unsure answer is supported" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["unexpected_option"] } }
    assert_response :unprocessable_entity
    assert_equal 0, @intake.intake_answers.count

    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: [], unsure: "1" } }
    assert_redirected_to project_intake_quiz_path(@intake, step: "features")
    assert @intake.intake_answers.find_by!(question_key: "outcome").unsure
  end

  test "review shortcut saves multi-select before navigation" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["leads"] } }

    assert_difference ["IntakeAnswer.count", "IntakeAnswerRevision.count"], 1 do
      patch project_intake_quiz_answer_path(@intake, question_key: "features"),
            params: { quiz: { selected_options: %w[contact_form catalogue], navigation: "review" } }
    end
    assert_redirected_to review_project_intake_quiz_path(@intake)
    get review_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "li", text: /Contact form/
    assert_select "li", text: /Catalogue/
    assert_select ".rc-quiz-review-ready", text: /All 2 questions are saved/
  end

  test "default quiz path resumes next unanswered step and shows review after completion" do
    sign_in_as_owner
    get project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /main desired outcome/

    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["leads"] } }
    get project_intake_quiz_path(@intake)
    assert_response :success
    assert_select "h1", text: /included or investigated/
    assert_select ".rc-quiz-progress__header", text: /1 \/ 2 answers saved/

    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: ["contact_form"] } }
    get project_intake_quiz_path(@intake)
    assert_redirected_to review_project_intake_quiz_path(@intake)
  end

  test "save and back preserves current answers and editing creates a revision" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: %w[contact_form catalogue], navigation: "back" } }
    assert_redirected_to project_intake_quiz_path(@intake, step: "outcome")

    get project_intake_quiz_path(@intake, step: "features")
    assert_response :success
    assert_select 'input[type="checkbox"][value="contact_form"][checked]'
    assert_select 'input[type="checkbox"][value="catalogue"][checked]'

    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: %w[contact_form catalogue], navigation: "review" } }
    answer = @intake.intake_answers.find_by!(question_key: "features")
    assert_equal 1, answer.revision

    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: ["catalogue"], navigation: "review" } }
    assert_equal 2, answer.reload.revision
    assert_equal 2, answer.intake_answer_revisions.count
    assert_equal %w[contact_form catalogue], answer.intake_answer_revisions.order(:revision).first.snapshot["selected_options"]
  end

  test "incomplete review has explicit continuation and intake has resume link" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: { quiz: { selected_options: ["leads"] } }
    get review_project_intake_quiz_path(@intake)
    assert_response :success
    assert_select ".rc-quiz-review-alert", text: /not finished yet/
    assert_select "a[href='#{project_intake_quiz_path(@intake, step: 'features')}']", text: /Continue unfinished quiz/
    assert_select "a", text: /Answer this question/

    get project_intake_path(@intake)
    assert_response :success
    assert_select "a", text: /Continue saved Quiz/
    assert_select ".rc-quiz-intake-entry", text: /1 \/ 2 quiz answers saved locally/
  end

  test "invalid choices do not save and preserve submitted input" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: ["invalid_key"], other_text: "Fictional idea", navigation: "review" } }
    assert_response :unprocessable_entity
    assert_equal 0, @intake.intake_answers.count
    assert_select 'input[name="quiz[other_text]"][value="Fictional idea"]'
    assert_select ".rc-notice--error"
  end

  test "save and return to intake keeps the draft" do
    sign_in_as_owner
    patch project_intake_quiz_answer_path(@intake, question_key: "features"),
          params: { quiz: { selected_options: ["contact_form"], navigation: "intake" } }
    assert_redirected_to project_intake_path(@intake)
    assert_equal ["contact_form"], @intake.intake_answers.find_by!(question_key: "features").selected_options
  end

  private

  def sign_in_as_owner
    password = "long-fictional-quiz-test-password"
    user = User.create!(
      email: "quiz-owner@example.test",
      role: "owner",
      password: password,
      password_confirmation: password
    )
    post account_session_path,
         params: { email: user.email, password: password }
    assert_redirected_to consultations_path
  end

  def sign_in_as_legacy_admin
    post admin_session_path, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_response :redirect
  end
end
