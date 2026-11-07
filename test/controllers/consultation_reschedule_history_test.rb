require "test_helper"

class ConsultationRescheduleHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @consultation = consultations(:two)
  end

  test "administrator move atomically retains old/new times, reason and server actor" do
    sign_in_as_admin
    old_start, old_end = @consultation.start_time, @consultation.end_time
    new_start = old_start + 35.minutes
    new_end = old_end + 35.minutes

    assert_difference "ConsultationRescheduleEvent.count", 1 do
      patch consultation_url(@consultation), params: {
        consultation: {
          title: @consultation.title,
          start_time: new_start.strftime("%Y-%m-%dT%H:%M"),
          end_time: new_end.strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "Client requested a later slot",
          actor_label: "forged-actor-from-request"
        }
      }
    end

    assert_redirected_to consultation_url(@consultation)
    event = ConsultationRescheduleEvent.order(:id).last
    assert_equal @consultation.id, event.consultation_id
    assert_equal old_start, event.old_start_time
    assert_equal old_end, event.old_end_time
    assert_equal new_start, event.new_start_time
    assert_equal new_end, event.new_end_time
    assert_equal "Client requested a later slot", event.reason
    assert_equal "administrator", event.actor_label
    assert_in_delta Time.current.to_i, event.created_at.to_i, 15
    assert_equal new_start, @consultation.reload.start_time

    get consultation_url(@consultation)
    assert_response :success
    assert_select "#reschedule-history-title", text: /Reschedule history/
    assert_select ".rc-reschedule-history li", count: 1
    assert_select ".rc-reschedule-history", text: /Client requested a later slot/
  end

  test "changing schedule without a reason is rejected with no writes" do
    sign_in_as_admin
    old_start, old_end = @consultation.start_time, @consultation.end_time

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: {
          start_time: (old_start + 1.hour).strftime("%Y-%m-%dT%H:%M"),
          end_time: (old_end + 1.hour).strftime("%Y-%m-%dT%H:%M")
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#consultation-form-errors", text: /Reason for rescheduling is required/
    assert_select "#consultation_reschedule_reason", count: 1
    assert_equal old_start, @consultation.reload.start_time
    assert_equal old_end, @consultation.end_time
  end

  test "too long a reason and invalid end time never write half an audit" do
    sign_in_as_admin
    old_start = @consultation.start_time

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: {
          start_time: (old_start + 1.hour).strftime("%Y-%m-%dT%H:%M"),
          end_time: (@consultation.end_time + 1.hour).strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "r" * 501
        }
      }
    end
    assert_response :unprocessable_entity
    assert_equal old_start, @consultation.reload.start_time

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: {
          end_time: (old_start - 1.minute).strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "Attempted invalid interval"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_equal old_start, @consultation.reload.start_time
  end

  test "text-only changes and unchanged minute fields never produce reschedule audit" do
    sign_in_as_admin
    legacy = consultations(:one) # Both original timestamps contain legacy seconds.
    first = legacy.start_time
    last = legacy.end_time

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(legacy), params: {
        consultation: {
          title: "Edited without moving",
          start_time: first.in_time_zone.strftime("%Y-%m-%dT%H:%M"),
          end_time: last.in_time_zone.strftime("%Y-%m-%dT%H:%M")
        }
      }
    end
    assert_redirected_to consultation_url(legacy)
    assert_equal first, legacy.reload.start_time
    assert_equal last, legacy.end_time
    assert_equal "Edited without moving", legacy.title
  end

  test "unauthenticated requests cannot change time, provide reason or see history" do
    old_start = @consultation.start_time
    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: {
          start_time: (old_start + 1.hour).strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "Unauthorized reason"
        }
      }
    end
    assert_redirected_to admin_login_url
    assert_equal old_start, @consultation.reload.start_time

    get consultation_url(@consultation)
    assert_response :success
    assert_select "#reschedule-history-title", count: 0
    assert_select ".rc-reschedule-history", count: 0
  end

  test "existing reschedule history is retained after physical deletion in isolated test DB" do
    sign_in_as_admin
    patch consultation_url(@consultation), params: {
      consultation: {
        start_time: (@consultation.start_time + 15.minutes).strftime("%Y-%m-%dT%H:%M"),
        reschedule_reason: "Test-only time adjustment"
      }
    }
    assert_redirected_to consultation_url(@consultation)
    event_id = ConsultationRescheduleEvent.last.id
    consultation_id = @consultation.id

    assert_difference "Consultation.count", -1 do
      delete consultation_url(@consultation)
    end
    assert_equal consultation_id, ConsultationRescheduleEvent.find(event_id).consultation_id
    assert_equal "Test-only time adjustment", ConsultationRescheduleEvent.find(event_id).reason
  end

  test "audit entry reason is escaped when rendered in administrator HTML" do
    sign_in_as_admin
    patch consultation_url(@consultation), params: {
      consultation: {
        end_time: (@consultation.end_time + 5.minutes).strftime("%Y-%m-%dT%H:%M"),
        reschedule_reason: "<script>alert('xss')</script>"
      }
    }
    assert_redirected_to consultation_url(@consultation)
    follow_redirect!
    assert_select ".rc-reschedule-history script", count: 0
    assert_select ".rc-reschedule-history", text: /<script>alert/
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
