require "test_helper"

class ConsultationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @consultation = consultations(:one)
    @valid_attributes = {
      description: @consultation.description,
      # Fixture :one intentionally includes legacy seconds (:51). New
      # consultations must be submitted with whole-minute precision.
      end_time: @consultation.end_time.change(sec: 0),
      start_time: @consultation.start_time.change(sec: 0),
      title: @consultation.title
    }
  end

  test "anyone may read the consultations index" do
    get consultations_url
    assert_response :success
    assert_select "a[href=?]", new_consultation_path, count: 0
  end

  test "anyone may read one consultation" do
    get consultation_url(@consultation)
    assert_response :success
    assert_select "a[href=?]", edit_consultation_path(@consultation), count: 0
    assert_select "form[action=?]", consultation_path(@consultation), count: 0
  end

  test "anonymous users cannot open new or edit forms" do
    get new_consultation_url
    assert_redirected_to admin_login_url

    get edit_consultation_url(@consultation)
    assert_redirected_to admin_login_url
  end

  test "anonymous users cannot create consultations" do
    assert_no_difference "Consultation.count" do
      post consultations_url, params: { consultation: @valid_attributes }
    end
    assert_redirected_to admin_login_url
  end

  test "anonymous users cannot patch or put consultations" do
    original_title = @consultation.title

    patch consultation_url(@consultation), params: { consultation: { title: "Unauthorized patch" } }
    assert_redirected_to admin_login_url
    assert_equal original_title, @consultation.reload.title

    put consultation_url(@consultation), params: { consultation: { title: "Unauthorized put" } }
    assert_redirected_to admin_login_url
    assert_equal original_title, @consultation.reload.title
  end

  test "anonymous users cannot delete consultations" do
    assert_no_difference "Consultation.count" do
      delete consultation_url(@consultation)
    end
    assert_redirected_to admin_login_url
  end

  test "admin form exposes required inputs and time zone help" do
    sign_in_as_admin

    get new_consultation_url

    assert_response :success
    assert_select "input[name='consultation[title]'][required]", count: 1
    assert_select "input[name='consultation[start_time]'][required][step='60']", count: 1
    assert_select "input[name='consultation[end_time]'][required][step='60']", count: 1
    assert_select "#consultation-timezone-hint", text: /UTC/
  end

  test "admin can open new and edit forms" do
    sign_in_as_admin
    get new_consultation_url
    assert_response :success
    get edit_consultation_url(@consultation)
    assert_response :success
  end

  test "admin can create a consultation" do
    sign_in_as_admin
    assert_difference "Consultation.count", 1 do
      post consultations_url, params: { consultation: @valid_attributes }
    end
    assert_redirected_to consultation_url(Consultation.last)
  end

  test "admin can update a consultation" do
    sign_in_as_admin
    patch consultation_url(@consultation), params: { consultation: { title: "Admin update" } }
    assert_redirected_to consultation_url(@consultation)
    assert_equal "Admin update", @consultation.reload.title
  end

  test "edit form hides legacy seconds without silently modifying stored instants" do
    sign_in_as_admin

    legacy_end_time = @consultation.end_time.change(sec: 7)
    @consultation.update_columns(end_time: legacy_end_time)

    get edit_consultation_url(@consultation)
    assert_response :success
    assert_select "input[name='consultation[end_time]'][step='60'][value=?]",
                  legacy_end_time.in_time_zone.strftime("%Y-%m-%dT%H:%M"), count: 1

    patch consultation_url(@consultation), params: {
      consultation: {
        title: "Text-only update",
        start_time: @consultation.start_time.in_time_zone.strftime("%Y-%m-%dT%H:%M"),
        end_time: legacy_end_time.in_time_zone.strftime("%Y-%m-%dT%H:%M")
      }
    }
    assert_redirected_to consultation_url(@consultation)
    assert_equal legacy_end_time, @consultation.reload.end_time
    assert_equal "Text-only update", @consultation.title
  end

  test "new and changed times reject seconds while minute inputs remain valid" do
    sign_in_as_admin
    start_input = @consultation.start_time.in_time_zone.strftime("%Y-%m-%dT%H:%M")
    end_input = @consultation.end_time.in_time_zone.strftime("%Y-%m-%dT%H:%M")

    assert_no_difference "Consultation.count" do
      post consultations_url, params: {
        consultation: { title: "Rejected seconds", start_time: start_input, end_time: "#{end_input}:07" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "#consultation-form-errors", text: /seconds must be 00/

    assert_difference "Consultation.count", 1 do
      post consultations_url, params: {
        consultation: { title: "Minute-only", start_time: start_input, end_time: end_input }
      }
    end
    created = Consultation.order(:id).last
    assert_equal 0, created.start_time.sec
    assert_equal 0, created.end_time.sec
  end

  test "delete action identifies the exact record before confirmation" do
    sign_in_as_admin
    get consultation_url(@consultation)
    assert_response :success

    assert_select "button[aria-label='Destroy this consultation']" do |buttons|
      confirmation = buttons.first["data-turbo-confirm"]
      assert_includes confirmation, "##{@consultation.id}"
      assert_includes confirmation, @consultation.title
      assert_includes confirmation, @consultation.start_time.in_time_zone.strftime("%d %b %Y")
      assert_includes confirmation, "cannot be undone"
    end
  end

  test "admin can delete a consultation" do
    sign_in_as_admin
    assert_difference "Consultation.count", -1 do
      delete consultation_url(@consultation)
    end
    assert_redirected_to consultations_url
  end

  test "admin receives a validation error for invalid times" do
    sign_in_as_admin
    assert_no_difference "Consultation.count" do
      post consultations_url, params: {
        consultation: @valid_attributes.merge(end_time: @valid_attributes[:start_time])
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role='alert']#consultation-form-errors"
    assert_select "input[name='consultation[end_time]'][aria-invalid='true']"
  end


  test "admin cannot create consultation outside supported years" do
    sign_in_as_admin

    assert_no_difference "Consultation.count" do
      post consultations_url, params: {
        consultation: @valid_attributes.merge(
          start_time: "1212-12-12T12:12",
          end_time: "1213-12-12T13:12"
        )
      }
    end
    assert_response :unprocessable_entity
    assert_select "#consultation-form-errors", text: /between years 2000 and 2100/
  end

  test "admin cannot update consultation with far future year" do
    sign_in_as_admin
    original_end = @consultation.end_time

    patch consultation_url(@consultation), params: {
      consultation: {
        start_time: "2101-12-12T12:12",
        end_time: "2101-12-12T13:12"
      }
    }

    assert_response :unprocessable_entity
    assert_equal original_end, @consultation.reload.end_time
    assert_select "#consultation-form-errors", text: /between years 2000 and 2100/
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
