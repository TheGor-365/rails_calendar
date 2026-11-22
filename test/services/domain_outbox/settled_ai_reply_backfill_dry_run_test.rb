require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxSettledAiReplyBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("ai-dry-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("ai-dry-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("ai-dry-client-#{SecureRandom.hex(6)}@example.test")
    @empty_owner = make_test_owner("ai-dry-empty-#{SecureRandom.hex(6)}@example.test")
    @workspace, @profile, = approved_profile_for(@owner)
    @other_workspace, @other_profile, = approved_profile_for(@other)
    @conversation = @workspace.owner_ai_conversations.create!(title: "Synthetic AI audit")
    @other_conversation = @other_workspace.owner_ai_conversations.create!(title: "Other tenant")

    @complete = make_reply(sequence: 1)
    @projection_only = make_reply(sequence: 2)
    @envelope_only = make_reply(sequence: 3)
    @missing_both = make_reply(sequence: 4)
    @foreign = make_reply(sequence: 1, conversation: @other_conversation, profile: @other_profile)

    # Only synthetic ephemeral test-DB fixtures are damaged.
    envelope_for(@projection_only).delete_all
    event_for(@envelope_only).delete_all
    envelope_for(@missing_both).delete_all
    event_for(@missing_both).delete_all
  end

  def make_ledger(profile: @profile, operation: OwnerAi::ConversationResponder::VERSION,
                  status: "settled")
    AiSpendEntry.create!(
      professional_profile: profile, operation: operation, model: "synthetic-no-provider",
      request_digest: Digest::SHA256.hexdigest(SecureRandom.uuid),
      status: status, reserved_ticks: 0, charged_ticks: status == "settled" ? 0 : nil,
      resolved_at: status == "settled" ? Time.current : nil
    )
  end

  def make_reply(sequence:, conversation: @conversation, profile: @profile,
                 role: "assistant", state: "settled", ledger: nil)
    entry = ledger || (role == "assistant" && state == "settled" ? make_ledger(profile: profile) : nil)
    conversation.owner_ai_messages.create!(
      sequence: sequence, role: role, state: state,
      body: "Fictional private text #{SecureRandom.hex(8)}",
      ai_spend_entry: entry
    )
  end

  def key(message)
    "OwnerAiMessage:#{message.id}:ai_reply_saved"
  end

  def event_for(message)
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key(message))
  end

  def envelope_for(message)
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "OwnerAiMessage", source_id: message.id)
  end

  def preview(owner: @owner, limit: 25, cursor: nil)
    DomainOutbox::SettledAiReplyBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7f four projection states and manual-review ambiguity are read-only" do
    assert_no_difference([
      "OwnerAiMessage.count", "AiSpendEntry.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "OwnerOutboxReplayRun.count"
    ]) do
      assert_equal({
        source_type: "OwnerAiMessage", inspected: 4,
        already_indexed: 1, projection_only: 1, envelope_only: 1,
        missing_both: 1, inconsistent_records: 0,
        ineligible_sources: 0, unexpected_artifacts: 0,
        manual_review_required: 1,
        has_more: false, scan_budget_exhausted: false, next_cursor: nil
      }, preview)
      assert_equal 1, preview(owner: @other)[:already_indexed]
      assert_equal 1, preview(owner: @other)[:inspected]
      assert_not_includes preview.to_json, @complete.body
      assert_not preview.key?(:source_id)
      assert_not preview.key?(:ledger_id)
      assert_equal preview, preview
    end
  end

  test "C2.3b7f post-settlement body edit never causes false timestamp mismatch" do
    original = envelope_for(@complete).pick(:occurred_at)
    assert_equal original.to_i, event_for(@complete).pick(:occurred_at).to_i
    travel_to(15.minutes.from_now) do
      assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count"]) do
        @complete.update!(body: "Edited later without new settlement event")
      end
      assert_operator @complete.reload.updated_at, :>, original
      result = preview
      assert_equal 1, result[:already_indexed]
      assert_equal 0, result[:inconsistent_records]
    end
  end

  test "C2.3b7f invalid status, role, ledger and foreign ledger are ineligible" do
    make_reply(sequence: 5, role: "owner", state: "settled")
    make_reply(sequence: 6, state: "pending")
    make_reply(sequence: 7, state: "failed")
    make_reply(sequence: 8, state: "uncertain")
    foreign_ledger = make_ledger(profile: @other_profile)
    wrong_ledger = make_reply(sequence: 9)
    wrong_ledger.update_columns(ai_spend_entry_id: foreign_ledger.id)
    wrong_operation = make_reply(sequence: 10)
    wrong_operation.ai_spend_entry.update_columns(operation: "client_ai_operation")
    uncertain_ledger = make_reply(sequence: 11)
    uncertain_ledger.ai_spend_entry.update_columns(status: "uncertain")
    missing_charge = make_reply(sequence: 12)
    missing_charge.ai_spend_entry.update_columns(charged_ticks: nil)
    result = preview
    assert_equal 12, result[:inspected]
    assert_equal 8, result[:ineligible_sources]
    assert_equal 1, result[:already_indexed]
    assert_equal 1, result[:projection_only]
    assert_equal 1, result[:envelope_only]
    assert_equal 1, result[:missing_both]
    assert_equal 1, result[:manual_review_required]
  end

  test "C2.3b7f envelope version drift and activity timestamp/metadata drift fail closed" do
    envelope_for(@complete).update_all(source_version: 99)
    event_for(@projection_only).update_all(occurred_at: 1.day.ago)
    envelope_for(@envelope_only).update_all(occurred_at: 1.day.ago)
    result = preview
    assert_equal 3, result[:inconsistent_records]
    assert_equal 3, result[:manual_review_required] - result[:missing_both]
    assert_equal 0, result[:already_indexed]
    assert_equal 0, result[:projection_only]
    assert_equal 0, result[:envelope_only]

    event_for(@projection_only).update_all(occurred_at: @projection_only.created_at,
      metadata: { "version" => 2 })
    assert_operator preview[:inconsistent_records], :>=, 3
  end

  test "C2.3b7f contradictory artifacts are not treated as canonical activity" do
    # A conflicting kind violates normal validations. Corrupt ONLY the
    # synthetic test row via direct column update to simulate historical drift.
    extra = DomainOutboxEvent.create!(
      workspace: @workspace, source_type: "OwnerAiMessage",
      source_id: @complete.id, source_version: @complete.sequence + 1,
      kind: "ai_reply_saved", occurred_at: @complete.created_at,
      state: "pending", attempts: 0
    )
    extra.update_columns(kind: "unrelated_kind")
    result = preview
    assert_equal 1, result[:unexpected_artifacts]
    assert_equal 1, result[:inconsistent_records]
    assert_equal 0, result[:already_indexed]
  end

  test "C2.3b7f foreign or unverified actors, invalid limit and cursor are rejected" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { preview(owner: actor) }
    end
    [0, -1, 26, 250, "5", nil, 1.5].each do |bad|
      assert_raises(ArgumentError) { preview(limit: bad) }
    end
    ["", "bad-cursor", "x" * 2049, [], 1].each do |bad|
      assert_raises(ArgumentError) { preview(cursor: bad) }
    end
  end

  test "C2.3b7f encrypted cursor is owner- and family-bound" do
    first = preview(limit: 2)
    assert_equal 2, first[:inspected]
    assert first[:has_more]
    assert_kind_of String, first[:next_cursor]
    assert_operator first[:next_cursor].bytesize, :<=, 2048

    second = preview(limit: 2, cursor: first[:next_cursor])
    assert_equal 2, second[:inspected]
    assert_nil second[:next_cursor]
    assert_equal 1, second[:envelope_only]
    assert_equal 1, second[:missing_both]
    assert_equal 1, second[:manual_review_required]

    assert_raises(ArgumentError) { preview(owner: @other, limit: 2, cursor: first[:next_cursor]) }
    assert_raises(ArgumentError) { preview(limit: 2, cursor: first[:next_cursor].reverse) }
    other = DomainOutbox::BackfillDryRun.send(:encryptor).encrypt_and_sign(
      {
        "owner_user_id" => @owner.id, "workspace_id" => @workspace.id,
        "source_type" => "ProjectIntake", "ceiling_id" => 3,
        "after_id" => 1, "scanned" => 1
      },
      purpose: DomainOutbox::BackfillDryRun::CURSOR_PURPOSE,
      expires_in: 15.minutes
    )
    assert_raises(ArgumentError) { preview(limit: 2, cursor: other) }
  end

  test "C2.3b7f cursor budget of 250 sources stops without renewal" do
    251.times do |i|
      make_reply(sequence: 10 + i, state: "pending")
    end
    first = preview(limit: 25)
    assert_equal 25, first[:inspected]
    assert_equal true, first[:has_more]
    cursor = first[:next_cursor]
    total = first[:inspected]
    9.times do
      page = preview(limit: 25, cursor: cursor)
      total += page[:inspected]
      cursor = page[:next_cursor]
      if total == 250
        assert_equal true, page[:has_more]
        assert_equal true, page[:scan_budget_exhausted]
        assert_nil cursor
      end
    end
    assert_equal 250, total
  end

  test "C2.3b7f initial MAX-id ceiling excludes later records" do
    first = preview(limit: 2)
    make_reply(sequence: 80, state: "pending")
    second = preview(limit: 2, cursor: first[:next_cursor])
    assert_equal 2, second[:inspected]
    assert_nil second[:next_cursor]
    assert_equal 0, second[:ineligible_sources]
  end
end
