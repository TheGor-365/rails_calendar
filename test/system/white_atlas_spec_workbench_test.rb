require "application_system_test_case"

class WhiteAtlasSpecWorkbenchTest < ApplicationSystemTestCase
  PASSWORD = "synthetic-spec-editor-browser-password-2026".freeze

  setup do
    @owner = User.create!(email: "spec-workbench-owner@example.test", role: "owner", password: PASSWORD)
    @intake = ProjectIntake.create!(
      title: "Synthetic Rails form", project_type: "rails_bugfix",
      goal: "Diagnose a fictional failing form, then define verification.",
      demo_consent_at: Time.current, status: "draft_spec"
    )
    @intake.intake_spec_versions.create!(
      version: 1, source: "template",
      document: {
        "summary" => "Synthetic investigation summary",
        "goals" => ["Restore fictional Rails form"],
        "deliverables" => ["Fictional reproduction report", "Example regression test"],
        "acceptance_criteria" => ["unique-acceptance-token: safe fictional replay"],
        "unknowns" => ["Synthetic logs are not available"],
        "exclusions" => ["No real payments or accounts"],
        "milestones" => []
      }
    )
  end

  test "search and group filters preserve edits, expanded height and narrow screen width" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit edit_spec_admin_project_intake_path(@intake)
    assert_selector "section.wa-spec-editor__section", count: 6
    assert_selector "button[data-wa-spec-review-category-param='all'][aria-pressed='true']"

    field = find("textarea[name='review[summary]']")
    long = ("Fictional verification step.\n" * 36).strip
    field.set(long)
    assert_equal long, field.value
    height = field.evaluate_script("this.getBoundingClientRect().height")
    assert_operator height, :>, 420, "Owner textarea must no longer stop at 420px"

    find("button[data-wa-spec-review-category-param='risks']").click
    assert_selector "section.wa-spec-editor__section:not([hidden])", count: 2
    assert_selector "button[data-wa-spec-review-category-param='risks'][aria-pressed='true']"

    find("button[data-wa-spec-review-category-param='all']").click
    fill_in "Search sections and text", with: "unique-acceptance-token"
    assert_selector "section.wa-spec-editor__section:not([hidden])", count: 1
    assert_selector "section#spec-section-acceptance_criteria:not([hidden])"
    assert_equal long, find("textarea[name='review[summary]']", visible: :all).value

    fill_in "Search sections and text", with: "no-matches-in-synthetic-draft-9917"
    assert_selector ".wa-spec-editor__empty", visible: true
    assert_selector "section.wa-spec-editor__section:not([hidden])", count: 0

    find("a[href='#spec-section-summary']").click
    assert_selector "section#spec-section-summary:not([hidden])"
    assert_equal long, find("textarea[name='review[summary]']").value

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      geometry = page.evaluate_script("({ page: document.documentElement.scrollWidth, viewport: innerWidth })")
      assert_operator geometry["page"], :<=, geometry["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
