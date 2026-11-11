require "test_helper"

class StudioProjectSourceRetentionTest < ActiveSupport::TestCase
  setup do
    password = "synthetic-retention-test-password"
    @owner = User.create!(email: "retention-owner@example.test",
      password: password, password_confirmation: password, role: "owner")
    @ws = Workspace.create!(owner_user: @owner,
      name: "Synthetic retention workspace", slug: "retention-test")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Synthetic cleanup")
    @intake = @ws.project_intakes.create!(client: @client, title: "Cleanup example",
      project_type: "website", goal: "Purely synthetic storage cleanup test.",
      demo_consent_at: Time.current)
    @store = Studio::PrivateSourceStorage.new
    @pipeline = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @ws)
    @source = @pipeline.stage!(client: @client, intake: @intake,
      filename: "cleanup.md", bytes: "# synthetic cleanup test\n")
  end

  teardown do
    @store.delete!(key: @source.project_source_blob.object_key) if @source&.project_source_blob
  end

  test "expires and physically deletes object while keeping audit metadata" do
    key = @source.project_source_blob.object_key
    assert_equal "# synthetic cleanup test\n", @store.read!(key: key)
    travel 8.days do
      sweeper = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @ws, storage: @store)
      assert_equal 1, sweeper.sweep_expired!
      assert_equal "revoked", @source.project_source_blob.reload.scan_state
      assert_raises(Studio::PrivateSourceStorage::MissingObject) { @store.read!(key: key) }
      assert_equal 0, sweeper.sweep_expired!
    end
  end

  test "does not remove unexpired sources and rejects invalid batch limits" do
    sweeper = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @ws, storage: @store)
    assert_equal 0, sweeper.sweep_expired!
    assert_raises(ArgumentError) { sweeper.sweep_expired!(limit: 0) }
    assert_raises(ArgumentError) { sweeper.sweep_expired!(limit: 1000) }
    assert_equal "quarantined", @source.project_source_blob.reload.scan_state
  end

  test "revoking workspace membership denies retention operations" do
    sweeper = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @ws, storage: @store)
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { sweeper.sweep_expired! }
    assert_equal "# synthetic cleanup test\n", @store.read!(key: @source.project_source_blob.object_key)
  end
end
