require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class ClientServiceSelectionTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @prior_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"
    @owner = make_test_owner("e1-owner-#{SecureRandom.hex(4)}@example.test")
    @client = make_test_client("e1-client-#{SecureRandom.hex(4)}@example.test")
    @foreign_client = make_test_client("e1-foreign-#{SecureRandom.hex(4)}@example.test")
    @workspace, _profile, _snapshot, caps = approved_profile_for(@owner)
    @offering = published_offering(@workspace, caps.first, "Fix a synthetic Rails form")
    @version = @offering.published_version
    @foreign_owner = make_test_owner("e1-other-#{SecureRandom.hex(4)}@example.test")
    @foreign_workspace, _other_profile, _other_snapshot, other_caps = approved_profile_for(@foreign_owner)
    @foreign_offering = published_offering(@foreign_workspace, other_caps.first, "Other synthetic Rails task")
  end

  teardown do
    @prior_pilot.nil? ? ENV.delete("RC_LOCAL_CLIENT_REQUESTS_ENABLED") : ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
    @prior_ai.nil? ? ENV.delete("RC_GROK_ENABLED") : ENV["RC_GROK_ENABLED"] = @prior_ai
  end

  test "verified client picks an approved published version; draft and foreign data stay isolated" do
    login(@client)
    get new_client_request_path
    assert_response :success
    assert_select ".wa-client-form__services input[value=?]", @version.id.to_s
    assert_select ".wa-client-form__services", text: /Fix a synthetic Rails form/
    assert_select "input[name='service_version_ids[]']", minimum: 2

    assert_difference("ProjectIntake.count", 1) do
      assert_difference("IntakeServiceSelection.count", 1) do
        post client_requests_path, params: {
          service_version_ids: [@version.id.to_s],
          demo_consent: "1",
          project_intake: { title: "", project_type: "", goal: "" }
        }
      end
    end
    intake = @client.client_project_intakes.order(:id).last
    assert_redirected_to client_request_path(intake)
    assert_equal @workspace.id, intake.workspace_id
    assert_equal "rails_bugfix", intake.project_type
    assert_equal "Fix a synthetic Rails form", intake.title
    assert_equal [@version.id], intake.selected_service_offering_versions.pluck(:id)
    assert_includes intake.goal, "Fix a synthetic Rails form"

    get client_request_path(intake)
    assert_response :success
    assert_select ".wa-client-request__services li", count: 1
    delete sign_out_path
    login(@foreign_client)
    get client_request_path(intake)
    assert_response :not_found
  end

  test "custom request without selected services is still possible" do
    login(@client)
    assert_difference("ProjectIntake.count", 1) do
      post client_requests_path, params: {
        demo_consent: "1", selected_workspace_id: @workspace.id,
        project_intake: {
          title: "Synthetic custom automation", project_type: "website",
          goal: "Invented business needs a custom online form without fixed services."
        }
      }
    end
    intake = @client.client_project_intakes.order(:id).last
    assert_equal 0, intake.intake_service_selections.count
    assert_equal @client.id, intake.client_user_id
    assert_equal @workspace.id, intake.workspace_id
  end

  test "reject unpublished, stale, missing and cross-workspace versions without saving" do
    draft = OwnerServices::Catalogue.new(workspace: @workspace).create_draft!(
      service_fields(@workspace.professional_profile.professional_capabilities.find_by!(domain: "react"),
                     title: "Private fictional Rails draft")
    )
    stale_id = draft.latest_version.id
    foreign_id = @foreign_offering.published_version_id
    login(@client)
    [[stale_id], [foreign_id, @version.id], ["999999999"]].each do |ids|
      assert_no_difference("ProjectIntake.count") do
        assert_no_difference("IntakeServiceSelection.count") do
          post client_requests_path, params: {
            demo_consent: "1", service_version_ids: ids,
            project_intake: { title: "Synthetic mixed version", project_type: "rails_bugfix",
                              goal: "A fictional task with a forged service selection." }
          }
          assert_response :unprocessable_entity
        end
      end
    end
  end

  private

  def published_offering(workspace, capability, title)
    offer = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capability, title: title)
    )
    version = offer.latest_version
    version.update!(approved_at: Time.current)
    offer.update!(approved_version: version, published_version: version)
    offer
  end

  def login(user)
    post account_session_path, params: {email: user.email, password: PASSWORD}
    assert_redirected_to client_home_path
  end
end
