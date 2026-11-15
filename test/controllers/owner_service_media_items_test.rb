require "test_helper"
require "tempfile"
require "base64"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServiceMediaItemsTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==".freeze

  setup do
    @owner = make_test_owner("media-controller-owner@example.test")
    @client = make_test_client("media-controller-client@example.test")
    @other = make_test_owner("media-controller-other@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
    @offer = OwnerServices::Catalogue.new(workspace: @workspace).create_draft!(
      service_fields(@capabilities.first)
    )
    @tempfiles = []
  end

  teardown do
    @tempfiles.each { |file| file.close! rescue nil }
  end

  test "owner uploads a local image, reviews it and downloads via protected route" do
    sign_in(@owner)
    assert_difference("ServiceOfferingMediaItem.count" => 1) do
      post owner_service_media_items_path(@offer), params: {
        media: { media_kind: "banner", caption: "Fictional Rails banner",
                 file: upload_png }
      }
    end
    assert_redirected_to owner_service_path(@offer, anchor: "offering-media")
    item = @offer.media_items.last
    assert_equal "banner", item.media_kind
    assert item.file.attached?
    assert_equal @offer.draft_version.id, item.service_offering_version_id
    assert_nil item.approved_at
    assert_equal false, item.ai_access_allowed
    assert_equal false, item.can_be_processed_by_ai?

    get owner_service_path(@offer)
    assert_response :success
    assert_select "#offering-media-upload"
    assert_select "img.wa-services__media-thumb[src=?]", owner_service_media_file_path(@offer, item)

    get owner_service_media_file_path(@offer, item)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    post approve_owner_service_media_path(@offer, item)
    assert_redirected_to owner_service_path(@offer, anchor: "offering-media")
    assert item.reload.approved?
    get owner_services_path
    assert_select "img.wa-services__card-banner[src=?]", owner_service_media_file_path(@offer, item)
    assert_nil @offer.reload.approved_version
    assert_nil @offer.published_version

    delete archive_owner_service_media_path(@offer, item)
    assert_redirected_to owner_service_path(@offer, anchor: "offering-media")
    assert item.reload.archived_at
    assert item.file.attached?
    get owner_service_media_file_path(@offer, item)
    assert_response :not_found
    get owner_service_path(@offer)
    assert_select ".wa-services__media-item", count: 0
  end

  test "guest, client and foreign owner cannot access or mutate media" do
    sign_in(@owner)
    post owner_service_media_items_path(@offer), params: {
      media: { media_kind: "image", caption: "Private sample", file: upload_png }
    }
    item = @offer.media_items.last
    delete sign_out_path

    get owner_service_media_file_path(@offer, item)
    assert_redirected_to sign_in_path
    post approve_owner_service_media_path(@offer, item)
    assert_redirected_to sign_in_path
    sign_in(@client)
    get owner_service_media_file_path(@offer, item)
    assert_redirected_to sign_in_path
    assert_no_difference("ServiceOfferingMediaItem.count") do
      post owner_service_media_items_path(@offer), params: {
        media: { media_kind: "image", file: upload_png }
      }
    end
    delete sign_out_path
    sign_in(@other)
    get owner_service_media_file_path(@offer, item)
    assert_response :not_found
    post approve_owner_service_media_path(@offer, item)
    assert_response :not_found
    delete archive_owner_service_media_path(@offer, item)
    assert_response :not_found
    assert_nil item.reload.approved_at
    assert_nil item.archived_at
  end

  test "unapproved extensions, categories and missing files do not persist" do
    sign_in(@owner)
    %w[audio document].each do |kind|
      assert_no_difference("ServiceOfferingMediaItem.count") do
        post owner_service_media_items_path(@offer), params: {
          media: { media_kind: kind, caption: "Invalid file", file: upload_png }
        }
      end
      assert_redirected_to owner_service_path(@offer, anchor: "offering-media")
    end

    assert_no_difference("ServiceOfferingMediaItem.count") do
      post owner_service_media_items_path(@offer), params: {
        media: { media_kind: "image", caption: "No file" }
      }
    end

    assert_no_difference("ServiceOfferingMediaItem.count") do
      post owner_service_media_items_path(@offer), params: {
        media: { media_kind: "image", file: upload_png(original_filename: "evil.html") }
      }
    end
  end

  test "blob direct Rails routes are disabled, approved attachment is immutable" do
    sign_in(@owner)
    post owner_service_media_items_path(@offer), params: {
      media: { media_kind: "image", file: upload_png }
    }
    item = @offer.media_items.last
    blob = item.file.blob
    assert_raises(ActionController::RoutingError) do
      get "/rails/active_storage/blobs/redirect/#{blob.signed_id}/sample.png"
    end

    post approve_owner_service_media_path(@offer, item)
    assert_raises(ActiveRecord::RecordInvalid) { item.reload.update!(caption: "Tampered") }
    assert_equal false, item.reload.ai_access_allowed
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end

  def upload_png(original_filename: "sample.png")
    tmp = Tempfile.new(["owner-service-media-", ".png"])
    tmp.binmode
    tmp.write(Base64.strict_decode64(PNG_BASE64))
    tmp.flush
    @tempfiles << tmp
    Rack::Test::UploadedFile.new(tmp.path, "image/png", true, original_filename: original_filename)
  end
end
