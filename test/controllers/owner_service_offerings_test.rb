require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceOfferingsTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("owner-offering-controller@example.test")
    @other_owner = make_test_owner("other-offering-controller@example.test")
    @client = make_test_client("client-offering-controller@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
  end

  test "owner creates and reviews versions, but /services and client flow never expose them" do
    sign_in(@owner)
    get owner_services_path
    assert_response :success
    assert_select "#owner-services"
    assert_select "a[href=?]", new_owner_service_path
    get new_owner_service_path
    assert_response :success
    assert_select "form[action=?]", owner_services_path
    assert_select "select[name='service_offering[professional_capability_id]']"

    assert_difference({"ServiceOffering.count" => 1, "ServiceOfferingVersion.count" => 1}) do
      post owner_services_path, params: { service_offering: service_fields(@capabilities.first) }
    end
    offer = @workspace.service_offerings.last
    assert_redirected_to owner_service_path(offer)
    get owner_service_path(offer)
    assert_response :success
    assert_select "#offering-draft-form", count: 1
    assert_select "#offering-approval", count: 1
    assert_select "#offering-publication", count: 0

    post approve_owner_service_path(offer), params: {
      version: 1, digest: offer.draft_version.digest, confirm: "0"
    }
    assert_nil offer.reload.approved_version

    post approve_owner_service_path(offer), params: {
      version: 1, digest: offer.draft_version.digest, confirm: "1"
    }
    assert_equal 1, offer.reload.approved_version.version
    assert_nil offer.published_version

    get services_path
    assert_response :success
    assert_no_match(/Fix a fictional Rails error/, response.body)
    get new_client_request_path
    assert_response :not_found # Local client pilot flag is intentionally disabled.

    post publish_owner_service_path(offer), params: {
      version_id: offer.approved_version.id, digest: offer.approved_version.digest, confirm: "0"
    }
    assert_nil offer.reload.published_version

    post publish_owner_service_path(offer), params: {
      version_id: offer.approved_version.id, digest: offer.approved_version.digest, confirm: "1"
    }
    assert_equal 1, offer.reload.published_version.version
    assert_equal 1, ServiceOfferingPublication.where(service_offering: offer, event: "publish").count
    get services_path
    assert_no_match(/Fix a fictional Rails error/, response.body)

    post revise_owner_service_path(offer)
    assert_equal 2, offer.reload.draft_version.version
    assert_equal 1, offer.published_version.version
    get owner_service_path(offer)
    assert_select "#offering-draft-form", count: 1
    assert_select "#offering-publication", count: 1
  end

  test "anonymous, client, and another owner cannot read or write private offering" do
    offer = OwnerServices::Catalogue.new(workspace: @workspace).create_draft!(service_fields(@capabilities.first))
    get owner_services_path
    assert_redirected_to sign_in_path
    get owner_service_path(offer)
    assert_redirected_to sign_in_path
    post approve_owner_service_path(offer), params: { version: 1, digest: offer.draft_version.digest, confirm: "1" }
    assert_redirected_to sign_in_path

    sign_in(@client)
    get owner_services_path
    assert_redirected_to sign_in_path
    post owner_services_path, params: { service_offering: service_fields(@capabilities.first) }
    assert_redirected_to sign_in_path
    delete sign_out_path

    sign_in(@other_owner)
    get owner_services_path
    assert_response :success
    get owner_service_path(offer)
    assert_response :not_found
    post publish_owner_service_path(offer), params: { version_id: offer.draft_version.id, digest: offer.draft_version.digest, confirm: "1" }
    assert_response :not_found
    assert_nil offer.reload.approved_version
    assert_nil offer.published_version
  end

  test "cross-account forged capability, malformed data and stale digest are rejected" do
    other_ws, _other_prof, _other_snap, other_caps = approved_profile_for(@other_owner)
    sign_in(@owner)
    assert_no_difference("ServiceOffering.count") do
      post owner_services_path, params: { service_offering: service_fields(other_caps.first) }
    end
    assert_response :unprocessable_entity

    assert_no_difference("ServiceOffering.count") do
      post owner_services_path, params: { service_offering: service_fields(@capabilities.first).merge(title: "No") }
    end
    assert_response :unprocessable_entity

    offer = OwnerServices::Catalogue.new(workspace: @workspace).create_draft!(service_fields(@capabilities.first))
    original_digest = offer.draft_version.digest
    patch owner_service_draft_path(offer), params: {
      base_version: 1, base_digest: original_digest,
      service_offering: service_fields(@capabilities.first).merge(title: "Fictional Rails 500 fix with unit tests")
    }
    assert_equal "Fictional Rails 500 fix with unit tests", offer.reload.draft_version.title
    assert_no_difference("ServiceOfferingVersion.count") do
      patch owner_service_draft_path(offer), params: {
        base_version: 1, base_digest: original_digest,
        service_offering: service_fields(@capabilities.first).merge(title: "Stale tab overwrite")
      }
    end
    assert_equal "Fictional Rails 500 fix with unit tests", offer.reload.draft_version.title
  end

  test "Turbo service quick view is private, read-only, and preserves the full-page route" do
    offer = OwnerServices::Catalogue.new(workspace: @workspace)
      .create_draft!(service_fields(@capabilities.first))
    sign_in(@owner)

    get owner_services_path
    assert_response :success
    assert_select "a[href=?][data-turbo-frame='wa-owner-service-preview']", owner_service_path(offer)
    assert_select ".wa-services__hero-symbol", count: 1
    assert_select ".wa-services__card .wa-services__cover-fallback", minimum: 1
    assert_select ".wa-services__tools summary", count: 1

    assert_no_difference("ServiceOfferingVersion.count") do
      get owner_service_path(offer), headers: { "Turbo-Frame" => "wa-owner-service-preview" }
    end
    assert_response :success
    assert_match(/private, no-store/, response.headers.fetch("Cache-Control"))
    assert_select "turbo-frame#wa-owner-service-preview" do
      assert_select "h2", text: offer.draft_version.title
      assert_select ".wa-services__preview-heading h2", text: offer.draft_version.title
      assert_select ".wa-services__preview-fact h3", text: /#{Regexp.escape(I18n.t("owner_services.included_scope"))}/
      assert_select "form", count: 0
      assert_select "a[data-turbo-frame='_top'][href=?]", owner_service_path(offer)
    end

    get owner_service_path(offer)
    assert_response :success
    assert_select "#offering-draft-form", count: 1

    delete sign_out_path
    get owner_service_path(offer), headers: { "Turbo-Frame" => "wa-owner-service-preview" }
    assert_redirected_to sign_in_path

    sign_in(@client)
    get owner_service_path(offer), headers: { "Turbo-Frame" => "wa-owner-service-preview" }
    assert_redirected_to sign_in_path

    delete sign_out_path
    sign_in(@other_owner)
    get owner_service_path(offer), headers: { "Turbo-Frame" => "wa-owner-service-preview" }
    assert_response :not_found
  end

  test "all locales have the review labels used by the service forms" do
    %i[en ru hy es].each do |locale|
      I18n.with_locale(locale) do
        %w[title private_title summary capability category approval_title confirm_approval
           publication_title confirm_publication new_revision history stale review_required
           catalogue_tools quick_preview close_preview cover_placeholder preview_private_hint].each do |key|
          assert I18n.exists?("owner_services.#{key}"), "Missing #{locale}.owner_services.#{key}"
        end
      end
    end
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
