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
      geometry = page.evaluate_script("(() => { const trigger = document.querySelector('#owner-ai-dock summary'); const dock = document.querySelector('#owner-ai-dock .wa-ai-dock__panel'); const t=trigger.getBoundingClientRect(); const p=dock.getBoundingClientRect(); return { triggerWidth: t.width, panelLeft: p.left, panelRight: p.right, viewportWidth: innerWidth, pagePadding: parseFloat(getComputedStyle(document.querySelector('#main-content')).paddingBottom) }; })()")
      assert_operator geometry["triggerWidth"], :<=, 54
      assert_operator geometry["panelLeft"], :>=, 0
      assert_operator geometry["panelRight"], :<=, geometry["viewportWidth"] + 1
      assert_operator geometry["pagePadding"], :>=, 140
      find("#owner-ai-dock summary").click
    end
    visit owner_services_path
    assert_selector "#owner-ai-dock"
    visit owner_ai_assistant_path
    assert_selector "#owner-ai-assistant"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
  test "bare service stem navigates from floating owner panel without AI consent or model call" do
    owner = make_test_owner("ai-navigation-stem-browser@example.test")
    approved_profile_for(owner)
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_ai_assistant_path
    find("#owner-ai-dock summary").click
    within(".wa-ai-dock__navigation") do
      fill_in "wa-dock-command", with: "услуг"
      click_button "Navigate"
    end
    assert_current_path owner_services_path
    assert_selector "#owner-services"

    find("#owner-ai-dock summary").click
    within(".wa-ai-dock__navigation") do
      fill_in "wa-dock-command", with: "кабин"
      click_button "Navigate"
    end
    assert_current_path owner_cabinet_path
  end


  test "AI studio navigation and responsive asymmetric knowledge board at 1440 390 and 320" do
    owner = make_test_owner("ai-studio-navigation-browser@example.test")
    approved_profile_for(owner)
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    page.driver.browser.manage.window.resize_to(1440, 900)
    visit owner_cabinet_path
    assert_selector ".rc-nav-group a.wa-ai-nav-entry", visible: true
    find(".rc-nav-group a.wa-ai-nav-entry").click
    assert_current_path owner_ai_assistant_path
    assert_selector ".wa-ai-page__wayfinder a[href='#owner-ai-knowledge']"
    assert_selector ".wa-ai-knowledge__item--profile"
    assert_selector ".wa-ai-knowledge__item--documents"
    assert_selector ".wa-ai-knowledge__flow li", count: 3

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      visit owner_cabinet_path
      assert_selector ".app-nav a.wa-ai-header-shortcut", visible: true
      bounds = page.evaluate_script("({page:document.documentElement.scrollWidth, viewport:innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
      find(".app-nav a.wa-ai-header-shortcut").click
      assert_current_path owner_ai_assistant_path
      assert_selector "nav.wa-ai-page__wayfinder a[href='#owner-ai-draft-library']"
      assert_selector "#owner-ai-knowledge .wa-ai-knowledge__item", count: 4
      widths = page.evaluate_script("({page:document.documentElement.scrollWidth, viewport:innerWidth})")
      assert_operator widths["page"], :<=, widths["viewport"] + 1
      find("#owner-ai-dock summary").click
      assert_selector "#owner-ai-dock a.wa-ai-dock__workspace-link", visible: true
      find("#owner-ai-dock summary").click
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end


end
