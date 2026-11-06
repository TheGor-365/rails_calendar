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

  test "should get home" do
    get root_url
    assert_response :success
  end

  test "shows consultations in the selected month" do
    consultation = consultations(:one)

    get root_url(start_date: consultation.start_time.to_date.iso8601)

    assert_response :success
    assert_select "a[href=?]", consultation_path(consultation), text: consultation.title
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
