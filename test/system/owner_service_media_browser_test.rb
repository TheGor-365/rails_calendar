require "application_system_test_case"
require "tempfile"
require "base64"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceMediaBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner reaches catalog from Requests and uploads a private image in White Atlas" do
    owner = make_test_owner("media-browser-owner@example.test")
    workspace, _profile, _snapshot, capabilities = approved_profile_for(owner)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capabilities.first)
    )

    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit admin_project_intakes_path
    assert_selector ".wa-requests__more > summary"
    find(".wa-requests__more > summary").click
    assert_selector ".wa-requests__more-panel a[href='#{owner_services_path}']"
    within ".wa-requests__more-panel" do
      click_link "My services"
    end
    assert_current_path owner_services_path

    visit owner_service_path(offering)
    assert_selector "#offering-media-upload"
    assert_text "Automatic AI access to files is disabled"

    Tempfile.create(["media-browser-", ".png"]) do |tmp|
      tmp.binmode
      tmp.write(Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=="))
      tmp.flush
      within "#offering-media-upload" do
        attach_file "File", tmp.path
        fill_in "Caption (optional)", with: "A harmless synthetic banner"
        click_button "Upload"
      end
    end

    assert_selector ".wa-services__media-item", count: 1
    assert_selector ".wa-services__media-thumb", count: 1
    assert_text "Needs review"
    click_button "Approve media"
    assert_text "Reviewed"
    assert_equal false, offering.reload.media_items.first.ai_access_allowed
    visit owner_services_path
    assert_selector ".wa-services__card-banner", count: 1

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 932)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
