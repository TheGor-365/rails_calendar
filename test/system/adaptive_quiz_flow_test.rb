require "application_system_test_case"

# RC-035B browser proof: real owner session, branching and no silent archival.
class AdaptiveQuizFlowTest < ApplicationSystemTestCase
  setup do
    @intake = ProjectIntake.create!(
      title: "Fictional Owner-Only Browser Preview",
      project_type: "website",
      goal: "Collect fictional website enquiries through an adaptive intake.",
      demo_consent_at: Time.current
    )
    @password = "fictional-adaptive-browser-password-123"
    @owner = User.create!(
      email: "adaptive-browser@example.test",
      role: "owner",
      password: @password, password_confirmation: @password
    )
  end

  test "browser owner login, conditional checkout, explicit archive confirmation and review" do
    visit sign_in_url
    fill_in "Email", with: @owner.email
    fill_in "Password", with: @password
    click_button "Sign in"
    assert_current_path consultations_path

    visit adaptive_project_intake_quiz_url(@intake, step: "website_pages")
    assert_selector "h1", text: "Which website pages or features are needed?"
    check "Catalogue or store"
    select "Must have", from: "Priority for Catalogue or store"
    click_button "Save and continue"
    assert_current_path adaptive_project_intake_quiz_path(@intake, step: "website_checkout")
    check "Checkout"
    select "Must have", from: "Priority for Checkout"
    click_button "Save and review"
    assert_current_path review_adaptive_project_intake_quiz_path(@intake)
    assert_text "What must the catalogue support?"

    visit adaptive_project_intake_quiz_url(@intake, step: "website_pages")
    uncheck "Catalogue or store"
    check "Landing page"
    select "Should have", from: "Priority for Landing page"
    click_button "Save and continue"
    assert_selector "[role='alert']", text: /will hide 1 previously saved answer/
    assert_selector "button[name='quiz[confirm_branch_change]'][value='1']", visible: true
    click_button "Confirm branch change"
    assert_text "Adaptive quiz draft saved"

    visit review_adaptive_project_intake_quiz_url(@intake)
    assert_text "historic answer(s) are currently inactive"
    assert_no_text "What must the catalogue support?"
    child = @intake.intake_answers.find_by!(question_key: "website_checkout")
    assert_equal ["checkout"], child.selected_options
    assert_equal 1, child.intake_answer_revisions.count
  end

  test "adaptive owner-only layout does not overflow 320 390 430px" do
    visit sign_in_url
    fill_in "Email", with: @owner.email
    fill_in "Password", with: @password
    click_button "Sign in"
    assert_current_path consultations_path

    [320, 390, 430].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      visit adaptive_project_intake_quiz_url(@intake)
      assert_selector "h1", text: "What should this work achieve?"
      visit adaptive_project_intake_quiz_url(@intake, step: "website_pages")
      assert_selector "h1", text: "Which website pages or features are needed?"
      size = page.evaluate_script(<<~JS)
        (() => ({
          content: document.documentElement.scrollWidth,
          viewport: window.innerWidth
        }))()
      JS
      assert_operator size["content"], :<=, size["viewport"] + 1,
                      "Adaptive quiz overflows the #{width}px viewport"
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
