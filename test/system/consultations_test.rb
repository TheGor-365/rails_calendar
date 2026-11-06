require "application_system_test_case"

class ConsultationsTest < ApplicationSystemTestCase
  setup do
    @consultation = consultations(:one)
  end

  test "visitor can navigate the month with accessible calendar semantics" do
    visit root_url(start_date: "2023-01-01")
    assert_selector "nav[aria-label='Calendar month navigation']"
    assert_selector ".calendar-scroll-region[tabindex='0']"
    assert_selector "time.calendar-day-label[datetime='2023-01-19']"
    click_on "Next"
    assert_selector ".calendar-title", text: "February 2023"
  end

  test "anonymous visitors can browse without editing controls" do
    visit consultations_url
    assert_selector "h1", text: "Consultations"
    assert_no_link "New consultation"

    visit consultation_url(@consultation)
    assert_no_link "Edit this consultation"
    assert_no_button "Destroy this consultation"
  end

  test "anonymous visitor cannot open administrative forms" do
    visit new_consultation_url
    assert_current_path admin_login_path
    assert_selector "h1", text: "Administrator sign-in"

    visit edit_consultation_url(@consultation)
    assert_current_path admin_login_path
  end

  test "administrator can create consultation" do
    sign_in_as_admin
    visit consultations_url
    click_on "New consultation"

    fill_in "Description", with: @consultation.description
    fill_in "End time", with: @consultation.end_time
    fill_in "Start time", with: @consultation.start_time
    fill_in "Title", with: @consultation.title
    click_on "Create Consultation"

    assert_text "Consultation was successfully created"
  end

  test "administrator can update consultation" do
    sign_in_as_admin
    visit consultation_url(@consultation)
    click_on "Edit this consultation"

    fill_in "Title", with: "Updated consultation"
    click_on "Update Consultation"

    assert_text "Consultation was successfully updated"
    assert_text "Updated consultation"
  end

  test "administrator can destroy consultation" do
    sign_in_as_admin
    visit consultation_url(@consultation)
    accept_confirm "Delete this consultation?" do
      click_on "Destroy this consultation"
    end

    assert_text "Consultation was successfully destroyed"
  end

  test "signing out hides administrative actions" do
    sign_in_as_admin
    visit consultations_url
    assert_link "New consultation"
    click_on "Sign out"

    assert_text "Administrator signed out"
    visit consultations_url
    assert_no_link "New consultation"
  end


  test "public visitor opens a date and sees all 24 hours" do
    visit root_url(start_date: "2023-01-01")
    find("a.calendar-day-link[href*='2023-01-19']").click

    assert_current_path calendar_day_path(date: "2023-01-19")
    assert_selector "table.day-timeline tbody tr", count: 24
    assert_selector "#hour-22", text: @consultation.title
    assert_no_link "Add at 09:00"
  end

  test "administrator manually creates consultation from a day timeslot" do
    sign_in_as_admin
    visit calendar_day_url(date: "2026-11-06")
    click_on "Add at 09:00"

    assert_selector "h1", text: "New consultation"
    assert_field "Start time", with: /2026-11-06T09:00/
    assert_field "End time", with: /2026-11-06T10:00/

    fill_in "Title", with: "Project kickoff"
    click_on "Create Consultation"

    assert_text "Consultation was successfully created"
    assert_text "Project kickoff"
  end

  private

  def sign_in_as_admin
    visit admin_login_url
    fill_in "Username", with: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME")
    fill_in "Password", with: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    click_on "Sign in"
    assert_text "Administrator signed in"
  end
end
