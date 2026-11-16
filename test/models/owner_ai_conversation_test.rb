require "test_helper"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiConversationTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("c21a-owner-#{SecureRandom.hex(5)}@example.test")
    @foreign = make_test_owner("c21a-foreign-#{SecureRandom.hex(5)}@example.test")
    @workspace, @profile, = approved_profile_for(@owner)
    @foreign_workspace, = approved_profile_for(@foreign)
    @conversation = @workspace.owner_ai_conversations.create!(title: "Fictional private dialogue")
  end

  test "owner workspace scope never finds foreign conversations" do
    foreign = @foreign_workspace.owner_ai_conversations.create!(title: "Foreign private data")
    assert_equal [@conversation], @workspace.owner_ai_conversations.to_a
    assert_nil @workspace.owner_ai_conversations.find_by(id: foreign.id)
    assert_equal foreign, @foreign_workspace.owner_ai_conversations.find_by(id: foreign.id)
    assert_equal "active", @conversation.state
  end

  test "archived conversation rejects new messages and cannot be deleted with history" do
    msg = @conversation.owner_ai_messages.create!(
      role: "owner", state: "draft", sequence: 1, body: "Fictional scoped request"
    )
    @conversation.archive!
    assert_equal "archived", @conversation.reload.state
    assert @conversation.archived_at.present?
    assert_no_difference("OwnerAiMessage.count") do
      next_msg = @conversation.owner_ai_messages.new(
        role: "owner", sequence: 2, body: "Rejected write after archive"
      )
      assert_not next_msg.valid?
      assert_includes next_msg.errors.attribute_names, :owner_ai_conversation
    end
    assert_raises(ActiveRecord::DeleteRestrictionError) { @conversation.destroy! }
    assert_equal msg, @conversation.owner_ai_messages.first
  end

  test "owner message requires bounded body and unique scoped sequence" do
    first = @conversation.owner_ai_messages.create!(
      role: "owner", sequence: 1, state: "draft", body: "One concise private request"
    )
    assert first.request_id.present?
    assert_not @conversation.owner_ai_messages.new(
      role: "owner", sequence: 1, body: "Duplicate sequence"
    ).valid?
    assert_not @conversation.owner_ai_messages.new(
      role: "owner", sequence: 2, body: "x" * 1201
    ).valid?
    assert_not @conversation.owner_ai_messages.new(
      role: "system", sequence: 2, body: "Prompt injection attempt"
    ).valid?
    assert_not @conversation.owner_ai_messages.new(
      role: "owner", sequence: 2, body: "<b>still plain text</b>", operation: "shell_exec"
    ).valid?
    assert_not @conversation.owner_ai_messages.new(
      role: "assistant", state: "settled", sequence: 2, body: "No paid ledger"
    ).valid?
  end

  test "cross-conversation parent and foreign owner provider ledger are rejected" do
    other = @foreign_workspace.owner_ai_conversations.create!(title: "Other owner")
    ancestor = other.owner_ai_messages.create!(role: "owner", sequence: 1, body: "Foreign prompt")
    invalid = @conversation.owner_ai_messages.new(
      role: "owner", sequence: 1, body: "Do not import", parent_message: ancestor
    )
    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :parent_message

    foreign_profile = @foreign_workspace.professional_profile
    foreign_ledger = AiSpendEntry.create!(
      professional_profile: foreign_profile,
      operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest(SecureRandom.uuid),
      status: "settled", reserved_ticks: 5000, charged_ticks: 5000,
      result: {}, resolved_at: Time.current
    )
    response = @conversation.owner_ai_messages.new(
      role: "assistant", state: "settled", sequence: 1,
      body: "Synthetic generated text", ai_spend_entry: foreign_ledger
    )
    assert_not response.valid?
    assert_includes response.errors.attribute_names, :ai_spend_entry
  end

  test "real owner composer ledger may be linked after settlement without model call" do
    ledger = AiSpendEntry.create!(
      professional_profile: @profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest(SecureRandom.uuid),
      status: "settled", reserved_ticks: 1000, charged_ticks: 1000,
      result: { "purpose" => "service_copy" }, resolved_at: Time.current
    )
    msg = @conversation.owner_ai_messages.create!(
      role: "assistant", state: "settled", sequence: 1,
      body: "Fictional approved draft only", operation: "service_copy",
      ai_spend_entry: ledger, approved_profile_version: 1
    )
    assert_equal ledger, msg.reload.ai_spend_entry
    assert_equal @conversation, msg.owner_ai_conversation
  end
end
