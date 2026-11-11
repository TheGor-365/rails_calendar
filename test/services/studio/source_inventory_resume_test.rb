require "test_helper"

class StudioSourceInventoryResumeTest < ActiveSupport::TestCase
  Item = Struct.new(:key, :last_modified)
  Page = Struct.new(:contents, :is_truncated, :next_continuation_token)

  class FakeS3
    attr_reader :calls
    def initialize(pages)
      @pages = pages
      @calls = []
    end
    def list_objects_v2(**options)
      @calls << options
      v = @pages.fetch(options.fetch(:continuation_token, "start"))
      raise v if v.is_a?(Exception)
      v
    end
    def set(token, response)
      @pages[token] = response
    end
  end

  class FakeStorage
    attr_reader :head_calls
    def initialize(missing: [])
      @missing = missing
      @head_calls = []
    end
    def exists?(key:)
      @head_calls << key
      !@missing.include?(key)
    end
  end

  setup do
    password = "synthetic-resume-test-password"
    @owner = User.create!(email: "resume-owner@example.test", role: "owner",
      password: password, password_confirmation: password)
    @other = User.create!(email: "resume-other@example.test", role: "owner",
      password: password, password_confirmation: password)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic resume A", slug: "resume-a")
    @foreign = Workspace.create!(owner_user: @other, name: "Synthetic resume B", slug: "resume-b")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @other, role: "owner", status: "active")
    @store = Studio::PrivateSourceStorage.new
    @owned = create_blob(@owner, @ws)
    @other_blob = create_blob(@other, @foreign)
    @env = %w[RC_STUDIO_QUARANTINE_BACKEND RC_STUDIO_S3_PURPOSE
      RC_STUDIO_S3_ENDPOINT RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION
      RC_STUDIO_S3_ACCESS_KEY_ID RC_STUDIO_S3_SECRET_ACCESS_KEY].to_h { |k| [k, ENV[k]] }
    ENV.update("RC_STUDIO_QUARANTINE_BACKEND" => "s3",
      "RC_STUDIO_S3_PURPOSE" => "nonproduction-synthetic",
      "RC_STUDIO_S3_ENDPOINT" => "http://127.0.0.1:9000",
      "RC_STUDIO_S3_BUCKET" => "rc036-synthetic-resume",
      "RC_STUDIO_S3_REGION" => "us-east-1",
      "RC_STUDIO_S3_ACCESS_KEY_ID" => "synthetic",
      "RC_STUDIO_S3_SECRET_ACCESS_KEY" => "synthetic")
  end

  teardown do
    @env.each { |k,v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    @store.delete!(key: @owned.object_key)
    @store.delete!(key: @other_blob.object_key)
  end

  test "resumes encrypted cursor across fresh service instances, classifies other tenant and never deletes" do
    unknown = "q/#{"f" * 64}"
    pages = {
      "start" => Page.new([Item.new(@owned.object_key, 3.days.ago),
                           Item.new(unknown, 5.hours.ago)], true, "private-next-cursor"),
      "private-next-cursor" => Page.new([Item.new(@other_blob.object_key, 3.days.ago)], false, nil)
    }
    client = FakeS3.new(pages)
    head = FakeStorage.new(missing: [@owned.object_key])
    one = service(client, head)
    cp = one.begin!
    assert_equal cp.id, one.begin!.id
    first = one.step!(checkpoint_id: cp.id)
    assert_equal "listing", first[:phase]
    assert_equal 1, first[:pages_scanned]
    cp.reload
    assert_not_includes cp.encrypted_cursor, "private-next-cursor"
    assert_not_includes cp.counts.to_json, @owned.object_key
    assert_equal 1, cp.seen_cursor_digests.length
    assert_match(/\A[0-9a-f]{64}\z/, cp.seen_cursor_digests.first)

    restarted = service(client, head)
    second = restarted.step!(checkpoint_id: cp.id)
    assert_equal "checking", second[:phase]
    assert_equal 2, second[:pages_scanned]
    final = restarted.step!(checkpoint_id: cp.id)
    assert_equal "completed", final[:phase]
    assert_equal true, final[:scan_complete]
    assert_equal false, final[:snapshot_consistent]
    assert_equal false, final[:orphan_deletion_permitted]
    assert_equal 0, final[:deleted_objects]
    assert_equal 1, final.dig(:counts, "owned_by_workspace")
    assert_equal 1, final.dig(:counts, "foreign_workspace")
    assert_equal 1, final.dig(:counts, "orphan_candidates_review_only")
    assert_equal 1, final.dig(:counts, "db_missing_objects")
    assert_equal [nil, "private-next-cursor"], client.calls.map { |a| a[:continuation_token] }
    assert_not_includes final.to_json, unknown
    assert_not_includes final.to_json, "private-next-cursor"
    assert_not_includes cp.reload.attributes.to_json, "private-next-cursor"
    assert_equal [@owned.object_key], head.head_calls
    assert_equal final, restarted.step!(checkpoint_id: cp.id)
    assert_not cp.destroy
  end

  test "continues beyond 25 pages without losing progress" do
    pages = {}
    27.times do |i|
      token = i.zero? ? "start" : "cursor-#{i}"
      new_token = i == 26 ? nil : "cursor-#{i+1}"
      pages[token] = Page.new([], i != 26, new_token)
    end
    client = FakeS3.new(pages)
    first = service(client, FakeStorage.new)
    checkpoint = first.begin!
    15.times { first.step!(checkpoint_id: checkpoint.id) }
    assert_equal 15, checkpoint.reload.pages_scanned
    assert_equal "listing", checkpoint.state
    next_service = service(client, FakeStorage.new)
    12.times { next_service.step!(checkpoint_id: checkpoint.id) }
    result = next_service.step!(checkpoint_id: checkpoint.id)
    assert_equal "completed", result[:phase]
    assert_equal 27, result[:pages_scanned]
    assert_equal 27, client.calls.length
    assert_equal 27, checkpoint.reload.seen_cursor_digests.length + 1
  end

  test "network error never advances persisted page, safe retry resumes same cursor" do
    client = FakeS3.new({
      "start" => Page.new([], true, "cursor-a"),
      "cursor-a" => RuntimeError.new("synthetic provider outage")
    })
    check = service(client, FakeStorage.new)
    cp = check.begin!
    check.step!(checkpoint_id: cp.id)
    assert_raises(Studio::SourceInventoryResume::Denied) { check.step!(checkpoint_id: cp.id) }
    assert_equal 1, cp.reload.pages_scanned
    assert_equal "listing", cp.state
    client.set("cursor-a", Page.new([], false, nil))
    check.step!(checkpoint_id: cp.id)
    assert_equal "checking", cp.reload.state
    assert_equal 2, cp.pages_scanned
  end

  test "cursor replay, corrupted ciphertext or wrong bucket prevents continuation" do
    client = FakeS3.new({
      "start" => Page.new([], true, "cursor-a"),
      "cursor-a" => Page.new([], true, "cursor-a")
    })
    svc = service(client, FakeStorage.new)
    cp = svc.begin!
    svc.step!(checkpoint_id: cp.id)
    assert_raises(Studio::SourceInventoryResume::Denied) { svc.step!(checkpoint_id: cp.id) }
    assert_equal 1, cp.reload.pages_scanned
    ENV["RC_STUDIO_S3_BUCKET"] = "rc036-a-different-bucket"
    assert_raises(Studio::SourceInventoryResume::Denied) { svc.step!(checkpoint_id: cp.id) }
    ENV["RC_STUDIO_S3_BUCKET"] = "rc036-synthetic-resume"
    cp.update_columns(encrypted_cursor: "raw-corruption")
    assert_raises(Studio::SourceInventoryResume::Denied) { svc.step!(checkpoint_id: cp.id) }
    assert_equal 1, cp.reload.pages_scanned
  end

  test "expired and wrong-tenant checkpoints fail closed and cannot resume" do
    fake = FakeS3.new({ "start" => Page.new([], false, nil) })
    svc = service(fake, FakeStorage.new)
    cp = svc.begin!
    assert_raises(SecurityError) do
      Studio::SourceInventoryResume.new(actor: @other, workspace: @ws,
        s3_client: fake, storage: FakeStorage.new)
    end
    cp.update_columns(expires_at: 1.minute.ago)
    report = svc.step!(checkpoint_id: cp.id)
    assert_equal "failed", report[:phase]
    assert_equal 0, fake.calls.length
    assert_nil cp.reload.encrypted_cursor
    assert_equal "expired", cp.error_code
    assert_raises(Studio::SourceInventoryResume::Denied) do
      Studio::SourceInventoryResume.new(actor: @owner, workspace: @foreign,
        s3_client: fake, storage: FakeStorage.new).step!(checkpoint_id: cp.id)
    end
  end

  private

  def service(client, storage)
    Studio::SourceInventoryResume.new(actor: @owner, workspace: @ws,
      s3_client: client, storage: storage)
  end

  def create_blob(actor, workspace)
    client = workspace.clients.create!(display_name: "Fictional resumed file")
    intake = workspace.project_intakes.create!(client: client, title: "Synthetic",
      project_type: "website", goal: "No real customer documents",
      demo_consent_at: Time.current)
    Studio::ProjectSourcePipeline.new(actor: actor, workspace: workspace,
      storage: @store).stage!(client: client, intake: intake,
      filename: "resume.md", bytes: "# synthetic resumption\n").project_source_blob
  end
end
