require "test_helper"

class WhiteAtlasFormAutogrowTest < ActionDispatch::IntegrationTest
  PASSWORD = "synthetic-owner-autogrow-password-2026".freeze

  setup do
    @owner = User.create!(email: "autogrow-owner@example.test", role: "owner", password: PASSWORD)
    post account_session_path, params: { email: @owner.email, password: PASSWORD }
    assert_redirected_to workspace_path
  end

  test "consultation creation retains native description and optional textarea enhancer" do
    get new_consultation_path
    assert_response :success
    assert_select "textarea[name='consultation[description]'][maxlength='5000'][data-controller='wa-autogrow']", count: 1
    assert_select "input[name='consultation[start_time]'][required]", count: 1
    assert_select "input[name='consultation[end_time]'][required]", count: 1
  end

  test "owner can edit existing consultation with reschedule reason and accessible native textarea" do
    record = consultations(:one)
    get edit_consultation_path(record)
    assert_response :success
    assert_select "textarea[name='consultation[description]'][data-controller='wa-autogrow']", count: 1
    assert_select "textarea[name='consultation[reschedule_reason]'][maxlength='500'][data-controller='wa-autogrow']", count: 1
    assert_select "input[name='consultation[lock_version]']", count: 1
  end
end
