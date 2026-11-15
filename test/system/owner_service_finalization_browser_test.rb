require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceFinalizationBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("finalization-browser-owner@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    @offerings = [
      @catalogue.create_draft!(service_fields(@capabilities.first)),
      @catalogue.create_draft!(service_fields(@capabilities.last, title: "Fictional React UI audit"))
    ]
  end

  test "catalog cards align footers, show meaningful icons, and finalize without publishing" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    visit owner_services_path
    assert_current_path owner_services_path
    assert_selector ".wa-services__card", count: 2
    assert_selector ".wa-services__card-heading > span > .bi", count: 2
    assert_selector ".wa-services__card-footer", count: 2
    assert_selector ".wa-services__state--draft", count: 2
    assert_selector ".wa-services__card-actions a.wa-services__open", count: 2

    # A single direct control can finalize one without enabling it.
    within first(".wa-services__card") do
      click_button "Finalize"
    end
    assert_selector ".wa-services__state--approved", count: 1
    assert_selector ".wa-services__state--draft", count: 1
    assert_equal 0, ServiceOfferingPublication.count

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
