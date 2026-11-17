require "test_helper"
require "tempfile"
require "base64"

class ClientAvatarsTest < ActionDispatch::IntegrationTest
  PASSWORD = "client-avatar-test-secret-2026".freeze
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==".freeze

  setup do
    @client = make_client("client-avatar-primary@example.test")
    @other_client = make_client("client-avatar-other@example.test")
    @owner = User.create!(email: "client-avatar-owner@example.test", role: "owner", password: PASSWORD)
    @tmpfiles = []
  end

  teardown do
    @tmpfiles.each { |file| file.close! rescue nil }
  end

  test "verified client uploads own private avatar and keeps older versions" do
    login(@client)
    get client_cabinet_path
    assert_response :success
    assert_select "#client-avatar-form"
    assert_select "details.ws-avatar-edit summary.ws-avatar-edit-trigger[aria-label]"
    assert_select "#client-avatar[data-controller=wa-avatar-editor]"

    assert_difference("ActiveStorage::Attachment.count", 1) do
      post client_avatars_path, params: { avatar: { file: image_upload } }
    end
    assert_redirected_to client_cabinet_path(anchor: "client-avatar")
    avatar = @client.client_avatars_attachments.last
    get client_avatar_file_path(avatar)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    get client_cabinet_path
    assert_select "img.ws-account-avatar[src=?]", client_avatar_file_path(avatar)
    assert_select "header.app-header img.ws-nav-avatar[src=?]", client_avatar_file_path(avatar)
    assert_difference("ActiveStorage::Attachment.count", 1) do
      post client_avatars_path, params: { avatar: { file: image_upload } }
    end
    assert_equal 2, @client.client_avatars_attachments.count
    assert_equal 0, @client.owner_avatars_attachments.count
  end

  test "guest, owner and foreign verified client cannot reach another client avatar" do
    login(@client)
    post client_avatars_path, params: { avatar: { file: image_upload } }
    avatar = @client.client_avatars_attachments.last
    delete sign_out_path

    get client_avatar_file_path(avatar)
    assert_redirected_to sign_in_path
    post client_avatars_path, params: { avatar: { file: image_upload } }
    assert_redirected_to sign_in_path

    login(@owner)
    get client_avatar_file_path(avatar)
    assert_redirected_to sign_in_path
    post client_avatars_path, params: { avatar: { file: image_upload } }
    assert_redirected_to sign_in_path
    delete sign_out_path

    login(@other_client)
    get client_avatar_file_path(avatar)
    assert_response :not_found
    get client_cabinet_path
    assert_select "img.ws-account-avatar[src=?]", client_avatar_file_path(avatar), count: 0
    assert_equal 0, @other_client.client_avatars_attachments.count
  end

  test "bad extension, MIME and oversized images do not persist" do
    login(@client)
    assert_no_difference("ActiveStorage::Attachment.count") do
      post client_avatars_path, params: { avatar: { file: image_upload(filename: "payload.html") } }
      post client_avatars_path, params: { avatar: { file: image_upload(mime: "text/plain") } }
      post client_avatars_path, params: { avatar: { file: image_upload(oversize: true) } }
    end
    assert_equal 0, @client.client_avatars_attachments.count
  end

  private

  def make_client(email)
    User.create!(email: email, role: "client", password: PASSWORD,
                 email_verified_at: Time.current, signup_consent_at: Time.current,
                 signup_policy_version: "client-avatar-test")
  end

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "owner" ? workspace_path : client_home_path)
  end

  def image_upload(filename: "avatar.png", mime: "image/png", oversize: false)
    tmp = Tempfile.new(["client-avatar-", ".png"])
    tmp.binmode
    tmp.write(Base64.strict_decode64(PNG))
    tmp.write("a" * (3.megabytes + 1)) if oversize
    tmp.flush
    @tmpfiles << tmp
    Rack::Test::UploadedFile.new(tmp.path, mime, true, original_filename: filename)
  end
end
