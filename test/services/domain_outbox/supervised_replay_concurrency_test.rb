require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"
require "timeout"

# Separate committed synthetic setup is intentional: the two Rails threads
# must see the same persisted workspace through independent PG connections.
# This test class never uses development, scratch, source or production DBs.
class DomainOutboxSupervisedReplayConcurrencyTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData
  self.use_transactional_tests = false

  setup do
    @owner = make_test_owner("supervised-concurrent-#{SecureRandom.hex(8)}@example.test")
    @workspace = @owner.create_owner_workspace!
    @now = Time.zone.parse("2026-11-22 15:00:00")
  end

  teardown do
    next unless @workspace&.persisted?

    OwnerOutboxReplayRun.where(workspace_id: @workspace.id).delete_all
    @workspace.destroy!
    @owner.destroy! if @owner&.persisted?
  end

  test "C2.3b6c2.2 two real PG sessions prevent duplicate and parallel owner replay" do
    started = Queue.new
    release = Queue.new
    results = Queue.new
    errors = Queue.new
    calls = Queue.new
    owner_id = @owner.id

    # Replayer is intentionally synthetic: verify the real database-backed
    # operator lease/concurrency without mutating any canonical source.
    fake_replayer = lambda do |workspace:, limit:, now:|
      calls << workspace.id
      started << true
      release.pop
      { attempted: 0, delivered: 0, failed: 0 }
    end

    workers = []
    begin
      DomainOutbox::Replayer.stub(:run!, fake_replayer) do
        workers << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              pid = ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
              result = DomainOutbox::SupervisedReplay.run!(
                owner: User.find(owner_id), request_token: "a" * 64,
                limit: 1, confirmed: true, now: @now
              )
              results << [pid, :first, result]
            rescue StandardError => e
              errors << e
            end
          end
        end

        # Ensure the first command has committed its running ledger row
        # and is paused in the synthetic replayer.
        Timeout.timeout(15) { started.pop }

        workers << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              pid = ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
              different = DomainOutbox::SupervisedReplay.run!(
                owner: User.find(owner_id), request_token: "b" * 64,
                limit: 1, confirmed: true, now: @now
              )
              duplicate = DomainOutbox::SupervisedReplay.run!(
                owner: User.find(owner_id), request_token: "a" * 64,
                limit: 1, confirmed: true, now: @now
              )
              results << [pid, :second, different, duplicate]
            rescue StandardError => e
              errors << e
            end
          end
        end

        assert workers.last.join(15), "second PostgreSQL connection stalled"
      ensure
        release << true
      end
    ensure
      workers.each do |thread|
        unless thread.join(15)
          thread.kill
          flunk "supervised replay worker did not terminate"
        end
      end
    end

    raise errors.pop unless errors.empty?

    first = results.pop
    second = results.pop
    first, second = second, first if first[1] == :second
    assert_equal :first, first[1]
    assert_equal :second, second[1]
    assert_not_equal first[0], second[0], "expected independent PG backend sessions"
    assert_equal "succeeded", first[2].fetch(:status)
    assert_equal "busy", second[2].fetch(:status)
    assert_equal "duplicate", second[3].fetch(:status)
    assert_equal [@workspace.id], [calls.pop]
    assert calls.empty?, "replayer was invoked twice"
    assert_equal 1, OwnerOutboxReplayRun.where(workspace_id: @workspace.id).count
    record = OwnerOutboxReplayRun.find_by!(workspace_id: @workspace.id)
    assert_equal "succeeded", record.state
    assert_equal @owner.id, record.owner_user_id
  end
end
