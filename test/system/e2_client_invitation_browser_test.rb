require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"
require "uri"

class E2ClientInvitationBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  setup do
    @previous_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @previous_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"
  end

  teardown do
    @previous_pilot.nil? ? ENV.delete("RC_LOCAL_CLIENT_REQUESTS_ENABLED") :
                           ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @previous_pilot
    @previous_ai.nil? ? ENV.delete("RC_GROK_ENABLED") :
                        ENV["RC_GROK_ENABLED"] = @previous_ai
  end

  test "owner shares fragment-only invitation, guest sees sanitized preview and verified client gets draft" do
    owner = make_test_owner("e2-browser-own-#{SecureRandom.hex(4)}@example.test")
    workspace, _, _, capabilities = approved_profile_for(owner)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capabilities.first, title: "Synthetic Rails form correction")
    )
    version = offering.latest_version
    version.update!(approved_at: Time.current)
    offering.update!(approved_version: version, published_version: version)
    client = make_test_client("e2-browser-client-#{SecureRandom.hex(4)}@example.test")

    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_invitations_path
    assert_text "Invite a client"
    fill_in "proposal_seed_title", with: "Fictional owner proposal"
    fill_in "proposal_seed_goal", with: "Private fictional source: should not be exposed in guest preview."
    find("input[name='service_version_ids[]']", match: :first).check
    click_button "Issue a 48-hour invitation"
    assert_selector ".wa-invite-issued:not([hidden])", wait: 10
    assert_selector "input[data-wa-invitation-issue-target='link']"
    invitation_url = find("input[data-wa-invitation-issue-target='link']").value
    assert_field "proposal_seed_title", with: "Fictional owner proposal"
    assert_field "proposal_seed_goal", with: "Private fictional source: should not be exposed in guest preview."
    assert_link "Preview invitation"
    assert_link "Download JSON"
    assert_match(/#token=[0-9a-f]{64}\z/, invitation_url)
    refute_match(/\?invite_token=/, invitation_url)
    [1440, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page:document.documentElement.scrollWidth,viewport:innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end

    page.driver.browser.manage.window.resize_to(1440, 900)
    click_button "Sign out"
    visit invitation_url
    assert_current_path client_invitation_preview_path, wait: 10
    assert_text "Invitation preview"
    assert_text version.title
    assert_no_text "Private fictional source"
    refute_match(/token=/, page.current_url)
    [1440, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page:document.documentElement.scrollWidth,viewport:innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end

    page.driver.browser.manage.window.resize_to(1440, 900)
    visit sign_in_path
    fill_in "Email address", with: client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_invitation_preview_path
    check "demo_consent"
    click_button "Use fictional data and claim editable draft"
    # Capybara waits for the HTML response; reading the model immediately after
    # click can race the asynchronous Puma request and return nil.
    assert_text "Review and edit request", wait: 10
    intake = client.client_project_intakes.order(id: :desc).first
    assert intake
    assert_current_path edit_client_request_path(intake)
    assert_text "Private fictional source"
    assert_text "What would you like to achieve?"
    assert_equal 0, intake.client_message_count
    [1440, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page:document.documentElement.scrollWidth,viewport:innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
