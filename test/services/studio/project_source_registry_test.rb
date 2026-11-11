require "test_helper"

class StudioProjectSourceRegistryTest < ActiveSupport::TestCase
  setup do
    pass = "synthetic-private-metadata-only-password"
    @owner = User.create!(email: "metadata-owner@example.test", role: "owner",
                          password: pass, password_confirmation: pass)
    @other_owner = User.create!(email: "metadata-other@example.test", role: "owner",
                                password: pass, password_confirmation: pass)
    @workspace = Workspace.create!(owner_user: @owner, name: "Synthetic Studio", slug: "metadata-studio")
    @foreign_workspace = Workspace.create!(owner_user: @other_owner, name: "Foreign Studio", slug: "metadata-foreign")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign_workspace, user: @other_owner, role: "owner", status: "active")
    @client = @workspace.clients.create!(display_name: "Synthetic Client A")
    @second_client = @workspace.clients.create!(display_name: "Synthetic Client B")
    @outsider = @foreign_workspace.clients.create!(display_name: "Synthetic Client C")
    @intake = new_intake(@workspace, @client)
    @second_intake = new_intake(@workspace, @second_client)
    @foreign_intake = new_intake(@foreign_workspace, @outsider)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @workspace)
    @report = Studio::SourceInspector.new.call(filename: "synthetic.md",
              bytes: "# Fixture only\n- [ ] No personal information\n")
  end

  test "identical previews are idempotent and metadata cannot be downloaded" do
    first = @registry.register_preview!(client: @client, intake: @intake, report: @report)
    again = @registry.register_preview!(client: @client, intake: @intake, report: @report)
    assert_equal first.id, again.id
    assert_equal [first.id], @registry.list!(client: @client, intake: @intake).pluck(:id)
    assert_equal "metadata_only", first.state
    assert_not first.downloadable?
    assert_equal @report.fetch("sha256"), first.source_sha256
    assert_nil first.attributes["filename"]
    assert_nil first.attributes["storage_key"]
    assert_nil first.attributes["text"]
    assert_not first.update(state: "released")
    assert_not first.destroy
    assert_raises(SecurityError) { @registry.download!(client: @client, intake: @intake, id: first.id) }
  end

  test "different clients in the same workspace cannot read each others source records" do
    source = @registry.register_preview!(client: @client, intake: @intake, report: @report)
    assert_empty @registry.list!(client: @second_client, intake: @second_intake)
    assert_raises(ActiveRecord::RecordNotFound) do
      @registry.find!(client: @second_client, intake: @second_intake, id: source.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      @registry.download!(client: @second_client, intake: @second_intake, id: source.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      @registry.register_preview!(client: @second_client, intake: @intake, report: @report)
    end
  end

  test "foreign tenant and revoked membership are denied" do
    assert_raises(SecurityError) do
      Studio::ProjectSourceRegistry.new(actor: @other_owner, workspace: @workspace)
    end
    assert_raises(SecurityError) do
      @registry.register_preview!(client: @outsider, intake: @foreign_intake, report: @report)
    end
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { @registry.list!(client: @client, intake: @intake) }
    assert_raises(SecurityError) do
      @registry.register_preview!(client: @client, intake: @intake, report: @report)
    end
  end

  test "legacy unscoped intake and forged parser reports fail closed" do
    legacy = ProjectIntake.create!(title: "Old synthetic", project_type: "website",
      goal: "Legacy synthetic goal must remain unassigned", demo_consent_at: Time.current)
    assert_raises(ActiveRecord::RecordNotFound) do
      @registry.register_preview!(client: @client, intake: legacy, report: @report)
    end
    altered = @report.merge("stored" => true)
    assert_raises(ArgumentError) do
      @registry.register_preview!(client: @client, intake: @intake, report: altered)
    end
    assert_raises(ArgumentError) do
      @registry.register_preview!(client: @client, intake: @intake,
        report: @report.merge("sha256" => "bad", "provider_ready" => true))
    end
    assert_empty ProjectSource.all
  end

  test "database rejects cross-client association even when model validations are bypassed" do
    now = Time.current
    attrs = {
      workspace_id: @workspace.id, client_id: @second_client.id,
      project_intake_id: @intake.id, recorded_by_id: @owner.id,
      source_sha256: @report.fetch("sha256"), byte_size: @report.fetch("bytes"),
      source_format: "markdown", parser_version: ProjectSource::PARSER_VERSION,
      state: "metadata_only", created_at: now, updated_at: now
    }
    assert_raises(ActiveRecord::InvalidForeignKey) { ProjectSource.insert_all!([attrs]) }
  end

  test "database rejects a forged released state without a scanner or storage gate" do
    now = Time.current
    attrs = {
      workspace_id: @workspace.id, client_id: @client.id,
      project_intake_id: @intake.id, recorded_by_id: @owner.id,
      source_sha256: @report.fetch("sha256"), byte_size: @report.fetch("bytes"),
      source_format: "markdown", parser_version: ProjectSource::PARSER_VERSION,
      state: "released", created_at: now, updated_at: now
    }
    assert_raises(ActiveRecord::StatementInvalid) { ProjectSource.insert_all!([attrs]) }
  end

  private

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Synthetic project",
      project_type: "website", goal: "A fictional concept for safe previews only.",
      demo_consent_at: Time.current)
  end
end
