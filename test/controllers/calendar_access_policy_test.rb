require "test_helper"

class CalendarAccessPolicyTest < ActionDispatch::IntegrationTest
  setup do
    @old_flag = ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"]
  end

  teardown do
    if @old_flag.nil?
      ENV.delete("RAILS_CALENDAR_PUBLIC_DEMO_MODE")
    else
      ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = @old_flag
    end
  end

  test "development test demo remains public by default with no flag" do
    ENV.delete("RAILS_CALENDAR_PUBLIC_DEMO_MODE")
    get root_url(start_date: "2023-01-19")
    assert_response :success
    get consultations_url
    assert_response :success
    get consultation_url(consultations(:one))
    assert_response :success
  end

  test "production defaults to private even when flag is absent" do
    ENV.delete("RAILS_CALENDAR_PUBLIC_DEMO_MODE")
    production = ActiveSupport::EnvironmentInquirer.new("production")
    refute ApplicationController.new.send(:calendar_public_read_enabled?, environment: production)
  end

  test "private mode denies anonymous calendar and all detail read routes" do
    ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = "false"

    [
      root_url(start_date: "2023-01-19"),
      calendar_day_url(date: "2023-01-19"),
      calendar_hour_url(date: "2023-01-19", hour: 22),
      consultations_url,
      consultation_url(consultations(:one))
    ].each do |path|
      get path
      assert_redirected_to admin_login_url, "Expected anonymous read denial on #{path}"
      refute_includes response.body, consultations(:one).title
    end

    get admin_login_url
    assert_response :success
  end

  test "private mode permits signed in administrator to read every calendar route" do
    ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = "false"
    sign_in

    get root_url(start_date: "2023-01-19")
    assert_response :success
    get calendar_day_url(date: "2023-01-19")
    assert_response :success
    get calendar_hour_url(date: "2023-01-19", hour: 22)
    assert_response :success
    get consultations_url
    assert_response :success
    get consultation_url(consultations(:one))
    assert_response :success
  end

  test "explicit public mode opt-in exposes synthetic read endpoints but not write endpoints" do
    ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = "true"

    get consultations_url
    assert_response :success

    get new_consultation_url
    assert_redirected_to admin_login_url

    assert_no_difference "Consultation.count" do
      delete consultation_url(consultations(:one))
    end
    assert_redirected_to admin_login_url
  end

  test "ambiguous public-demo flag values do not enable public read access" do
    ["1", "TRUE", "", "yes"].each do |value|
      ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = value
      get consultations_url
      assert_redirected_to admin_login_url
    end
  end

  private

  def sign_in
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
