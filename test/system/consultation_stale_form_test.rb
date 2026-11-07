require "application_system_test_case"

# Browser-level proof that a form opened in one tab cannot overwrite a newer
# edit saved from another tab in the same authenticated session.
class ConsultationStaleFormTest < ApplicationSystemTestCase
  setup do
    @consultation = consultations(:two)
  end

  test "stale browser tab displays a conflict without overwriting saved data" do
    visit admin_login_url
    fill_in "Username", with: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME")
    fill_in "Password", with: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    click_on "Sign in"
    assert_text "Administrator signed in"

    visit edit_consultation_url(@consultation)
    old_tab = page.current_window
    old_version = find("input[name='consultation[lock_version]']", visible: false).value

    new_tab = window_opened_by do
      page.execute_script("window.open('#{edit_consultation_path(@consultation)}', '_blank')")
    end

    within_window(new_tab) do
      assert_selector "input[name='consultation[lock_version]'][value='#{old_version}']", visible: false)
      fill_in "Title", with: "Newer saved title"
      click_on "Update Consultation"
      assert_text "Consultation was successfully updated"
      assert_text "Newer saved title"
    end

    within_window(old_tab) do
      fill_in "Title", with: "Obsolete tab overwrite"
      click_on "Update Consultation"
      assert_selector "#consultation-form-errors[role='alert']", text: /changed in another tab/
      assert_field "Title", with: "Newer saved title"
      assert_selector "input[name='consultation[lock_version]'][value='#{old_version.to_i + 1}']", visible: false)
    end

    assert_equal "Newer saved title", @consultation.reload.title
    assert_equal old_version.to_i + 1, @consultation.lock_version
  end
end
