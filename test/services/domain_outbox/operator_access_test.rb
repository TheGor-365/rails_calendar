require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxOperatorAccessTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("operator-access-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("operator-access-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("operator-access-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @empty_owner = make_test_owner("operator-access-empty-#{SecureRandom.hex(6)}@example.test")
  end

  test "C2.3b6b2.1 owner authority resolves only own persisted workspace without queue writes" do
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal @workspace, DomainOutbox::OperatorAccess.workspace_for!(owner: @owner)
      assert_equal @other_workspace, DomainOutbox::OperatorAccess.workspace_for!(owner: @other)
      assert_equal 0, DomainOutbox::Health.snapshot(owner: @owner)[:total]
      assert_equal [], DomainOutbox::Health.preview(owner: @other)
    end
  end

  test "C2.3b6b2.1 unauthenticated client and owner without workspace are denied" do
    [nil, @client, @empty_owner, Workspace.new, "owner", @workspace].each do |actor|
      assert_raises(ArgumentError) do
        DomainOutbox::OperatorAccess.workspace_for!(owner: actor)
      end
    end
  end

  test "C2.3b6b2.1 replay limit policy is a narrow allowlist and never invokes replay" do
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      [1, 5, 10, 25].each do |limit|
        assert_equal limit, DomainOutbox::OperatorAccess.replay_limit!(limit: limit)
      end
      [0, -1, 2, 26, 50, 100, 101, "10", 10.0, nil, true].each do |invalid|
        assert_raises(ArgumentError) do
          DomainOutbox::OperatorAccess.replay_limit!(limit: invalid)
        end
      end
    end
  end
end
