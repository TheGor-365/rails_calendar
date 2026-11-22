require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerOutboxOperatorPreparationBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "C2.3b6b2.4a owner sees informational disabled replay gate at desktop and mobile without writes" do
    owner = make_test_owner("disabled-operator-owner-#{SecureRandom.hex(6)}@example.test")
    approved_profile_for(owner)

    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    baseline = [
      OwnerOutboxReplayRun.count, DomainOutboxEvent.count,
      ActivityEvent.count, AiSpendEntry.count
    ]

    [1400, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      visit owner_outbox_health_path
      assert_selector "[data-outbox-health] [data-outbox-operator-preparation][data-replay-enabled='false']"
      within("[data-outbox-operator-preparation]") do
        assert_no_selector "button", visible: :all
        assert_no_selector "form", visible: :all
        assert_no_selector "input", visible: :all
      end
      within("[data-outbox-health]") do
        assert_no_selector "form[action*='replay']", visible: :all
        assert_no_selector "form[method='post']", visible: :all
      end
      widths = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator widths["page"], :<=, widths["viewport"] + 1
    end

    assert_equal baseline, [
      OwnerOutboxReplayRun.count, DomainOutboxEvent.count,
      ActivityEvent.count, AiSpendEntry.count
    ]
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  test "C2.3b6b2.4a anonymous and client cannot see operator preparation" do
    visit owner_outbox_health_path
    assert_no_selector "[data-outbox-operator-preparation]", visible: :all

    client = make_test_client("disabled-operator-client-#{SecureRandom.hex(6)}@example.test")
    visit sign_in_path
    fill_in "Email address", with: client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_home_path

    visit owner_outbox_health_path
    assert_no_selector "[data-outbox-operator-preparation]", visible: :all
  end
end
