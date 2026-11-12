require "test_helper"

class OwnerQuizI18nTest < ActionDispatch::IntegrationTest
  LOCALES = {
    "en" => ["Workspace", "What is the main desired outcome?", "Collect enquiries"],
    "ru" => ["Рабочее пространство", "Какого результата нужно достичь?", "Собирать заявки"],
    "hy" => ["Աշխատանքային տարածք", "Ո՞րն է հիմնական նպատակային արդյունքը", "Հավաքել հայտեր"],
    "es" => ["Espacio de trabajo", "¿Cuál es el principal resultado deseado?", "Recibir consultas"]
  }.freeze

  setup do
    @previous_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_GROK_ENABLED"] = "false"
    @owner = User.create!(email: "i18n-quiz-owner@example.test",
                          role: "owner", password: "safe-long-synthetic-password-2026")
    @intake = ProjectIntake.create!(
      title: "Synthetic bakery request",
      project_type: "website",
      goal: "A fictional bakery wants an informational site with an enquiry form",
      demo_consent_at: Time.current
    )
    post account_session_path, params: {
      email: @owner.email, password: "safe-long-synthetic-password-2026"
    }
    assert_redirected_to workspace_path
  end

  teardown do
    ENV["RC_GROK_ENABLED"] = @previous_ai
  end

  test "owner dashboard and quiz are localized without writes or external AI" do
    LOCALES.each do |code, (workspace_title, question_title, option_label)|
      post language_path, params: {locale: code, return_to: workspace_path}
      assert_response :see_other

      assert_no_difference ["User.count", "ProjectIntake.count", "IntakeAnswer.count", "IntakeAiQuota.count"] do
        get workspace_path
        assert_response :success
        assert_select "html[lang=?]", code
        assert_select "h1", text: workspace_title
        assert_select ".ws-hub-tool[href=?]", new_project_intake_path, count: 1

        get project_intake_quiz_path(@intake, step: "outcome")
        assert_response :success
        assert_select "html[lang=?]", code
        assert_select "h1", text: question_title
        assert_select "input[type=radio][value=leads]", count: 1
        assert_select ".rc-quiz-choice", text: option_label
        assert_select ".rc-quiz-progress", count: 1
        assert_select "form#rc-quiz-answer-form", count: 1
      end
    end
  end

  test "switching languages never changes saved canonical options and revisions" do
    post language_path, params: {locale: "en", return_to: project_intake_quiz_path(@intake)}
    patch project_intake_quiz_answer_path(@intake, question_key: "outcome"),
          params: {quiz: {selected_options: ["leads"], navigation: "review"}}
    assert_redirected_to review_project_intake_quiz_path(@intake)
    first = @intake.intake_answers.find_by!(question_key: "outcome")
    assert_equal ["leads"], first.selected_options
    assert_equal 1, first.revision

    %w[ru hy es en].each do |code|
      post language_path, params: {locale: code, return_to: review_project_intake_quiz_path(@intake)}
      assert_response :see_other
      get review_project_intake_quiz_path(@intake)
      assert_response :success
      assert_select "html[lang=?]", code
      assert_select ".rc-quiz-review-choices li", text: I18n.t("quiz.options.website.outcome.leads", locale: code)
      assert_equal ["leads"], first.reload.selected_options
      assert_equal 1, first.revision
      assert_equal 1, first.intake_answer_revisions.count
    end
    assert_equal 0, IntakeAiQuota.count
  end

  test "localized synthetic creation uses canonical work type and still requires consent" do
    post language_path, params: {locale: "hy", return_to: new_project_intake_path}
    get new_project_intake_path
    assert_response :success
    assert_select "select[name='project_intake[project_type]'] option[value=rails_bugfix]", count: 1
    assert_select "label[for='demo_consent']", text: I18n.t("intake.demo_consent", locale: :hy)
    assert_select "form[action=?]", project_intakes_path
  end

  test "client and unauthenticated access remain isolated under another locale" do
    delete sign_out_path
    post language_path, params: {locale: "es", return_to: workspace_path}
    get workspace_path
    assert_redirected_to sign_in_path
    get project_intake_quiz_path(@intake)
    assert_redirected_to sign_in_path
  end

  test "all translated quiz options keep the same keys as the offline catalog" do
    %w[en ru hy es].each do |code|
      I18n.with_locale(code) do
        ProjectIntake::TYPES.each do |type|
          Intake::QuizCatalog.for(type).each do |question|
            question.fetch(:options).each_key do |option|
              translated = I18n.t("quiz.options.#{type}.#{question.fetch(:key)}.#{option}", raise: true)
              assert translated.is_a?(String) && translated.present?
            end
          end
        end
      end
    end
  end
end
