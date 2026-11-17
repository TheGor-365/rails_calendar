require "application_system_test_case"
require "base64"
require "tempfile"

class ClientAvatarEditorBrowserTest < ApplicationSystemTestCase
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAIAAAAt/+nTAAAAQ0lEQVR4nO3PQQ3AIADAQEADWjGB6YngcVnSU9DOfc/4s6UDXjWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oH015wFVe6iKsAAAAABJRU5ErkJggg==".freeze
  PASSWORD = "client-avatar-browser-local-test".freeze

  test "verified client edits and uploads square avatar from the pencil popover" do
    client = User.create!(email: "client-avatar-browser@example.test", role: "client",
                          password: PASSWORD, email_verified_at: Time.current,
                          signup_consent_at: Time.current, signup_policy_version: "avatar-pilot")
    visit sign_in_path
    fill_in "Email address", with: client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_home_path

    visit client_cabinet_path
    assert_selector "#client-avatar.ws-account-avatar-frame"
    assert_selector "summary.ws-avatar-edit-trigger"
    assert_no_selector ".ws-avatar-edit-panel", visible: true
    find("summary.ws-avatar-edit-trigger").click
    assert_selector "#client-avatar-form", visible: true

    Tempfile.create(["client-avatar-browser-", ".png"]) do |tmp|
      tmp.binmode
      tmp.write(Base64.strict_decode64(PNG))
      tmp.flush
      attach_file "client-avatar-file", tmp.path
      assert_text "Square image prepared. Ready to save."
      assert_selector ".ws-avatar-edit-crop-preview__image", visible: true
      click_button "Upload avatar"
    end

    assert_current_path client_cabinet_path
    assert_text "Avatar saved"
    assert_selector "#client-avatar img.ws-account-avatar"
    assert_selector "header.app-header img.ws-nav-avatar"
    blob = client.reload.client_avatars_attachments.order(id: :desc).first.blob
    assert_equal "image/jpeg", blob.content_type
    assert_equal "avatar-square.jpg", blob.filename.to_s

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
