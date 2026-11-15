require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceAutoSyncBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("auto-sync-browser-owner@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(
      @owner, capabilities: %w[rails testing],
      desired_services: %w[rails_bugfix rails_tests]
    )
  end

  test "owner generates a private catalogue from v1 with one click, without duplicate drafts" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_services_path
    assert_selector ".wa-services__card", count: 0
    click_button "Generate from profile"
    assert_selector ".wa-services__card", count: 2
    assert_selector ".wa-services__state--draft", count: 2
    click_button "Generate from profile"
    assert_selector ".wa-services__card", count: 2
    assert_equal 2, @workspace.service_offerings.count
    assert_equal 0, ServiceOfferingPublication.count

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      overflow = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator overflow["page"], :<=, overflow["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
