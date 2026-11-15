require "application_system_test_case"
require "base64"
require "tempfile"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAvatarEditorBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==".freeze

  test "owner edits 1-to-1 avatar through compact pencil popover without a full-width panel" do
    owner = make_test_owner("avatar-editor-browser@example.test")
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_cabinet_path
    assert_selector ".ws-account-avatar-frame"
    assert_no_selector ".ws-account-avatar-panel"
    assert_selector "summary.ws-avatar-edit-trigger"
    assert_no_selector ".ws-avatar-edit-panel", visible: true

    find("summary.ws-avatar-edit-trigger").click
    assert_selector ".ws-avatar-edit-panel", visible: true
    assert_selector "#owner-avatar-form"

    Tempfile.create(["avatar-browser-", ".png"]) do |tmp|
      tmp.binmode
      tmp.write(Base64.strict_decode64(PNG))
      tmp.flush
      attach_file "owner-avatar-file", tmp.path
      assert_text "Square image prepared. Ready to save."
      click_button "Upload avatar"
    end

    assert_current_path owner_cabinet_path(anchor: "owner-avatar")
    assert_selector ".ws-account-avatar-frame img.ws-account-avatar"
    blob = owner.reload.owner_avatars.last.blob
    assert_equal "image/jpeg", blob.content_type
    assert_equal "avatar-square.jpg", blob.filename.to_s

    square = page.evaluate_script("(() => { const el=document.querySelector('.ws-account-avatar-frame'); const b=el.getBoundingClientRect(); return [b.width, b.height] })()")
    assert_in_delta square[0], square[1], 1

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      find("summary.ws-avatar-edit-trigger").click
      assert_selector ".ws-avatar-edit-panel", visible: true
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
      find("summary.ws-avatar-edit-trigger").click
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
