require "test_helper"
require "tempfile"
require "base64"
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


  test "AI turns require explicit paid consent and enabled provider, notes stay free" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    login(@owner)
    payload = { request_id: SecureRandom.uuid, body: "Diagnose a fictional Rails 422.",
                intent: "ai", paid_consent: "0" }
    assert_no_difference("OwnerAiMessage.count") do
      assert_no_difference("AiSpendEntry.count") do
        post owner_ai_conversation_messages_path(thread), params: payload
        assert_response :unprocessable_entity
        assert_select "textarea#wa-thread-body", text: /Diagnose a fictional Rails 422/
        assert_select "input[name='request_id'][value=?]", payload.fetch(:request_id)
        assert_select "#wa-thread-paid-consent[checked]", count: 0
      end
    end
    OwnerIntelligence::Grok.stub(:enabled?, false) do
      assert_no_difference("OwnerAiMessage.count") do
        post owner_ai_conversation_messages_path(thread), params: payload.merge(paid_consent: "1")
        assert_response :unprocessable_entity
        assert_select "textarea#wa-thread-body", text: /Diagnose a fictional Rails 422/
        assert_select "input[name='request_id'][value=?]", payload.fetch(:request_id)
        assert_select "#wa-thread-paid-consent[checked]", count: 1
      end
    end
    assert_equal 0, thread.owner_ai_messages.count
  end

  test "consented mock Grok reply is one ledgered turn, a safe automatic title and bounded follow-up" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    profile = @workspace.professional_profile
    profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("chat-approved-public-v2"),
      approved_at: Time.current,
      payload: { "headline" => "Synthetic Rails owner",
                 "public_summary_draft" => "Approved shareable technical scope",
                 "private_summary" => "SECRET_PRIVATE_NOT_SENT_TO_PROVIDER" }
    )
    responses = [
      mock_chat_response("Rails 422 diagnosis",
                         "<script>alert('xss')</script> Inspect sanitized logs and Turbo CSRF flow."),
      mock_chat_response("Do not overwrite title",
                         "Check whether Turbo navigation affects CSRF token selection.",
                         ["Review one safe reproduction"])
    ]
    sent = []
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      sent << JSON.parse(request.body)
      responses.fetch(sent.length - 1)
    end
    previous_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictional-test-only-not-a-real-token"
    login(@owner)
    question1 = { request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
                  body: "My fictional Rails form sometimes responds 422 after Turbo navigation." }

    assert_difference("OwnerAiMessage.count", 2) do
      assert_difference("AiSpendEntry.count", 1) do
        OwnerIntelligence::Grok.stub(:enabled?, true) do
          IntakeAiQuota.stub(:reserve_call!, true) do
            Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
              post owner_ai_conversation_messages_path(thread), params: question1
            end
          end
        end
      end
    end
    assert_redirected_to owner_ai_conversation_path(thread)
    assert_equal "Rails 422 diagnosis", thread.reload.title
    assert_equal %w[owner assistant], thread.owner_ai_messages.in_order.pluck(:role)
    assert_equal %w[settled settled], thread.owner_ai_messages.in_order.pluck(:state)
    assistant = thread.owner_ai_messages.find_by!(role: "assistant")
    entry = assistant.ai_spend_entry
    assert_equal "settled", entry.status
    assert_equal OwnerAi::ConversationResponder::VERSION, entry.operation
    assert_equal 125_000, entry.charged_ticks
    assert_equal [], sent.first["tools"]
    assert_equal false, sent.first["store"]
    assert_equal "json_schema", sent.first.fetch("text").fetch("format").fetch("type")
    context = sent.first.fetch("input").last.fetch("content")
    assert_includes context, "Approved shareable technical scope"
    refute_includes context, "SECRET_PRIVATE_NOT_SENT_TO_PROVIDER"

    get owner_ai_conversation_path(thread)
    assert_response :success
    assert_select ".wa-threads__message-body script", count: 0
    assert_includes response.body, "&lt;script&gt;"
    assert_select ".wa-threads__message--owner", count: 1

    patch rename_owner_ai_conversation_path(thread), params: { title: "Manual Rails troubleshooting" }
    assert_redirected_to owner_ai_conversation_path(thread)
    question2 = { request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
                  body: "The fictional bug only happens after Turbo navigation. Refine the plan." }
    OwnerIntelligence::Grok.stub(:enabled?, true) do
      IntakeAiQuota.stub(:reserve_call!, true) do
        Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
          post owner_ai_conversation_messages_path(thread), params: question2
          assert_redirected_to owner_ai_conversation_path(thread)
          assert_no_difference("AiSpendEntry.count") do
            assert_no_difference("OwnerAiMessage.count") do
              post owner_ai_conversation_messages_path(thread), params: question2
            end
          end
        end
      end
    end
    assert_equal 2, sent.size
    assert_equal "Manual Rails troubleshooting", thread.reload.title
    followup = JSON.parse(sent.last.fetch("input").last.fetch("content"))
    assert_equal 2, followup.fetch("previous_turns").size
    assert_includes followup.fetch("previous_turns").last.fetch("text"), "Inspect sanitized logs"
    assert_equal 4, thread.owner_ai_messages.count
    assert_equal 2, AiSpendEntry.where(operation: OwnerAi::ConversationResponder::VERSION).count
  ensure
    previous_key.nil? ? ENV.delete("XAI_API_KEY") : ENV["XAI_API_KEY"] = previous_key
  end

  test "provider timeout is uncertain, persisted, and never retried for the same form" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    previous_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictional-test-only-not-a-real-token"
    login(@owner)
    payload = { request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
                body: "Explain why a fictional Rails request might time out." }
    calls = 0
    failing_provider = ->(*_args, **_kwargs, &_block) do
      calls += 1
      raise Net::ReadTimeout
    end
    OwnerIntelligence::Grok.stub(:enabled?, true) do
      IntakeAiQuota.stub(:reserve_call!, true) do
        Net::HTTP.stub(:start, failing_provider) do
          post owner_ai_conversation_messages_path(thread), params: payload
          assert_redirected_to owner_ai_conversation_path(thread)
          post owner_ai_conversation_messages_path(thread), params: payload
        end
      end
    end
    assert_equal 1, calls
    assert_equal 2, thread.owner_ai_messages.count
    assert_equal "uncertain", thread.owner_ai_messages.find_by!(role: "assistant").state
    entry = AiSpendEntry.find_by!(operation: OwnerAi::ConversationResponder::VERSION)
    assert_equal "uncertain", entry.status
    assert_no_difference("AiSpendEntry.count") do
      assert_no_difference("OwnerAiMessage.count") do
        OwnerIntelligence::Grok.stub(:enabled?, true) do
          post owner_ai_conversation_messages_path(thread), params: payload.merge(request_id: SecureRandom.uuid)
        end
      end
    end
    get owner_ai_conversation_path(thread)
    assert_response :success
    assert_select ".wa-threads__message-body", text: /Explain why/, count: 1
    assert_select ".wa-threads__message-body", text: /-/, count: 0
    assert_select ".wa-threads__message-meta", text: /uncertain|unknown|неизвестен/i
  ensure
    previous_key.nil? ? ENV.delete("XAI_API_KEY") : ENV["XAI_API_KEY"] = previous_key
  end

  test "budget exhaustion fails safely and archived or foreign threads never allow paid turns or rename" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    foreign = @foreign_workspace.owner_ai_conversations.create!(title: "Foreign")
    login(@owner)
    post owner_ai_conversation_messages_path(foreign), params: {
      body: "Fake owner AI call", request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1"
    }
    assert_response :not_found
    patch rename_owner_ai_conversation_path(foreign), params: { title: "Injected" }
    assert_response :not_found
    assert_equal "Foreign", foreign.reload.title

    OwnerIntelligence::Grok.stub(:enabled?, true) do
      AiSpendLedger.stub(:reserve!, ->(**_kwargs) { raise AiSpendLedger::LimitReached }) do
        post owner_ai_conversation_messages_path(thread), params: {
          request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
          body: "A fictional Rails question with an exhausted AI budget"
        }
      end
    end
    assert_equal 0, AiSpendEntry.where(operation: OwnerAi::ConversationResponder::VERSION).count
    assert_equal "failed", thread.owner_ai_messages.find_by!(role: "assistant").state
    post archive_owner_ai_conversation_path(thread)
    patch rename_owner_ai_conversation_path(thread), params: { title: "Not allowed" }
    assert_equal "archived", thread.reload.state
    refute_equal "Not allowed", thread.title

    delete sign_out_path
    login(@client)
    patch rename_owner_ai_conversation_path(thread), params: { title: "Client injection" }
    assert_redirected_to sign_in_path
  end


  test "Turbo frame provides inline navigation and no oversized empty-state panel" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    login(@owner)
    get owner_ai_conversation_path(thread), headers: { "Turbo-Frame" => "wa-thread-workspace" }
    assert_response :success
    assert_select "turbo-frame#wa-thread-workspace", count: 1
    assert_select ".wa-threads__empty", count: 0
    assert_select "form[enctype='multipart/form-data']", count: 1
    assert_select "input[type='file'][name='files[]']", count: 1
  end

  test "private PNG note is visible to owner only and bytes are guarded" do
    thread = @workspace.owner_ai_conversations.create!(title: "Screenshots")
    login(@owner)
    png = tiny_test_png_upload
    assert_difference("ActiveStorage::Attachment.count", 1) do
      post owner_ai_conversation_messages_path(thread), params: {
        request_id: SecureRandom.uuid, intent: "note",
        body: "Private test screenshot", files: [png]
      }
    end
    message = thread.owner_ai_messages.first
    attachment = message.files_attachments.first
    assert attachment
    get owner_ai_conversation_file_path(thread, message, attachment)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    get owner_ai_conversation_path(thread)
    assert_select ".wa-threads__file-link", count: 1

    delete sign_out_path
    login(@client)
    get owner_ai_conversation_file_path(thread, message, attachment)
    assert_redirected_to sign_in_path
    delete sign_out_path
    login(@foreign)
    get owner_ai_conversation_file_path(thread, message, attachment)
    assert_response :not_found
  ensure
    png&.tempfile&.close! rescue nil
  end

  test "consented image is sent to Grok in same turn, never as a public URL" do
    thread = @workspace.owner_ai_conversations.create!(title: "New conversation")
    fake_http = Object.new
    sent = []
    fake_http.define_singleton_method(:request) do |request|
      sent << JSON.parse(request.body)
      Struct.new(:code, :body).new("200", JSON.generate(
        status: "completed", output: [{
          type: "message", content: [{
            type: "output_text", text: JSON.generate(
              title: "Screenshot check", answer: "Only safe hypotheses.", suggested_actions: []
            )
          }]
        }], usage: { input_tokens: 160, output_tokens: 60,
                     total_tokens: 220, cost_in_usd_ticks: 126_000 }
      ))
    end
    png = tiny_test_png_upload
    previous_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictional-test-only-not-a-real-token"
    login(@owner)
    OwnerIntelligence::Grok.stub(:enabled?, true) do
      IntakeAiQuota.stub(:reserve_call!, true) do
        Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
          post owner_ai_conversation_messages_path(thread), params: {
            request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
            body: "Explain only what is visible in the synthetic PNG.", files: [png]
          }
        end
      end
    end
    assert_redirected_to owner_ai_conversation_path(thread)
    assert_equal 1, sent.size
    input = sent.first.fetch("input").last.fetch("content")
    assert_equal "input_text", input.first.fetch("type")
    assert_equal "input_image", input.last.fetch("type")
    assert_match(/\\Adata:image\\/png;base64,/, input.last.fetch("image_url"))
    assert_equal false, sent.first.fetch("store")
    assert_equal 1, thread.owner_ai_messages.find_by!(role: "owner").files.count
    assert_equal "settled", thread.owner_ai_messages.find_by!(role: "assistant").state
  ensure
    previous_key.nil? ? ENV.delete("XAI_API_KEY") : ENV["XAI_API_KEY"] = previous_key
    png&.tempfile&.close! rescue nil
  end

  test "reject disallowed file before creation or provider spend" do
    thread = @workspace.owner_ai_conversations.create!(title: "Unsafe file")
    login(@owner)
    temp = Tempfile.new(["attack", ".html"])
    temp.write("<script>alert(1)</script>")
    temp.flush
    upload = Rack::Test::UploadedFile.new(temp.path, "text/html", true,
                                           original_filename: "attack.html")
    assert_no_difference("OwnerAiMessage.count") do
      assert_no_difference("ActiveStorage::Attachment.count") do
        assert_no_difference("AiSpendEntry.count") do
          post owner_ai_conversation_messages_path(thread), params: {
            request_id: SecureRandom.uuid, intent: "ai", paid_consent: "1",
            body: "Please run this html", files: [upload]
          }
          assert_response :unprocessable_entity
          assert_select "textarea#wa-thread-body", text: /Please run this html/
        end
      end
    end
  ensure
    temp&.close! rescue nil
  end

  def tiny_test_png_upload
    png = Tempfile.new(["owner-chat-", ".png"])
    png.binmode
    png.write(Base64.strict_decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=="
    ))
    png.flush
    Rack::Test::UploadedFile.new(png.path, "image/png", true,
                                 original_filename: "synthetic.png")
  end

  def mock_chat_response(title, answer, actions = [])
    Struct.new(:code, :body).new("200", JSON.generate(
      status: "completed", id: "mock-chat-#{SecureRandom.hex(4)}",
      output: [{ type: "message", content: [{ type: "output_text", text: JSON.generate(
        title: title, answer: answer, suggested_actions: actions
      ) }] }],
      usage: { input_tokens: 140, output_tokens: 180, total_tokens: 320,
               cost_in_usd_ticks: 125_000 }
    ))
  end

  private

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
