require "test_helper"

class ConsultationOverlapFlowTest < ActionDispatch::IntegrationTest
  setup do
    @existing = consultations(:one)
  end

  test "admin sees advisory overlap and direct link to the colliding record" do
    conflicting = Consultation.create!(
      title: "Overlapping review",
      start_time: Time.zone.local(2023, 1, 19, 23, 0),
      end_time: Time.zone.local(2023, 1, 19, 23, 30)
    )
    sign_in_as_admin

    get consultation_url(@existing)
    assert_response :success
    assert_select ".rc-overlap-notice[role='status']" do
      assert_select "a[href=?]", consultation_path(conflicting), text: conflicting.title
      assert_select ".rc-overlap-heading", text: /Schedule overlap/
    end

    get edit_consultation_url(@existing)
    assert_response :success
    assert_select ".rc-overlap-notice a[href=?]", consultation_path(conflicting), count: 1
    assert_select "input#consultation_start_time", count: 1
  end

  test "guest read view does not expose admin-only conflict advisory and reschedule action" do
    Consultation.create!(
      title: "Overlapping private review",
      start_time: Time.zone.local(2023, 1, 19, 23, 0),
      end_time: Time.zone.local(2023, 1, 19, 23, 30)
    )

    get consultation_url(@existing)
    assert_response :success
    assert_select ".rc-overlap-notice", count: 0

    get consultations_url
    assert_response :success
    assert_select "a[href=?]", edit_consultation_path(@existing, anchor: "consultation_start_time"), count: 0

    get edit_consultation_url(@existing)
    assert_redirected_to admin_login_url
  end

  test "admin list exposes one-hop reschedule into the time field" do
    sign_in_as_admin
    get consultations_url
    assert_response :success
    assert_select "a[href=?]", edit_consultation_path(@existing, anchor: "consultation_start_time"), count: 1
    assert_select "a[aria-label=?]", "Reschedule #{@existing.title}", count: 1
  end

  test "saving an overlap is permitted pending booking policy and advisory is refreshed" do
    sign_in_as_admin
    candidate = consultations(:two)
    original_start = @existing.start_time
    new_start = Time.zone.local(2023, 1, 19, 23, 0)
    new_end = new_start + 30.minutes

    patch consultation_url(candidate), params: {
      consultation: { start_time: new_start.strftime("%Y-%m-%dT%H:%M"),
                      end_time: new_end.strftime("%Y-%m-%dT%H:%M"),
                      reschedule_reason: "Approved overlapping consultation QA" }
    }

    assert_redirected_to consultation_url(candidate)
    assert_equal new_start, candidate.reload.start_time
    assert_equal original_start, @existing.reload.start_time

    follow_redirect!
    assert_response :success
    assert_select ".rc-overlap-notice a[href=?]", consultation_path(@existing), count: 1
  end

  test "prefilled new form shows existing calendar overlaps without saving" do
    sign_in_as_admin

    assert_no_difference "Consultation.count" do
      get new_consultation_url(start_at: "2023-01-19T22:45:00Z")
    end
    assert_response :success
    assert_select ".rc-overlap-notice a[href=?]", consultation_path(@existing), count: 1
  end

  test "meeting precisely at an end boundary does not cause a false warning" do
    boundary = Consultation.create!(
      title: "Following boundary",
      start_time: @existing.end_time.change(sec: 0) + 1.minute,
      end_time: @existing.end_time.change(sec: 0) + 31.minutes
    )

    sign_in_as_admin
    get consultation_url(boundary)
    assert_response :success
    assert_select ".rc-overlap-notice", count: 0
  end

  private

  def sign_in_as_admin
    post admin_session_url, params: {
      username: ENV.fetch("RAILS_CALENDAR_ADMIN_USERNAME"),
      password: ENV.fetch("RAILS_CALENDAR_ADMIN_PASSWORD")
    }
    assert_redirected_to consultations_url
  end
end
