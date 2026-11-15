require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServicesBulkApprovalTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("bulk-finalize-owner@example.test")
    @client = make_test_client("bulk-finalize-client@example.test")
    @other = make_test_owner("bulk-finalize-foreign@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    @first = @catalogue.create_draft!(service_fields(@capabilities.first))
    @second = @catalogue.create_draft!(service_fields(@capabilities.last, title: "Evaluate a fictional React UI"))
    @third = @catalogue.create_draft!(service_fields(@capabilities.first, title: "Review a different synthetic Rails bug"))
    draft = @first.draft_version
    @catalogue.approve!(offering: @first, version: draft.version, digest: draft.digest, confirmed: true)
    @bulk = OwnerServices::BulkApproval.new(workspace: @workspace)
  end

  test "owner finalizes only outstanding drafts; never enables or publishes anything" do
    sign_in(@owner)
    get owner_services_path
    assert_response :success
    assert_select "form[action=?]", approve_all_owner_services_path
    assert_select ".wa-services__card", count: 3
    assert_select ".wa-services__card-footer", count: 3

    before = @bulk.fingerprint
    assert_no_difference("ServiceOfferingPublication.count") do
      post approve_all_owner_services_path, params: { fingerprint: before }
    end
    assert_redirected_to owner_services_path
    assert_equal 0, OwnerServices::BulkApproval.new(workspace: @workspace).drafts.length
    assert_equal [1, 1, 1], [@first, @second, @third].map { |o| o.reload.approved_version.version }
    assert [@first, @second, @third].all? { |o| o.reload.published_version.nil? }
    assert_equal "conditional", @second.reload.approved_version.delivery_mode
    assert_response :redirect
  end

  test "card finalization returns to catalog without a supplied open redirect" do
    sign_in(@owner)
    draft = @second.draft_version
    post approve_owner_service_path(@second), params: {
      version: draft.version, digest: draft.digest,
      confirm: "1", return_to_catalog: "1"
    }
    assert_redirected_to owner_services_path
    assert @second.reload.approved_version
    assert_nil @second.published_version
  end

  test "stale fingerprint fails atomically without approving partial draft list" do
    sign_in(@owner)
    old = @bulk.fingerprint
    newer = @second.draft_version
    @catalogue.update_draft!(
      offering: @second,
      attributes: service_fields(@capabilities.last, title: "Different fictional React prototype with tests"),
      version: newer.version, digest: newer.digest
    )
    post approve_all_owner_services_path, params: { fingerprint: old }
    assert_redirected_to owner_services_path
    assert_nil @second.reload.approved_version
    assert_nil @third.reload.approved_version
    assert @first.reload.approved_version
  end

  test "unapproved profile blocks batch and rolls back every draft" do
    sign_in(@owner)
    key = @bulk.fingerprint
    @profile.update!(onboarding_state: "draft")
    post approve_all_owner_services_path, params: { fingerprint: key }
    assert_redirected_to owner_services_path
    assert_nil @second.reload.approved_version
    assert_nil @third.reload.approved_version
  end

  test "client, guest, and foreign owner cannot finalize this owner's drafts" do
    post approve_all_owner_services_path, params: { fingerprint: @bulk.fingerprint }
    assert_redirected_to sign_in_path
    sign_in(@client)
    post approve_all_owner_services_path, params: { fingerprint: @bulk.fingerprint }
    assert_redirected_to sign_in_path
    delete sign_out_path
    sign_in(@other)
    post approve_all_owner_services_path, params: { fingerprint: @bulk.fingerprint }
    assert_redirected_to owner_services_path
    assert_nil @second.reload.approved_version
    assert_nil @third.reload.approved_version
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
