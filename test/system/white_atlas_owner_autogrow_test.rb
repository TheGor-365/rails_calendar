require "application_system_test_case"

class WhiteAtlasOwnerAutogrowTest < ApplicationSystemTestCase
  PASSWORD = "synthetic-owner-browser-autogrow-password-2026".freeze

  setup do
    @owner = User.create!(email: "owner-browser-autogrow@example.test", password: PASSWORD, role: "owner")
  end

  test "owner interview notes use native textarea, grow on input, and remain accessible on mobile" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_setup_path(step: "A")
    assert_selector "textarea#owner_notes[data-controller='wa-autogrow']"
    notes = find("#owner_notes")
    initial_height = notes.evaluate_script("this.getBoundingClientRect().height")
    body = ("Fictional task requirements and constraints for a safe local demonstration.\n" * 8).strip
    notes.set(body)
    assert_equal body, notes.value
    expanded_height = notes.evaluate_script("this.getBoundingClientRect().height")
    assert_operator expanded_height, :>, initial_height

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({width: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["width"], :<=, bounds["viewport"] + 1
      assert_equal body, notes.value
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
