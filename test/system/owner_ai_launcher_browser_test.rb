require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiLauncherBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner floating assistant is keyboard-operable and does not break mobile layouts" do
    owner = make_test_owner("ai-launcher-system@example.test")
    approved_profile_for(owner)
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_cabinet_path
    assert_selector "#owner-ai-dock"
    assert_no_selector ".wa-ai-dock__panel", visible: true
    find("#owner-ai-dock summary").click
    assert_selector ".wa-ai-dock__panel", visible: true
    assert_selector "textarea#wa-dock-brief", visible: true
    assert_selector "input[name=paid_consent]", visible: true
    find("#owner-ai-dock summary").send_keys(:escape)
    assert_no_selector ".wa-ai-dock__panel", visible: true
    find("#owner-ai-dock summary").click
    find("#owner-ai-dock summary").click
    assert_no_selector ".wa-ai-dock__panel", visible: true

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      find("#owner-ai-dock summary").click
      assert_selector ".wa-ai-dock__panel", visible: true
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
      find("#owner-ai-dock summary").click
    end
    visit owner_services_path
    assert_selector "#owner-ai-dock"
    visit owner_ai_assistant_path
    assert_selector "#owner-ai-assistant"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
