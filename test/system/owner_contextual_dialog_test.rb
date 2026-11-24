require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerContextualDialogTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("owner-dialog-navigation@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
  end

  test "interview steps stay local, cabinet return closes, and focus returns to opener" do
    sign_in_owner
    visit owner_cabinet_path

    opener = find("a.ws-account-tool[data-wa-page-dialog][href*='/workspace/setup']")
    opener.click
    assert_current_path owner_cabinet_path
    assert_selector "dialog.wa-page-dialog[open]"

    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-setup"
      find("a.ws-owner-step[href*='step=B']").click
      assert_selector "a.ws-owner-step.is-active[href*='step=B']"
      assert_no_selector ".app-header", visible: true
      find("a[href='#{owner_cabinet_path}']").click
    end

    assert_no_selector "dialog.wa-page-dialog[open]"
    assert_current_path owner_cabinet_path
    assert_selector "a.ws-account-tool[data-wa-page-dialog][href*='/workspace/setup']:focus"
  end

  test "a distinct allowed section replaces the iframe content without nesting dialogs" do
    sign_in_owner
    visit owner_cabinet_path

    find("a.ws-account-tool[data-wa-page-dialog][href='#{owner_capabilities_path}']").click
    assert_selector "dialog.wa-page-dialog[open]"

    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-capabilities"
      first("a[href^='#{owner_ai_assistant_path}']").click
    end

    assert_current_path owner_cabinet_path
    assert_selector "dialog.wa-page-dialog[open]", count: 1
    assert_selector "iframe[data-wa-embedded-page]", count: 1
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-ai-assistant"
      assert_no_selector ".app-header", visible: true
      first("a[href='#{owner_cabinet_path}']").click
    end
    assert_no_selector "dialog.wa-page-dialog[open]"
  end


  test "contextual profile and capabilities return through logical modal history" do
    sign_in_owner
    visit owner_cabinet_path
    find("header[data-wa-banner='account'] a[data-wa-page-dialog][href='#{owner_practice_path}']").click
    assert_selector "dialog.wa-page-dialog[open]"
    assert_selector ".wa-page-dialog__back[disabled]"
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-practice"
      find("header[data-wa-banner] a[href='#{owner_capabilities_path}']").click
    end
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-capabilities"
    end
    assert_selector ".wa-page-dialog__back:not([disabled])"
    find(".wa-page-dialog__back").click
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-practice"
    end
    assert_selector ".wa-page-dialog__back[disabled]"
    assert_current_path owner_cabinet_path
    find("dialog.wa-page-dialog button[data-action='wa-page-dialog#close']").click
    assert_no_selector "dialog.wa-page-dialog[open]"
    assert_current_path owner_cabinet_path
  end


  test "closing an edited interview requires explicit discard" do
    sign_in_owner
    visit owner_cabinet_path
    find("a.ws-account-tool[data-wa-page-dialog][href*='/workspace/setup']").click
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-setup"
      fill_in "owner_notes", with: "Synthetic unsaved review note"
    end
    assert_selector "iframe[data-wa-dirty='true']"
    dismiss_confirm do
      find("dialog.wa-page-dialog button[data-action='wa-page-dialog#close']").click
    end
    assert_selector "dialog.wa-page-dialog[open]"
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_field "owner_notes", with: "Synthetic unsaved review note"
    end
    accept_confirm do
      find("dialog.wa-page-dialog button[data-action='wa-page-dialog#close']").click
    end
    assert_no_selector "dialog.wa-page-dialog[open]"
    assert_current_path owner_cabinet_path
  end

  private

  def sign_in_owner
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: OwnerServiceCatalogueTestData::PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
  end
end
