require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceAutoSyncTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("auto-sync-controller-owner@example.test")
    @client = make_test_client("auto-sync-controller-client@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(
      @owner, capabilities: %w[rails testing], desired_services: %w[rails_bugfix rails_tests]
    )
  end

  test "owner generates catalog once by POST and remains private" do
    sign_in(@owner)
    get owner_services_path
    assert_response :success
    assert_select "form[action=?][method='post']", sync_owner_services_path
    assert_select ".wa-services__card", count: 0
    assert_difference "ServiceOffering.count", 2 do
      post sync_owner_services_path
    end
    assert_redirected_to owner_services_path
    assert_equal %w[auto-rails-bugfix auto-rails-tests],
      @workspace.service_offerings.order(:key).pluck(:key)

    assert_no_difference "ServiceOffering.count" do
      post sync_owner_services_path
    end
    get owner_services_path
    assert_select ".wa-services__card", count: 2
    assert_select ".wa-services__state--draft", text: /Draft/
    get services_path
    assert_response :success
    assert_no_match(/Исправление ошибок Ruby on Rails/, response.body)
  end

  test "client and anonymous cannot use owner auto generation" do
    get owner_services_path
    assert_redirected_to sign_in_path
    post sync_owner_services_path
    assert_redirected_to sign_in_path
    sign_in(@client)
    assert_no_difference "ServiceOffering.count" do
      post sync_owner_services_path
    end
    assert_redirected_to sign_in_path
  end

  test "pending owner profile approval refuses sync" do
    @profile.update!(onboarding_state: "draft")
    sign_in(@owner)
    assert_no_difference "ServiceOffering.count" do
      post sync_owner_services_path
    end
    assert_redirected_to owner_services_path
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
