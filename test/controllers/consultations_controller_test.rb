require "test_helper"

class ConsultationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @consultation = consultations(:one)
    @valid_attributes = {
      description: @consultation.description,
      end_time: @consultation.end_time,
      start_time: @consultation.start_time,
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
    assert_select "input[name='consultation[start_time]'][required]", count: 1
    assert_select "input[name='consultation[end_time]'][required]", count: 1
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
