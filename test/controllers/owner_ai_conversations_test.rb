require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiConversationsTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("c21b-owner-#{SecureRandom.hex(5)}@example.test")
    @foreign = make_test_owner("c21b-foreign-#{SecureRandom.hex(5)}@example.test")
    @client = make_test_client("c21b-client-#{SecureRandom.hex(5)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @foreign_workspace, = approved_profile_for(@foreign)
  end

  test "guest and client cannot list, create, or access owner threads" do
    thread = @workspace.owner_ai_conversations.create!(title: "OWNER_PRIVATE_ONLY")
    get owner_ai_conversations_path
    assert_redirected_to sign_in_path
    post owner_ai_conversations_path, params: { title: "forged" }
    assert_redirected_to sign_in_path
    get owner_ai_conversation_path(thread)
    assert_redirected_to sign_in_path

    login(@client)
    get owner_ai_conversations_path
    assert_redirected_to sign_in_path
    post owner_ai_conversations_path, params: { title: "forged" }
    assert_redirected_to sign_in_path
    get owner_ai_conversation_path(thread)
    assert_redirected_to sign_in_path
    post owner_ai_conversation_messages_path(thread), params: {
      body: "forged", request_id: SecureRandom.uuid
    }
    assert_redirected_to sign_in_path
    post archive_owner_ai_conversation_path(thread)
    assert_redirected_to sign_in_path
    assert_equal "active", thread.reload.state
    assert_equal 0, thread.owner_ai_messages.count
  end

  test "separate owners cannot enumerate, read, write or archive foreign threads" do
    foreign = @foreign_workspace.owner_ai_conversations.create!(title: "FOREIGN_PRIVATE_THREAD")
    login(@owner)
    get owner_ai_conversations_path
    assert_response :success
    assert_select "#owner-ai-conversations", text: /FOREIGN_PRIVATE_THREAD/, count: 0

    get owner_ai_conversation_path(foreign)
    assert_response :not_found
    post owner_ai_conversation_messages_path(foreign),
         params: { body: "forged", request_id: SecureRandom.uuid }
    assert_response :not_found
    post archive_owner_ai_conversation_path(foreign)
    assert_response :not_found
    assert_equal 0, foreign.owner_ai_messages.count
    assert_equal "active", foreign.reload.state
  end

  test "owner creates switches and reopens threads without paid spend" do
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      assert_difference("OwnerAiConversation.count", 2) do
        post owner_ai_conversations_path, params: { title: "First owner note" }
        assert_response :redirect
        post owner_ai_conversations_path, params: { title: "Second owner note" }
        assert_response :redirect
      end
    end
    first = @workspace.owner_ai_conversations.find_by!(title: "First owner note")
    second = @workspace.owner_ai_conversations.find_by!(title: "Second owner note")

    get owner_ai_conversation_path(first)
    assert_response :success
    assert_select ".wa-threads__item", text: /Second owner note/
    get owner_ai_conversation_path(second)
    assert_response :success
    assert_select ".wa-threads__item[aria-current='page']", count: 1
    delete sign_out_path
    login(@owner)
    get owner_ai_conversation_path(first)
    assert_response :success
  end

  test "owner saves escaped text once with idempotent request UUID and archives read-only" do
    thread = @workspace.owner_ai_conversations.create!(title: "Confidential journal")
    payload = { request_id: SecureRandom.uuid, body: "<script>alert('xss')</script> A private note" }
    login(@owner)

    assert_no_difference("AiSpendEntry.count") do
      assert_difference("OwnerAiMessage.count", 1) do
        post owner_ai_conversation_messages_path(thread), params: payload
      end
      assert_redirected_to owner_ai_conversation_path(thread)
      assert_no_difference("OwnerAiMessage.count") do
        post owner_ai_conversation_messages_path(thread), params: payload
      end
    end
    message = thread.owner_ai_messages.first
    assert_equal "owner", message.role
    assert_equal "draft", message.state
    assert_equal 1, message.sequence

    get owner_ai_conversation_path(thread)
    assert_response :success
    assert_select ".wa-threads__message-body", text: /A private note/
    assert_select ".wa-threads__message-body script", count: 0
    assert_includes response.body, "&lt;script&gt;"

    post archive_owner_ai_conversation_path(thread)
    assert_redirected_to owner_ai_conversation_path(thread)
    assert thread.reload.archived?
    get owner_ai_conversation_path(thread)
    assert_response :success
    assert_select ".wa-threads__message-body", text: /A private note/
    assert_select "form[action=?]", owner_ai_conversation_messages_path(thread), count: 0

    assert_no_difference("OwnerAiMessage.count") do
      post owner_ai_conversation_messages_path(thread), params: {
        request_id: SecureRandom.uuid, body: "Attempt after archive"
      }
    end
    assert_redirected_to owner_ai_conversation_path(thread)
  end

  test "invalid message length uuid and conflicting replay do not append rows" do
    thread = @workspace.owner_ai_conversations.create!(title: "Validation notes")
    login(@owner)
    assert_no_difference("OwnerAiMessage.count") do
      post owner_ai_conversation_messages_path(thread),
           params: { request_id: SecureRandom.uuid, body: " " }
      post owner_ai_conversation_messages_path(thread),
           params: { request_id: SecureRandom.uuid, body: "a" * 1201 }
      post owner_ai_conversation_messages_path(thread),
           params: { request_id: "not-a-uuid", body: "Valid text" }
    end
    uuid = SecureRandom.uuid
    post owner_ai_conversation_messages_path(thread),
         params: { request_id: uuid, body: "Original note" }
    assert_equal 1, thread.owner_ai_messages.count
    assert_no_difference("OwnerAiMessage.count") do
      post owner_ai_conversation_messages_path(thread),
           params: { request_id: uuid, body: "Different note" }
    end
    assert_equal "Original note", thread.owner_ai_messages.first.body
  end

  private

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
