require "application_system_test_case"

class WhiteAtlasAutogrowTest < ApplicationSystemTestCase
  PASSWORD = "synthetic-form-browser-password-2026".freeze

  setup do
    @old_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    @client = User.create!(
      email: "autogrow-browser@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "local-browser-test"
    )
  end

  teardown do
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @old_pilot
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "client form grows and shrinks without changing its value or native maxlength" do
    visit sign_in_path
    fill_in "Email address", with: @client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_home_path

    visit new_client_request_path
    assert_selector "section.wa-client-form__section", count: 3
    assert_selector "textarea#project_intake_goal[data-controller='wa-autogrow']"
    assert_selector "output#client-goal-count", text: "0 / 1200"

    initial = page.evaluate_script("document.querySelector('#project_intake_goal').getBoundingClientRect().height")
    long = ("Fictional booking form failure to reproduce and verify.\n" * 12).strip
    find("#project_intake_goal").set(long)
    assert_selector "output#client-goal-count", text: "#{long.length} / 1200"
    expanded = page.evaluate_script("document.querySelector('#project_intake_goal').getBoundingClientRect().height")
    assert_operator expanded, :>, initial
    assert_equal long, find("#project_intake_goal").value

    shorter = "Fictional API bug"
    find("#project_intake_goal").set(shorter)
    assert_selector "output#client-goal-count", text: "#{shorter.length} / 1200"
    reduced = page.evaluate_script("document.querySelector('#project_intake_goal').getBoundingClientRect().height")
    assert_operator reduced, :<, expanded
    assert_equal shorter, find("#project_intake_goal").value

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      geometry = page.evaluate_script(<<~JS)
        (() => ({
          pageWidth: document.documentElement.scrollWidth,
          viewportWidth: window.innerWidth,
          maxLength: document.querySelector("#project_intake_goal").maxLength,
          sectionCount: document.querySelectorAll("section.wa-client-form__section").length
        }))()
      JS
      assert_operator geometry["pageWidth"], :<=, geometry["viewportWidth"] + 1
      assert_equal 1200, geometry["maxLength"]
      assert_equal 3, geometry["sectionCount"]
    end
  end
end
