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
    assert_text "Your project invitation"
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
    assert_no_selector "input[name='demo_consent']"
    click_button "Start my project request"
    # Capybara waits for the HTML response; reading the model immediately after
    # click can race the asynchronous Puma request and return nil.
    assert_text "Shape your project request", wait: 10
    intake = client.client_project_intakes.order(id: :desc).first
    assert intake
    assert_current_path edit_client_request_path(intake)
    assert_text "Private fictional source"
    assert_text "Let's define what needs to be built"
    assert_selector ".wa-scope__section", count: 12
    assert_text "What would you like to achieve?"
    assert_equal 0, intake.client_message_count
    [1440, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page:document.documentElement.scrollWidth,viewport:innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
    end
    # F2: explicitly save discovery, reload, then submit the same canonical
    # intake. The custom selects retain their native form values.
    page.driver.browser.manage.window.resize_to(1440, 900)
    note = "Synthetic client requirement: preserve the submitted form."
    fill_in "scope-business_goal", with: note
    %w[title project_type goal].each do |key|
      page.execute_script(<<~JS, key)
        const field = document.getElementById("fact_review_" + arguments[0]);
        field.value = "confirmed";
        field.dispatchEvent(new Event("change", { bubbles: true }));
      JS
    end
    click_button "Save changes"
    assert_text "Draft saved."
    assert_current_path edit_client_request_path(intake)
    assert_equal note, intake.reload.latest_scope_revision.answers.fetch("business_goal").fetch("text")
    visit edit_client_request_path(intake)
    assert_field "scope-business_goal", with: note
    assert_equal 0, intake.client_message_count
    click_button "Send request for review"
    assert_current_path client_request_path(intake)
    assert_equal 1, intake.reload.client_message_count
    assert intake.client_request_invitation.reload.submitted_at
    assert_equal [version.id], intake.selected_service_offering_versions.pluck(:id)
    assert_equal 1, client.client_project_intakes.count
    assert_equal 0, AiSpendEntry.count

    # The owner sees the submitted request, not merely the pre-claim proposal.
    click_button "Sign out"
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    visit admin_project_intakes_path(view: "incoming")
    assert_selector ".wa-requests__record--unread", text: intake.title
    within(".wa-requests__record--unread", text: intake.title) do
      find("summary").click
      find("a[href='#{project_intake_path(intake)}']").click
    end
    assert_current_path project_intake_path(intake)
    assert_equal 0, AiSpendEntry.count
    visit admin_project_intakes_path(view: "incoming")
    assert_no_selector ".wa-requests__record--unread", text: intake.title
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  test "invitation overwrite uses explicit shared confirmation without paid generation" do
    owner = make_test_owner("e2-overwrite-#{SecureRandom.hex(4)}@example.test")
    approved_profile_for(owner)
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    visit owner_invitations_path

    # Synthetic DOM-only draft; no provider or persisted AI entry.
    page.execute_script(<<~JS)
      const section = document.querySelector('[data-controller="wa-invitation-ai"]');
      section.querySelector('[data-wa-invitation-ai-target="heading"]').textContent = "Synthetic heading";
      section.querySelector('[data-wa-invitation-ai-target="draft"]').textContent = "Synthetic replacement description";
      section.querySelector('[data-wa-invitation-ai-target="result"]').hidden = false;
      section.querySelector('[data-wa-invitation-ai-target="apply"]').disabled = false;
    JS
    fill_in "proposal_seed_goal", with: "Original synthetic description"
    find("[data-action='click->wa-invitation-ai#apply']").click
    assert_selector "dialog.wa-confirm-dialog[open][data-wa-confirm-kind='overwrite']"
    find("dialog.wa-confirm-dialog [data-wa-page-dialog-target='keepEditing']").click
    assert_field "proposal_seed_goal", with: "Original synthetic description"
    find("[data-action='click->wa-invitation-ai#apply']").click
    find("dialog.wa-confirm-dialog [data-action='wa-page-dialog#confirmDiscard']").click
    assert_field "proposal_seed_goal", with: "Synthetic replacement description"

    fill_in "proposal_approved_client_preview", with: "Original synthetic preview"
    find("#proposal_share_preview").check
    find("[data-action='click->wa-invitation-ai#useClientPreview']").click
    assert_selector "dialog.wa-confirm-dialog[open][data-wa-confirm-kind='overwrite']"
    find("dialog.wa-confirm-dialog [data-wa-page-dialog-target='keepEditing']").click
    assert_field "proposal_approved_client_preview", with: "Original synthetic preview"
    assert_checked_field "proposal_share_preview"
    find("[data-action='click->wa-invitation-ai#useClientPreview']").click
    find("dialog.wa-confirm-dialog [data-action='wa-page-dialog#confirmDiscard']").click
    assert_field "proposal_approved_client_preview", with: /Synthetic replacement description/
    assert_unchecked_field "proposal_share_preview"
    assert_equal 0, AiSpendEntry.count
    assert_equal 0, ClientRequestInvitation.count
  end

end
