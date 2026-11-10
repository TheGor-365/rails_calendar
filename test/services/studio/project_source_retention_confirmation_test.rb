require "test_helper"

class StudioProjectSourceRetentionConfirmationTest < ActiveSupport::TestCase
  class UnverifiedStore
    attr_reader :deletions

    def initialize
      @deletions = 0
    end

    def delete!(key:)
      @deletions += 1
      true
    end

    def exists?(key:)
      true # deletion was acknowledged but bytes still exist
    end
  end

  setup do
    pass = "synthetic-confirmation-owner-password"
    @owner = User.create!(email: "confirm-retention-owner@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic retention validation",
      slug: "retention-confirmation")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
                                role: "owner", status: "active")
    client = @workspace.clients.create!(display_name: "Fictional retention")
    intake = @workspace.project_intakes.create!(client: client, title: "Fictional retention",
      project_type: "website", goal: "No actual customer data", demo_consent_at: Time.current)
    @store = Studio::PrivateSourceStorage.new
    @blob = Studio::ProjectSourcePipeline.new(actor: @owner, workspace: @workspace,
      storage: @store).stage!(client: client, intake: intake, filename: "retention.md",
      bytes: "# Synthetic retention confirmation\n").project_source_blob
  end

  teardown do
    @store.delete!(key: @blob.object_key)
  end

  test "false storage-delete success never revokes DB audit record" do
    store = UnverifiedStore.new
    sweep = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @workspace,
      storage: store)
    travel 8.days do
      assert_raises(Studio::ProjectSourceRetention::VerificationFailed) do
        sweep.sweep_expired!
      end
      assert_equal 1, store.deletions
      assert_equal "quarantined", @blob.reload.scan_state
      assert_equal true, @store.exists?(key: @blob.object_key)
    end
  end

  test "real physical absence is confirmed before changing state to revoked" do
    sweep = Studio::ProjectSourceRetention.new(actor: @owner, workspace: @workspace,
      storage: @store)
    travel 8.days do
      assert_equal 1, sweep.sweep_expired!
      assert_equal false, @store.exists?(key: @blob.object_key)
      assert_equal "revoked", @blob.reload.scan_state
    end
  end
end
