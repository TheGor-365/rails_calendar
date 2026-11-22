require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxOperatorRequestIntentTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-intent-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-intent-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-intent-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @empty_owner = make_test_owner("outbox-intent-empty-#{SecureRandom.hex(6)}@example.test")
    @session = {}
    @now = Time.zone.parse("2026-11-22 16:00:00")
  end

  def prepare(owner: @owner, limit: 5, now: @now)
    DomainOutbox::OperatorRequestIntent.prepare!(
      session: @session, owner: owner, limit: limit, now: now
    )
  end

  def verify(token:, owner: @owner, limit: "5", confirmation: "REPLAY 5", now: @now)
    DomainOutbox::OperatorRequestIntent.verify!(
      session: @session, owner: owner, request_token: token,
      limit: limit, confirmation: confirmation, now: now
    )
  end

  test "C2.3b6b2.4b server intent binds owner workspace, exact limit and stable duplicate" do
    assert_no_difference([
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      token = prepare
      assert_match(/\A[0-9a-f]{64}\z/, token)
      assert_equal token, @session.fetch(DomainOutbox::OperatorRequestIntent::SESSION_KEY).fetch("token")
      first = verify(token: token)
      duplicate = verify(token: token, now: @now + 1.minute)
      assert_equal @workspace, first.fetch(:workspace)
      assert_equal 5, first.fetch(:limit)
      assert_equal token, first.fetch(:request_token)
      assert_equal first, duplicate
      assert_raises(ArgumentError) do
        verify(token: token, limit: "10", confirmation: "REPLAY 10")
      end
    end
  end

  test "C2.3b6b2.4b rejects unassigned, client, guest and cross-owner reuse" do
    [nil, @client, @empty_owner].each do |actor|
      assert_raises(ArgumentError) { prepare(owner: actor) }
    end
    token = prepare
    assert_raises(ArgumentError) { verify(token: token, owner: @other) }
    assert_raises(ArgumentError) { verify(token: token, owner: @client) }
    assert_raises(ArgumentError) { verify(token: token, owner: nil) }
    assert_equal @workspace, verify(token: token).fetch(:workspace)
  end

  test "C2.3b6b2.4b requires exact token with TTL and refuses clock skew" do
    token = prepare
    [nil, 123, "short", "Z" * 64, "a" * 64].each do |bad|
      assert_raises(ArgumentError) { verify(token: bad) }
    end
    assert_equal @workspace, verify(token: token, now: @now + 10.minutes).fetch(:workspace)
    assert_raises(ArgumentError) { verify(token: token, now: @now + 10.minutes + 1.second) }
    assert_raises(ArgumentError) { verify(token: token, now: @now - 1.second) }
    assert_raises(ArgumentError) { verify(token: token, now: "now") }
  end

  test "C2.3b6b2.4b invalid session attributes fail closed" do
    token = prepare
    key = DomainOutbox::OperatorRequestIntent::SESSION_KEY
    original = @session.fetch(key).dup

    [nil, [], "string", {}].each do |value|
      @session[key] = value
      assert_raises(ArgumentError) { verify(token: token) }
    end

    [
      ["workspace_id", @other_workspace.id],
      ["owner_user_id", @other.id],
      ["limit", 10],
      ["issued_at", "0"],
      ["token", "Z" * 64]
    ].each do |field, altered|
      @session[key] = original.merge(field => altered)
      assert_raises(ArgumentError) { verify(token: token) }
    end

    @session[key] = original
    assert_equal 5, verify(token: token).fetch(:limit)
  end

  test "C2.3b6b2.4b invalid form limits and confirmation never reach replay" do
    token = prepare
    assert_no_difference(["OwnerOutboxReplayRun.count", "AiSpendEntry.count"]) do
      assert_raises(ArgumentError) { verify(token: token, limit: 5) }
      assert_raises(ArgumentError) { verify(token: token, confirmation: "REPLAY 25") }
      assert_raises(ArgumentError) { prepare(limit: "5") }
    end
  end
end
