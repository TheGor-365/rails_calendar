require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
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
