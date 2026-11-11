require "test_helper"

class StudioSourceInventoryAuditTest < ActiveSupport::TestCase
  Item = Struct.new(:key, :last_modified)
  Listing = Struct.new(:contents, :is_truncated)

  class FakeClient
    attr_reader :calls
    def initialize(objects:, truncated: false, fail_list: false)
      @objects = objects
      @truncated = truncated
      @fail_list = fail_list
      @calls = []
    end
    def list_objects_v2(bucket:, prefix:, max_keys:)
      @calls << [bucket, prefix, max_keys]
      raise "synthetic backend unavailable" if @fail_list
      Listing.new(@objects, @truncated)
    end
  end

  class FakeHead
    attr_reader :checked
    def initialize(missing: [])
      @missing = missing
      @checked = []
    end
    def exists?(key:)
      @checked << key
      !@missing.include?(key)
    end
  end

  setup do
    password = "synthetic-inventory-password-2026"
    @owner = User.create!(email: "inventory-owner@example.test", role: "owner",
      password: password, password_confirmation: password)
    @foreign_owner = User.create!(email: "inventory-other@example.test", role: "owner",
      password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic inventory A",
      slug: "inventory-test-a")
    @foreign_workspace = Workspace.create!(owner_user: @foreign_owner,
      name: "Synthetic inventory B", slug: "inventory-test-b")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
                                role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @foreign_owner,
                                role: "owner", status: "active")
    store = Studio::PrivateSourceStorage.new
    @owned = create_blob(store, @owner, @workspace, "owned.md")
    @foreign = create_blob(store, @foreign_owner, @foreign_workspace, "foreign.md")
    @store = store

    @saved = %w[
      RC_STUDIO_QUARANTINE_BACKEND RC_STUDIO_S3_PURPOSE RC_STUDIO_S3_ENDPOINT
      RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION RC_STUDIO_S3_ACCESS_KEY_ID
      RC_STUDIO_S3_SECRET_ACCESS_KEY
    ].to_h { |key| [key, ENV[key]] }
    ENV["RC_STUDIO_QUARANTINE_BACKEND"] = "s3"
    ENV["RC_STUDIO_S3_PURPOSE"] = "nonproduction-synthetic"
    ENV["RC_STUDIO_S3_ENDPOINT"] = "http://127.0.0.1:9000"
    ENV["RC_STUDIO_S3_BUCKET"] = "rc036-test-inventory"
    ENV["RC_STUDIO_S3_REGION"] = "us-east-1"
    ENV["RC_STUDIO_S3_ACCESS_KEY_ID"] = "synthetic-test-only"
    ENV["RC_STUDIO_S3_SECRET_ACCESS_KEY"] = "synthetic-test-only"
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    @store.delete!(key: @owned.object_key)
    @store.delete!(key: @foreign.object_key)
  end

  test "bounded listing separates owned, foreign, recent and old unreferenced without delete" do
    old_unknown = "q/#{"a" * 64}"
    recent_unknown = "q/#{"b" * 64}"
    invalid = "wrong-prefix"
    client = FakeClient.new(objects: [
      Item.new(@owned.object_key, 3.days.ago),
      Item.new(@foreign.object_key, 3.days.ago),
      Item.new(old_unknown, 3.hours.ago),
      Item.new(recent_unknown, 15.minutes.ago),
      Item.new(invalid, 4.hours.ago)
    ])
    head = FakeHead.new(missing: [@owned.object_key])
    result = Studio::SourceInventoryAudit.new(actor: @owner, workspace: @workspace,
      s3_client: client, storage: head).call(limit: 6)
    counts = result.fetch(:counts)
    assert_equal [["rc036-test-inventory", "q/", 6]], client.calls
    assert_equal 4, counts.fetch(:listed)
    assert_equal 1, counts.fetch(:invalid_keys)
    assert_equal 1, counts.fetch(:owned_by_workspace)
    assert_equal 1, counts.fetch(:belongs_to_other_workspace)
    assert_equal 1, counts.fetch(:orphan_candidates)
    assert_equal 1, counts.fetch(:recent_unreferenced)
    assert_equal 1, counts.fetch(:scoped_metadata_checked)
    assert_equal 1, counts.fetch(:scoped_missing_objects)
    assert_equal false, result.fetch(:listing_truncated)
    assert_equal false, result.fetch(:automatic_deletion)
    assert_equal 0, result.fetch(:actual_storage_deletions)
    assert_not_includes result.to_json, old_unknown
    assert_not_includes result.to_json, @owned.object_key
  end

  test "partial listing must be labeled partial and unverified last_modified never an orphan" do
    unknown = "q/#{"c" * 64}"
    client = FakeClient.new(objects: [Item.new(unknown, nil)], truncated: true)
    result = Studio::SourceInventoryAudit.new(actor: @owner, workspace: @workspace,
      s3_client: client, storage: FakeHead.new).call(limit: 1)
    assert_equal "partial", result.fetch(:completeness)
    assert_equal true, result.fetch(:listing_truncated)
    assert_equal 1, result.dig(:counts, :unverified_unreferenced)
    assert_equal 0, result.dig(:counts, :orphan_candidates)
  end

  test "provider list failure, revoked owner, non S3 or wrong environment fail closed" do
    assert_raises(SecurityError) do
      Studio::SourceInventoryAudit.new(actor: @owner, workspace: @workspace,
        s3_client: FakeClient.new(objects: [], fail_list: true),
        storage: FakeHead.new).call
    end
    ENV["RC_STUDIO_S3_PURPOSE"] = "production"
    assert_raises(Studio::PrivateSourceStorage::Unavailable) do
      Studio::SourceInventoryAudit.new(actor: @owner, workspace: @workspace,
        s3_client: FakeClient.new(objects: []), storage: FakeHead.new)
    end
    ENV["RC_STUDIO_S3_PURPOSE"] = "nonproduction-synthetic"
    assert_raises(SecurityError) do
      Studio::SourceInventoryAudit.new(actor: @foreign_owner, workspace: @workspace,
        s3_client: FakeClient.new(objects: []), storage: FakeHead.new)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      Studio::SourceInventoryAudit.new(actor: @owner, workspace: @workspace,
        s3_client: FakeClient.new(objects: []), storage: FakeHead.new)
    end
  end

  private

  def create_blob(storage, actor, workspace, filename)
    client = workspace.clients.create!(display_name: "Synthetic inventory #{filename}")
    intake = workspace.project_intakes.create!(client: client, title: "Synthetic inventory",
      project_type: "website", goal: "Only synthetic reconciliation fixtures",
      demo_consent_at: Time.current)
    Studio::ProjectSourcePipeline.new(actor: actor, workspace: workspace, storage: storage)
      .stage!(client: client, intake: intake, filename: filename,
              bytes: "# Synthetic #{filename}\n").project_source_blob
  end
end
