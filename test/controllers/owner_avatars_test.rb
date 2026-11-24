require "test_helper"
require "tempfile"
require "base64"

class OwnerAvatarsTest < ActionDispatch::IntegrationTest
  PASSWORD = "owner-avatar-test-secret-2026".freeze
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==".freeze

  setup do
    @owner = User.create!(email: "avatar-owner@example.test", role: "owner", password: PASSWORD)
    @other = User.create!(email: "avatar-other@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(
      email: "avatar-client@example.test", role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "avatar-fixture"
    )
    @tmpfiles = []
  end

  teardown do
    @tmpfiles.each { |file| file.close! rescue nil }
  end

  test "owner uploads private avatar and keeps earlier versions" do
    login(@owner)
    get owner_cabinet_path
    assert_select "#owner-avatar-form"
    assert_select ".ws-account-avatar-panel", count: 0
    assert_select "details.ws-avatar-edit summary.ws-avatar-edit-trigger[aria-label]"
    assert_select "[data-controller~='wa-avatar-editor']"
    assert_select "[data-controller~='wa-private-image']"
    assert_no_difference("User.count") do
      post owner_avatars_path, params: { avatar: { file: image_upload } }
    end
    assert_redirected_to owner_cabinet_path(anchor: "owner-avatar")
    attachment = @owner.owner_avatars_attachments.last
    assert attachment
    get owner_avatar_file_path(attachment)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"

    get owner_cabinet_path
    assert_select "img.ws-account-avatar[src=?]", owner_avatar_file_path(attachment)
    get workspace_path
    assert_select "img.ws-nav-avatar[src=?]", owner_avatar_file_path(attachment)

    assert_difference("ActiveStorage::Attachment.count", 1) do
      post owner_avatars_path, params: { avatar: { file: image_upload } }
    end
    assert_equal 2, @owner.owner_avatars_attachments.count
    assert_equal 0, ServiceOfferingMediaItem.count
  end

  test "guest, client and foreign owner cannot read or change avatar" do
    login(@owner)
    post owner_avatars_path, params: { avatar: { file: image_upload } }
    attachment = @owner.owner_avatars_attachments.last
    delete sign_out_path

    get owner_avatar_file_path(attachment)
    assert_redirected_to sign_in_path
    login(@client)
    get owner_avatar_file_path(attachment)
    assert_redirected_to sign_in_path
    post owner_avatars_path, params: { avatar: { file: image_upload } }
    assert_redirected_to sign_in_path
    delete sign_out_path

    login(@other)
    get owner_avatar_file_path(attachment)
    assert_response :not_found
    assert_equal 0, @other.owner_avatars_attachments.count
  end

  test "missing private avatar file returns 404 instead of raising 500" do
    login(@owner)
    post owner_avatars_path, params: { avatar: { file: image_upload } }
    attachment = @owner.owner_avatars_attachments.last
    attachment.blob.service.delete(attachment.blob.key)

    get owner_avatar_file_path(attachment)
    assert_response :not_found
    assert_equal 1, @owner.owner_avatars_attachments.count

    get owner_cabinet_path
    assert_response :success
    assert_select ".ws-account-avatar[data-wa-private-image-target=image]", count: 1
    assert_select ".ws-account-avatar-placeholder[data-wa-private-image-target=fallback][hidden]", count: 1

    get workspace_path
    assert_response :success
    assert_select ".ws-nav-avatar-link[data-controller=wa-private-image]", count: 1
    assert_select ".ws-nav-avatar-placeholder[data-wa-private-image-target=fallback][hidden]", count: 1
  end

  test "wrong file extension and MIME are rejected" do
    login(@owner)
    post owner_avatars_path, params: { avatar: { file: image_upload(filename: "payload.html") } }
    assert_redirected_to owner_cabinet_path(anchor: "owner-avatar")
    assert_equal 0, @owner.owner_avatars_attachments.count
  end

  private

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end

  def image_upload(filename: "avatar.png")
    tmp = Tempfile.new(["avatar-", ".png"])
    tmp.binmode
    tmp.write(Base64.strict_decode64(PNG))
    tmp.flush
    @tmpfiles << tmp
    Rack::Test::UploadedFile.new(tmp.path, "image/png", true, original_filename: filename)
  end
end
