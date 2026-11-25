require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "calendar provides accessible month navigation and weekday headings" do
    get root_url(start_date: "2023-01-01")

    assert_response :success
    assert_select "nav[aria-label='Calendar month navigation']"
    assert_select "nav a[aria-label='Previous month']", count: 1
    assert_select "nav a[aria-label='Next month']", count: 1
    assert_select ".calendar-grid caption", text: /January 2023/
    assert_select ".calendar-grid th[scope='col']", count: 7
    assert_select ".calendar-scroll-region[tabindex='0']", count: 1
    assert_select "time.calendar-day-label[datetime='2023-01-19']", count: 1
  end

  test "owner without workspace sees calendar but no private activity" do
    owner = User.create!(email: "calendar-no-workspace@example.test", role: "owner",
      password: "synthetic-calendar-password-2026")
    assert_nil owner.owner_workspace

    post account_session_path, params: {
      email: owner.email, password: "synthetic-calendar-password-2026"
    }
    assert_redirected_to workspace_path

    assert_no_difference "Workspace.count" do
      get root_path(start_date: "2026-11-18")
      assert_response :success
      assert_select "[data-calendar-month-total]", minimum: 1

      get calendar_day_path(date: "2026-11-18")
      assert_response :success
      assert_select ".wa-calendar-day-recap", count: 0

      get calendar_hour_path(date: "2026-11-18", hour: 17)
      assert_response :success
      assert_select "li[data-hour-activity-source]", count: 0
    end
  end

  test "should get home" do
    get root_url
    assert_response :success
  end

  test "shows consultations in the selected month" do
    consultation = consultations(:one)

    get root_url(start_date: consultation.start_time.to_date.iso8601)

    assert_response :success
    assert_select "a.calendar-event-link[href=?] .calendar-event-name", consultation_path(consultation), text: consultation.title
  end

  test "does not show consultations outside the selected calendar month" do
    get root_url(start_date: "2024-03-01")

    assert_response :success
    assert_select "a[href=?]", consultation_path(consultations(:one)), count: 0
  end

  test "rejects invalid calendar date parameter" do
    get root_url(start_date: "not-a-date")

    assert_redirected_to root_url
  end
end
