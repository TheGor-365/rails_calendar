require "test_helper"

class StudioSourceScanQueueTest < ActiveSupport::TestCase
  class FakeScanner
    attr_reader :calls

    def initialize(failures: 0, state: "clean")
      @failures = failures
      @state = state
      @calls = 0
    end

    def scan!(_bytes)
      @calls += 1
      if @calls <= @failures
        raise Studio::ClamAvScanner::Unavailable, "Synthetic scanner not ready"
      end

      Studio::ClamAvScanner::Verdict.new(state: @state, engine: "synthetic-queue-test")
    end
  end

  setup do
    password = "nonproduction-scan-queue-owner-password"
    @owner = User.create!(email: "scanqueue-owner@example.test",
      password: password, password_confirmation: password, role: "owner")
    @other = User.create!(email: "scanqueue-other@example.test",
      password: password, password_confirmation: password, role: "owner")
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic scan-queue A", slug: "scanqueue-a")
    @ws_other = Workspace.create!(owner_user: @other, name: "Synthetic scan-queue B", slug: "scanqueue-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @ws_other, user: @other, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Queue A")
    @different_client = @ws.clients.create!(display_name: "Queue B")
    @intake = @ws.project_intakes.create!(client: @client, title: "Fictional queue project",
      project_type: "website", goal: "A purely synthetic scan queue test", demo_consent_at: Time.current)
    @different_intake = @ws.project_intakes.create!(client: @different_client, title: "Fictional other",
      project_type: "website", goal: "Another fictional queue test", demo_consent_at: Time.current)
    @store = Studio::PrivateSourceStorage.new
    @source = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @ws, storage: @store)
      .stage!(client: @client, intake: @intake,
              filename: "queue.md", bytes: "# Synthetic queued material\n")
  end

  teardown do
    blob = @source&.project_source_blob
    @store.delete!(key: blob.object_key) if blob
  end

  test "enqueue is tenant scoped and idempotent; worker marks scan clean once" do
    fake = FakeScanner.new
    queue = build_queue(fake)
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    assert_equal task.id, queue.enqueue!(client: @client, intake: @intake, source_id: @source.id).id
    assert_equal 1, Studio::SourceScanTask.count
    assert_equal "queued", task.state
    assert_equal "quarantined", @source.project_source_blob.reload.scan_state
    assert_equal 1, queue.process_due!(limit: 2)
    assert_equal "complete_clean", task.reload.state
    assert_equal 1, task.attempts
    assert_equal 1, fake.calls
    assert @source.project_source_blob.reload.downloadable?
    assert_equal 0, queue.process_due!
    assert_equal({ "complete_clean" => 1 }, queue.summary)
    assert_raises(Studio::SourceScanQueue::Denied) do
      queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    end
  end

  test "infected verdict is terminal and bytes stay inaccessible" do
    queue = build_queue(FakeScanner.new(state: "infected"))
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    assert_equal 1, queue.process_due!
    assert_equal "complete_infected", task.reload.state
    assert_equal "infected", @source.project_source_blob.reload.scan_state
    assert_not @source.project_source_blob.downloadable?
    assert_equal 0, queue.process_due!
  end

  test "scanner failure fails closed, retries after backoff and eventually succeeds" do
    fake = FakeScanner.new(failures: 1)
    queue = build_queue(fake)
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    assert_equal 1, queue.process_due!
    assert_equal "retry_wait", task.reload.state
    assert_equal 1, task.attempts
    assert_equal "scan_denied", task.last_error_code
    assert_equal "failed", @source.project_source_blob.reload.scan_state
    assert_not @source.project_source_blob.downloadable?
    assert_equal 0, queue.process_due!
    travel 6.minutes do
      assert_equal 1, queue.process_due!
    end
    assert_equal "complete_clean", task.reload.state
    assert_equal 2, task.attempts
    assert_nil task.last_error_code
    assert_equal 2, fake.calls
    assert @source.project_source_blob.reload.downloadable?
  end

  test "three scanner failures exhaust without repeatedly retrying unboundedly" do
    queue = build_queue(FakeScanner.new(failures: 20))
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    assert_equal 1, queue.process_due!
    travel 6.minutes do
      assert_equal 1, queue.process_due!
    end
    # Third attempt is due 30 minutes after the second attempt at +6m.
    travel 37.minutes do
      assert_equal 1, queue.process_due!
      assert_equal "exhausted", task.reload.state
      assert_equal 3, task.attempts
      assert_equal "scan_denied", task.last_error_code
      assert_equal 0, queue.process_due!
    end
    assert_equal "failed", @source.project_source_blob.reload.scan_state
    assert_not @source.project_source_blob.downloadable?
  end

  test "expiry never scans and retention deletes physical bytes without regrant" do
    queue = build_queue(FakeScanner.new)
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    key = @source.project_source_blob.object_key
    travel 8.days do
      assert_equal 1, queue.process_due!
      assert_equal "expired", task.reload.state
      assert_equal 0, task.attempts
      sweeper = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @ws, storage: @store)
      assert_equal 1, sweeper.sweep_expired!
      assert_equal "revoked", @source.project_source_blob.reload.scan_state
      assert_raises(Studio::PrivateSourceStorage::MissingObject) { @store.read!(key: key) }
      assert_equal 0, queue.process_due!
    end
  end

  test "wrong client and revoked or foreign owner cannot enqueue or process" do
    queue = build_queue(FakeScanner.new)
    assert_raises(ActiveRecord::RecordNotFound) do
      queue.enqueue!(client: @different_client, intake: @different_intake, source_id: @source.id)
    end
    assert_raises(Studio::SourceScanQueue::Denied) do
      queue.enqueue!(client: @client, intake: @different_intake, source_id: @source.id)
    end
    assert_raises(SecurityError) do
      Studio::SourceScanQueue.new(actor: @other, workspace: @ws, storage: @store)
    end
    task = queue.enqueue!(client: @client, intake: @intake, source_id: @source.id)
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { queue.process_due! }
    assert_equal "queued", task.reload.state
    assert_equal "quarantined", @source.project_source_blob.reload.scan_state
  end

  test "queue never processes invalid batch limits or a forged cross-tenant task" do
    queue = build_queue(FakeScanner.new)
    assert_raises(ArgumentError) { queue.process_due!(limit: 0) }
    assert_raises(ArgumentError) { queue.process_due!(limit: 1000) }
    blob = @source.project_source_blob
    now = Time.current
    values = {
      workspace_id: @ws_other.id, project_source_blob_id: blob.id,
      state: "queued", attempts: 0, next_attempt_at: now,
      created_at: now, updated_at: now
    }
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Studio::SourceScanTask.insert_all!([values])
      end
    end
  end

  private

  def build_queue(scanner)
    Studio::SourceScanQueue.new(actor: @owner, workspace: @ws,
                                storage: @store, scanner: scanner)
  end
end
