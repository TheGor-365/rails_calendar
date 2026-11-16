require "test_helper"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiAssistantTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("ai-assistant-owner@example.test")
    @other = make_test_owner("ai-assistant-foreign@example.test")
    @client = make_test_client("ai-assistant-client@example.test")
    @workspace, @profile, = approved_profile_for(@owner)
    @foreign_workspace, @foreign_profile, = approved_profile_for(@other)
  end

  test "owner assistant and floating launcher are access restricted and GET is free" do
    assert_no_difference("AiSpendEntry.count") do
      get owner_ai_assistant_path
      assert_redirected_to sign_in_path

      login(@client)
      get owner_ai_assistant_path
      assert_redirected_to sign_in_path
      get owner_cabinet_path
      assert_redirected_to sign_in_path
      delete sign_out_path

      login(@owner)
      get owner_ai_assistant_path
      assert_response :success
      assert_select "#owner-ai-assistant"
      assert_select "#owner-ai-dock"
      assert_select "summary[aria-label]"
      assert_select "form[action=?]", create_owner_ai_draft_path, count: 2
      get owner_cabinet_path
      assert_response :success
      assert_select "#owner-ai-dock"
    end
  end

  test "invalid operation or missing explicit paid consent cannot reserve provider spend" do
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post create_owner_ai_draft_path, params: {
        operation: "delete_everything", brief: "Do something destructive", paid_consent: "1"
      }
      assert_redirected_to owner_ai_assistant_path
      post create_owner_ai_draft_path, params: {
        operation: "service_copy", brief: "Draft synthetic service copy", paid_consent: "0"
      }
      assert_redirected_to owner_ai_assistant_path(operation: "service_copy")
    end
  end

  test "only the matching owner can see a previously stored draft; output is escaped" do
    entry = AiSpendEntry.create!(
      professional_profile: @profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("owner-assistant-#{@profile.id}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => "Synthetic test result",
        "draft" => "<script>alert('bad')</script> A fictional service draft.",
        "questions" => ["What should the form collect?"],
        "cautions" => ["No promised release dates"],
        "next_step" => "Owner reviews before publishing",
        "purpose" => "service_copy", "profile_version" => 1
      }, resolved_at: Time.current
    )
    login(@other)
    get owner_ai_assistant_path(entry_id: entry.id)
    assert_response :success
    assert_select ".wa-ai-page__draft", count: 0
    delete sign_out_path

    login(@owner)
    get owner_ai_assistant_path(entry_id: entry.id)
    assert_response :success
    assert_select ".wa-ai-page__draft", text: /fictional service draft/
    assert_select "script", text: /alert\('bad'\)/, count: 0
    assert_select "form[action=?]", create_owner_ai_draft_path, count: 2
  end

  test "operation registry rejects forged keys and output validation rejects malformed schema" do
    assert_equal 4, OwnerAi::OperationRegistry.keys.size
    assert_nil OwnerAi::OperationRegistry.fetch("system_command")
    composer = OwnerAi::Composer.new(workspace: @workspace)
    safe = {
      "heading" => "A synthetic private service",
      "draft" => "A bounded fictional service description with no promises.",
      "questions" => [], "cautions" => [], "next_step" => "Owner must review."
    }
    assert_nil composer.send(:validate_result!, safe)
    assert_raises(OwnerAi::Composer::Unavailable) do
      composer.send(:validate_result!, safe.merge("tool_call" => "approve"))
    end
    assert_raises(OwnerAi::Composer::Unavailable) do
      composer.send(:validate_result!, safe.merge("draft" => "too short"))
    end
  end

  private

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
