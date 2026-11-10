require "test_helper"

class StudioSourceInventoryReconciliationTest < ActiveSupport::TestCase
  Item = Struct.new(:key, :last_modified)
  Page = Struct.new(:contents, :is_truncated, :next_continuation_token)

  class FakeList
    attr_reader :calls
    def initialize(pages)
      @pages = pages
      @calls = []
    end

    def list_objects_v2(**args)
      @calls << args
      token = args[:continuation_token]
      page = @pages.fetch(token || "start")
      raise page if page.is_a?(Exception)
      page
    end
  end

  class FakeHead
    attr_reader :keys
    def initialize(missing: [])
      @missing = missing
      @keys = []
    end
    def exists?(key:)
      @keys << key
      !@missing.include?(key)
    end
  end

  setup do
    pass = "synthetic-pages-test-password-2026"
    @owner = User.create!(email: "page-owner@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @other_owner = User.create!(email: "page-foreign@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Pagination synthetic A", slug: "page-a")
    @foreign = Workspace.create!(owner_user: @other_owner, name: "Pagination synthetic B", slug: "page-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other_owner, role: "owner", status: "active")
    @store = Studio::PrivateSourceStorage.new
    @owned = create_blob(@owner, @ws)
    @foreign_blob = create_blob(@other_owner, @foreign)
    @env = %w[RC_STUDIO_QUARANTINE_BACKEND RC_STUDIO_S3_PURPOSE RC_STUDIO_S3_ENDPOINT
      RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION RC_STUDIO_S3_ACCESS_KEY_ID
      RC_STUDIO_S3_SECRET_ACCESS_KEY].to_h { |k| [k, ENV[k]] }
    ENV.update({
      "RC_STUDIO_QUARANTINE_BACKEND" => "s3",
      "RC_STUDIO_S3_PURPOSE" => "nonproduction-synthetic",
      "RC_STUDIO_S3_ENDPOINT" => "http://127.0.0.1:9000",
      "RC_STUDIO_S3_BUCKET" => "rc036-test-paginated",
      "RC_STUDIO_S3_REGION" => "us-east-1",
      "RC_STUDIO_S3_ACCESS_KEY_ID" => "synthetic",
      "RC_STUDIO_S3_SECRET_ACCESS_KEY" => "synthetic"
    })
  end

  teardown do
    @env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    @store.delete!(key: @owned.object_key)
    @store.delete!(key: @foreign_blob.object_key)
  end

  test "two pages and all scoped DB rows give complete-but-not-snapshot-consistent read-only report" do
    orphan = "q/#{"a" * 64}"
    recent = "q/#{"b" * 64}"
    fake = FakeList.new({
      "start" => Page.new([Item.new(@owned.object_key, 1.day.ago),
                            Item.new(orphan, 3.hours.ago)], true, "page-two"),
      "page-two" => Page.new([Item.new(@foreign_blob.object_key, 1.day.ago),
                               Item.new(recent, 2.minutes.ago)], false, nil)
    })
    head = FakeHead.new(missing: [@owned.object_key])
    result = audit(fake, head).call
    counts = result.fetch(:counts)
    assert_equal 2, result[:pages]
    assert result[:list_complete]
    assert result[:db_complete]
    assert result[:reconciliation_complete]
    assert_equal 1, counts[:owned_by_workspace]
    assert_equal 1, counts[:foreign_workspace]
    assert_equal 1, counts[:orphan_candidates_review_only]
    assert_equal 1, counts[:recent_unreferenced]
    assert_equal 1, counts[:db_active_total]
    assert_equal 1, counts[:db_missing_objects]
    assert_equal false, result[:snapshot_consistent]
    assert_equal false, result[:orphan_deletion_permitted]
    assert_equal 0, result[:deleted_objects]
    assert_not_includes result.to_json, orphan
    assert_not_includes result.to_json, @foreign_blob.object_key
    assert_equal [nil, "page-two"], fake.calls.map { |x| x[:continuation_token] }
    assert fake.calls.all? { |x| x[:prefix] == "q/" && x[:max_keys] == 100 }
    assert_equal [@owned.object_key], head.keys
  end

  test "budget ceilings make list or DB reconciliation explicitly incomplete" do
    first = Page.new([Item.new(@owned.object_key, 2.hours.ago)], true, "next")
    fake = FakeList.new({ "start" => first })
    result = audit(fake, FakeHead.new).call(max_pages: 1)
    assert_equal 1, result[:pages]
    assert_equal false, result[:list_complete]
    assert_equal false, result[:reconciliation_complete]
    assert_equal 1, fake.calls.length

    # Only one scoped active DB row: check that the limit itself is validated
    assert_raises(ArgumentError) { audit(fake, FakeHead.new).call(max_db_heads: 0) }
    assert_raises(ArgumentError) { audit(fake, FakeHead.new).call(max_pages: 1000) }
  end

  test "missing or repeating cursors, oversized provider pages and API failure fail closed" do
    unknown = Item.new("q/#{"c" * 64}", 3.days.ago)
    scenarios = [
      { "start" => Page.new([unknown], true, nil) },
      { "start" => Page.new([unknown], true, "same"),
        "same" => Page.new([unknown], true, "same") },
      { "start" => Page.new(Array.new(101, unknown), false, nil) },
      { "start" => RuntimeError.new("synthetic network failure") }
    ]
    scenarios.each do |pages|
      assert_raises(SecurityError) { audit(FakeList.new(pages), FakeHead.new).call }
    end
  end

  test "no owner permission, invalid bucket purpose or production-only storage prevents inventory" do
    fake = FakeList.new({ "start" => Page.new([], false, nil) })
    assert_raises(SecurityError) do
      Studio::SourceInventoryReconciliation.new(actor: @other_owner, workspace: @ws,
        s3_client: fake, storage: FakeHead.new)
    end
    ENV["RC_STUDIO_S3_PURPOSE"] = "production"
    assert_raises(Studio::PrivateSourceStorage::Unavailable) do
      audit(fake, FakeHead.new)
    end
  end

  private

  def audit(client, storage)
    Studio::SourceInventoryReconciliation.new(actor: @owner, workspace: @ws,
      s3_client: client, storage: storage)
  end

  def create_blob(actor, workspace)
    client = workspace.clients.create!(display_name: "Fictional pagination")
    intake = workspace.project_intakes.create!(client: client, title: "Fictional",
      project_type: "website", goal: "Only synthetic S3 test", demo_consent_at: Time.current)
    Studio::ProjectSourcePipeline.new(actor: actor, workspace: workspace,
      storage: @store).stage!(client: client, intake: intake, filename: "pagination.md",
      bytes: "# Fictional pagination test\n").project_source_blob
  end
end
