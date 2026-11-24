require "application_system_test_case"

class OwnerContextualDialogTest < ApplicationSystemTestCase
  PASSWORD = "fictional-owner-contextual-dialog-password-2026".freeze

  setup do
    @owner = User.create!(email: "owner-dialog-navigation@example.test", password: PASSWORD, role: "owner")
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
      find("a[href='#{owner_practice_path}']").first.click
    end

    assert_current_path owner_cabinet_path
    assert_selector "dialog.wa-page-dialog[open]", count: 1
    assert_selector "iframe[data-wa-embedded-page]", count: 1
    within_frame(find("iframe[data-wa-embedded-page]")) do
      assert_selector "#owner-practice"
      assert_no_selector ".app-header", visible: true
      find("a[href='#{owner_cabinet_path}']").first.click
    end
    assert_no_selector "dialog.wa-page-dialog[open]"
  end

  private

  def sign_in_owner
    visit sign_in_path
    fill_in "Email address", with: @owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
  end
end
