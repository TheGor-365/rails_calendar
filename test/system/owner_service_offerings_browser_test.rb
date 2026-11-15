require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceOfferingsBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("offering-browser-owner@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
    @offering = OwnerServices::Catalogue.new(workspace: @workspace).create_draft!(
      service_fields(@capabilities.first)
    )
  end

  test "owner navigates catalogue, reviews private draft and sees distinct publication gate" do
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_services_path
    assert_selector "#owner-services"
    assert_text "Internal catalog only"
    assert_selector ".wa-services__card", count: 1
    assert_text "Draft v1"
    click_link "Fix a fictional Rails error"
    assert_current_path owner_service_path(@offering)
    assert_selector "#offering-draft-form"
    assert_selector "#offering-approval"
    assert_no_selector "#offering-publication"
    assert_selector "textarea#offering-summary[data-controller='wa-autogrow']"

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
    page.driver.browser.manage.window.resize_to(1400, 900)

    check "I reviewed this exact revision and its feasibility."
    click_button "Approve revision"
    assert_selector "#offering-approved"
    assert_selector "#offering-publication"
    assert_no_selector "#offering-draft-form"
    assert_text "Approved v1"

    check "I confirm enabling this approved revision without unsupported promises."
    click_button "Enable"
    assert_selector ".wa-services__state--enabled", text: "Enabled v1"
    visit services_path
    assert_no_text "Fix a fictional Rails error"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
