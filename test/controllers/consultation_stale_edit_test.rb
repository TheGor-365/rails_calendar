require "test_helper"

class ConsultationStaleEditTest < ActionDispatch::IntegrationTest
  setup do
    @consultation = consultations(:two)
  end

  test "edit form contains lock version but create form does not" do
    sign_in
    get edit_consultation_url(@consultation)
    assert_response :success
    assert_select "input[type='hidden'][name='consultation[lock_version]'][value=?]",
                  @consultation.lock_version.to_s, count: 1

    get new_consultation_url
    assert_response :success
    assert_select "input[name='consultation[lock_version]']", count: 0
  end

  test "a stale tab cannot overwrite a newer title" do
    sign_in
    first_version = @consultation.lock_version

    patch consultation_url(@consultation), params: {
      consultation: { lock_version: first_version, title: "First tab saved" }
    }
    assert_redirected_to consultation_url(@consultation)
    assert_equal "First tab saved", @consultation.reload.title
    assert_equal first_version + 1, @consultation.lock_version

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: { lock_version: first_version, title: "Stale overwrite" }
      }
    end
    assert_response :conflict
    assert_select "#consultation-form-errors[role='alert']", text: /changed in another tab/
    assert_select "input[name='consultation[title]'][value=?]", "First tab saved", count: 1
    assert_select "input[name='consultation[lock_version]'][value=?]",
                  (first_version + 1).to_s, count: 1
    assert_equal "First tab saved", @consultation.reload.title
  end

  test "a stale reschedule cannot produce duplicate history" do
    sign_in
    version = @consultation.lock_version
    start = @consultation.start_time
    finish = @consultation.end_time
    assert_difference "ConsultationRescheduleEvent.count", 1 do
      patch consultation_url(@consultation), params: {
        consultation: {
          lock_version: version,
          start_time: (start + 15.minutes).strftime("%Y-%m-%dT%H:%M"),
          end_time: (finish + 15.minutes).strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "First admin edit"
        }
      }
    end
    assert_redirected_to consultation_url(@consultation)

    assert_no_difference "ConsultationRescheduleEvent.count" do
      patch consultation_url(@consultation), params: {
        consultation: {
          lock_version: version,
          start_time: (start + 45.minutes).strftime("%Y-%m-%dT%H:%M"),
          end_time: (finish + 45.minutes).strftime("%Y-%m-%dT%H:%M"),
          reschedule_reason: "Obsolete admin edit"
        }
      }
    end
    assert_response :conflict
    assert_equal start + 15.minutes, @consultation.reload.start_time
    assert_equal finish + 15.minutes, @consultation.end_time
    assert_equal version + 1, @consultation.lock_version
    assert_equal "First admin edit", ConsultationRescheduleEvent.last.reason
  end

  test "missing malformed or forged versions fail closed" do
    sign_in
    title = @consultation.title
    version = @consultation.lock_version
    [nil, "", "-1", "1.5", "junk", "00", (version + 100).to_s].each do |token|
      attrs = { title: "Untrusted change" }
      attrs[:lock_version] = token unless token.nil?
      assert_no_difference "ConsultationRescheduleEvent.count" do
        patch consultation_url(@consultation), params: { consultation: attrs }
      end
      assert_response :conflict
      assert_equal title, @consultation.reload.title
      assert_equal version, @consultation.lock_version
    end
  end

  test "a fresh version permits subsequent valid changes" do
    sign_in
    version = @consultation.lock_version
    patch consultation_url(@consultation), params: {
      consultation: { lock_version: version, title: "First allowed change" }
    }
    assert_redirected_to consultation_url(@consultation)
    @consultation.reload

    patch consultation_url(@consultation), params: {
      consultation: { lock_version: @consultation.lock_version, title: "Second allowed change" }
    }
    assert_redirected_to consultation_url(@consultation)
    assert_equal "Second allowed change", @consultation.reload.title
    assert_equal version + 2, @consultation.lock_version
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
