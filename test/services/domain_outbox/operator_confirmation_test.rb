require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxOperatorConfirmationTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-confirm-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-confirm-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-confirm-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @empty_owner = make_test_owner("outbox-confirm-empty-#{SecureRandom.hex(6)}@example.test")
  end

  def validate(owner: @owner, limit: "5", confirmation: "REPLAY 5")
    DomainOutbox::OperatorConfirmation.validate!(
      owner: owner, limit: limit, confirmation: confirmation
    )
  end

  test "C2.3b6b2.4a exact owner confirmation is bounded and non-mutating" do
    assert_no_difference([
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      %w[1 5 10 25].each do |raw|
        result = validate(limit: raw, confirmation: "REPLAY #{raw}")
        assert_equal @workspace, result.fetch(:workspace)
        assert_equal raw.to_i, result.fetch(:limit)
      end
      assert_equal @other_workspace, validate(owner: @other).fetch(:workspace)
    end
  end

  test "C2.3b6b2.4a rejects guest client and missing owner workspace" do
    [nil, @client, @empty_owner, @workspace, "owner"].each do |actor|
      assert_raises(ArgumentError) { validate(owner: actor) }
    end
  end

  test "C2.3b6b2.4a rejects ambiguous limits and nonexact confirmation" do
    [nil, 5, "0", "-1", "2", "05", "50", "100", "5 ", ["5"], { value: "5" }].each do |bad|
      assert_raises(ArgumentError) { validate(limit: bad) }
    end
    [nil, false, "REPLAY", "replay 5", "REPLAY 05", "REPLAY 25",
     "REPLAY 5 ", " REPLAY 5", "REPLAY 5\n", ["REPLAY 5"]].each do |bad|
      assert_raises(ArgumentError) { validate(confirmation: bad) }
    end
  end
end
