require "test_helper"

class StudioProjectSourceBlobTest < ActiveSupport::TestCase
  setup do
    pass = "synthetic-blob-only-test-password"
    @owner = User.create!(email: "blob-owner@example.test", role: "owner",
      password: pass, password_confirmation: pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic blob", slug: "blob-tenant")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Synthetic A")
    @second = @workspace.clients.create!(display_name: "Synthetic B")
    @intake = make_intake(@client)
    @other_intake = make_intake(@second)
    registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @workspace)
    report = Studio::SourceInspector.new.call(filename: "fixture.md", bytes: "# synthetic\n")
    @source = registry.register_preview!(client: @client, intake: @intake, report: report)
    other_report = Studio::SourceInspector.new.call(filename: "fixture.md", bytes: "# different synthetic\n")
    @unbound_source = registry.register_preview!(client: @client, intake: @intake, report: other_report)
    @blob = @source.create_project_source_blob!(
      workspace: @workspace, client: @client, project_intake: @intake,
      object_key: "q/#{SecureRandom.hex(32)}", scan_state: "quarantined",
      expires_at: 7.days.from_now)
  end

  test "quarantined sources cannot be clean without an attestation or updated to arbitrary fields" do
    assert_not @blob.downloadable?
    assert_not @blob.update(scan_state: "clean")
    assert_not @blob.update(scan_state: "active")
    assert_not @blob.destroy
    assert_not @blob.update(object_key: "q/#{SecureRandom.hex(32)}")
    assert_equal "quarantined", @blob.reload.scan_state
  end

  test "Postgres rejects forged cross-client blob association" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ProjectSourceBlob.insert_all!([new_attrs.merge(client_id: @second.id)])
    end
  end

  test "Postgres rejects forged clean state without scanner attestation" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ProjectSourceBlob.insert_all!([new_attrs.merge(scan_state: "clean")])
    end
  end

  test "unconfigured storage is fail-closed rather than local or public fallback" do
    Studio::PrivateSourceStorage.stub(:enabled?, false) do
      assert_raises(Studio::PrivateSourceStorage::Unavailable) { Studio::PrivateSourceStorage.new }
    end
  end

  private

  def make_intake(client)
    @workspace.project_intakes.create!(client: client, title: "Synthetic", project_type: "website",
      goal: "A fictional project for DB constraints.", demo_consent_at: Time.current)
  end

  def new_attrs
    now = Time.current
    { workspace_id: @workspace.id, client_id: @client.id, project_intake_id: @intake.id,
      project_source_id: @unbound_source.id, object_key: "q/#{SecureRandom.hex(32)}",
      scan_state: "quarantined", expires_at: 7.days.from_now,
      created_at: now, updated_at: now }
  end
end
