require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerCatalogueCopilotBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner opens private catalogue copilot without making an AI call or changing offers" do
    owner = make_test_owner("copilot-browser@example.test")
    workspace, _profile, _snapshot, capabilities = approved_profile_for(owner)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capabilities.first)
    )
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_services_path
    find(".wa-services__tools > summary").click
    click_link "AI catalogue review"
    assert_current_path owner_catalogue_ai_path
    assert_selector "#owner-catalogue-copilot"
    assert_text "No review yet"
    assert_equal 0, AiSpendEntry.count
    assert offering.reload.draft_version

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
