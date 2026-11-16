require "test_helper"
require "digest"
require "securerandom"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiConversationTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("owner-conversation-a@example.test")
    @foreign_owner = make_test_owner("owner-conversation-b@example.test")
    @client = make_test_client("client-conversation@example.test")
    @workspace, @profile, = approved_profile_for(@owner)
    @foreign_workspace, @foreign_profile, = approved_profile_for(@foreign_owner)
  end

  def create_thread(workspace = @workspace, title: "Synthetic private discussion")
    workspace.owner_ai_conversations.create!(
      title: title, retention_expires_at: 7.days.from_now
    )
  end

  test "owner-only conversation scope never exposes another owner or a client" do
    mine = create_thread
    foreign = create_thread(@foreign_workspace, title: "Foreign private discussion")

    assert_equal [mine.id], OwnerAi::ConversationAccess.for_user(@owner).pluck(:id)
    assert_equal [foreign.id], OwnerAi::ConversationAccess.for_user(@foreign_owner).pluck(:id)
    assert_equal [], OwnerAi::ConversationAccess.for_user(@client).pluck(:id)
    assert_equal [], OwnerAi::ConversationAccess.for_user(nil).pluck(:id)
    assert_raises(ActiveRecord::RecordNotFound) do
      OwnerAi::ConversationAccess.for_user(@foreign_owner).find(mine.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      OwnerAi::ConversationAccess.for_user(@owner).find(foreign.id)
    end
    assert_no_difference("AiSpendEntry.count") { assert mine.persisted? }
  end

  test "repeated owner submission is idempotent and messages have ordered sequences" do
    conversation = create_thread
    id = SecureRandom.uuid
    assert_difference("OwnerAiMessage.count", 1) do
      first = conversation.append_owner_message!(body: "  Synthetic bug-fix request  ", request_id: id)
      assert_equal "Synthetic bug-fix request", first.body
      assert_equal 1, first.sequence
    end
    first_id = conversation.owner_ai_messages.first.id
    assert_no_difference("OwnerAiMessage.count") do
      assert_equal first_id, conversation.append_owner_message!(
        body: "Synthetic bug-fix request", request_id: id
      ).id
    end
    assert_raises(OwnerAiConversation::RequestConflict) do
      conversation.append_owner_message!(body: "Different scope", request_id: id)
    end
    second = conversation.append_owner_message!(body: "Follow-up with constraints", request_id: SecureRandom.uuid)
    assert_equal [1, 2], conversation.owner_ai_messages.order(:sequence).pluck(:sequence)
    assert_equal "draft", second.state
    assert_equal "owner", second.role
  end

  test "archived or retention-expired conversation refuses new messages and existing rows are immutable" do
    conversation = create_thread
    row = conversation.append_owner_message!(body: "Synthetic private prompt", request_id: SecureRandom.uuid)

    assert_not row.update(body: "silent edit")
    assert_equal "Synthetic private prompt", row.reload.body
    assert_not row.destroy
    assert row.persisted?

    conversation.archive!
    assert_equal "archived", conversation.reload.state
    assert_raises(OwnerAiConversation::Closed) do
      conversation.append_owner_message!(body: "Unapproved continuation", request_id: SecureRandom.uuid)
    end

    expired = create_thread
    expired.update!(retention_expires_at: 2.minutes.ago)
    assert_raises(OwnerAiConversation::Closed) do
      expired.append_owner_message!(body: "Expired prompt", request_id: SecureRandom.uuid)
    end
    assert_raises(ActiveRecord::DeleteRestrictionError) { conversation.destroy! }
    assert conversation.reload.persisted?
  end

  test "cannot attach foreign parent message or foreign and client cost ledgers" do
    mine = create_thread
    foreign = create_thread(@foreign_workspace)
    foreign_parent = foreign.append_owner_message!(body: "Foreign parent", request_id: SecureRandom.uuid)
    msg = mine.owner_ai_messages.build(
      role: "owner", state: "draft", sequence: 1, request_id: SecureRandom.uuid,
      body: "Synthetic owner message", parent_message: foreign_parent
    )
    assert_not msg.valid?
    assert_includes msg.errors.attribute_names, :parent_message

    foreign_ledger = create_ledger(@foreign_profile, "foreign-ledger")
    other = mine.owner_ai_messages.build(
      role: "assistant", state: "settled", sequence: 2, request_id: SecureRandom.uuid,
      body: "Synthetic external AI text", ai_spend_entry: foreign_ledger
    )
    assert_not other.valid?
    assert_includes other.errors.attribute_names, :ai_spend_entry

    own_ledger = create_ledger(@profile, "owner-ledger")
    own = mine.owner_ai_messages.build(
      role: "assistant", state: "settled", sequence: 2, request_id: SecureRandom.uuid,
      body: "Synthetic reviewed AI draft", ai_spend_entry: own_ledger
    )
    assert own.valid?
  end

  test "rejects unbounded body and unapproved operation or settlement without a ledger" do
    conversation = create_thread
    oversized = conversation.owner_ai_messages.build(
      role: "owner", state: "draft", sequence: 1, request_id: SecureRandom.uuid, body: "A" * 1_201
    )
    assert_not oversized.valid?
    assert_includes oversized.errors.attribute_names, :body

    forged = conversation.owner_ai_messages.build(
      role: "assistant", state: "settled", sequence: 1,
      request_id: SecureRandom.uuid, body: "Synthetic answer",
      operation: "run_shell_command"
    )
    assert_not forged.valid?
    assert_includes forged.errors.attribute_names, :operation
    assert_includes forged.errors.attribute_names, :ai_spend_entry

    invalid_date = @workspace.owner_ai_conversations.build(
      title: "Invalid retention", retention_expires_at: 2.days.ago
    )
    assert_not invalid_date.valid?
  end

  private

  def create_ledger(profile, suffix)
    AiSpendEntry.create!(
      professional_profile: profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("#{profile.id}/#{suffix}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: { "synthetic_test" => true }, resolved_at: Time.current
    )
  end
end
