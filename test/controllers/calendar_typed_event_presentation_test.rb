require "test_helper"

class CalendarTypedEventPresentationTest < ActionDispatch::IntegrationTest
  test "owner can see a typed activity in its exact hour and month" do
    travel_to Time.zone.local(2026, 11, 13, 22, 37) do
      owner = User.create!(email: "qa-calendar-owner@example.test", role: "owner",
                           password: "qa-calendar-owner-password-2026")
      workspace = owner.create_owner_workspace!
      intake = ProjectIntake.create!(
        workspace: workspace, title: "QA Mayak Rails intake",
        project_type: "rails_bugfix",
        goal: "Investigate a synthetic Rails error and test the expected response.",
        demo_consent_at: Time.current
      )
      post account_session_path, params: {
        email: owner.email, password: "qa-calendar-owner-password-2026"
      }
      assert_redirected_to workspace_path

      get calendar_day_path(date: "2026-11-13")
      assert_response :success
      assert_select "a.rc-hour-band[href=?]",
                    calendar_hour_path(date: "2026-11-13", hour: 22) do
        assert_select ".wa-calendar-hour-preview--request[data-calendar-event-kind=request]", count: 1
        assert_select ".wa-calendar-hour-preview__content strong", text: intake.title
        assert_select ".wa-calendar-hour-preview .bi.bi-clipboard2-check", count: 1
      end
      assert_select ".wa-calendar-hour-activity[data-calendar-hour='22']", count: 1
      assert_select ".rc-time-axis-hour", count: 24

      get root_path(start_date: "2026-11-13")
      assert_response :success
      assert_select "h1", text: "Events"
      assert_select ".calendar-event.wa-calendar-event--request", minimum: 1
    end
  end

  test "anonymous cannot see private owner activity previews" do
    get calendar_day_path(date: "2026-11-13")
    assert_response :success
    assert_select ".wa-calendar-hour-preview", count: 0
    assert_select ".wa-calendar-hour-activity", count: 0
  end

  test "calendar no longer shows redundant tutorial paragraphs" do
    get root_path(start_date: "2026-11-13")
    assert_response :success
    assert_select ".simple-calendar > p.rc-hint", count: 0
  end
end
