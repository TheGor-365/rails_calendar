require "test_helper"

class StudioOfflineSourceSelectorTest < ActiveSupport::TestCase
  setup do
    nonce = SecureRandom.hex(5)
    pass = "rc037-synthetic-source-selector-password"
    @owner = User.create!(email: "src-owner-#{nonce}@example.test",
      role: "owner", password: pass, password_confirmation: pass)
    @outsider = User.create!(email: "src-other-#{nonce}@example.test",
      role: "owner", password: pass, password_confirmation: pass)
    @ws = Workspace.create!(owner_user: @owner, name: "Synthetic source select", slug: "srcselect-#{nonce}")
    @foreign = Workspace.create!(owner_user: @outsider, name: "Foreign source select", slug: "srcforeign-#{nonce}")
    WorkspaceMembership.create!(workspace: @ws, user: @owner, role: "owner", status: "active")
    WorkspaceMembership.create!(workspace: @foreign, user: @outsider, role: "owner", status: "active")
    @client = @ws.clients.create!(display_name: "Fictional source A")
    @other_client = @ws.clients.create!(display_name: "Fictional source B")
    @intake = new_intake(@ws, @client)
    @other_intake = new_intake(@ws, @other_client)
    foreign_client = @foreign.clients.create!(display_name: "Fictional source C")
    @foreign_intake = new_intake(@foreign, foreign_client)
    @registry = Studio::ProjectSourceRegistry.new(actor: @owner, workspace: @ws)
    @one = add_source(@registry, @client, @intake, "# One synthetic\n")
    @other = add_source(@registry, @other_client, @other_intake, "# Other synthetic\n")
    foreign_registry = Studio::ProjectSourceRegistry.new(actor: @outsider, workspace: @foreign)
    @foreign_source = add_source(foreign_registry, foreign_client, @foreign_intake, "# Foreign synthetic\n")
  end

  test "only explicitly selected metadata is returned; no source bytes" do
    assert_equal [], selector.select!(source_ids: [])
    result = selector.select!(source_ids: [@one.id])
    assert_equal [@one.id], result.pluck(:source_id)
    assert_equal @one.source_sha256, result.first.fetch(:sha256)
    assert_equal "markdown", result.first.fetch(:format)
    refute_includes result.to_json, "One synthetic"
    refute_includes result.to_json, @owner.email
    assert_equal 4, result.first.keys.length
  end

  test "foreign, same-workspace other-client and invalid lists fail closed" do
    [[@other.id], [@foreign_source.id], [@one.id, @other.id],
     [@one.id, @one.id], ["1"], [0], [-3], [nil],
     (1..11).to_a, "#{@one.id}", nil].each do |input|
      assert_raises(Studio::OfflineSourceSelector::Denied) do
        selector.select!(source_ids: input)
      end
    end
    assert_raises(SecurityError) do
      Studio::OfflineSourceSelector.new(actor: @outsider, workspace: @ws, intake: @intake)
    end
    assert_raises(SecurityError) do
      Studio::OfflineSourceSelector.new(actor: @owner, workspace: @foreign, intake: @intake)
    end
  end

  test "revoked owner loses access to already initialized selector" do
    active = selector
    @ws.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) { active.select!(source_ids: [@one.id]) }
  end

  test "dispatcher uses only selected count and fails on foreign source, not all project sources" do
    @ws.studio_ai_policies.create!(mode: "offline", purposes: ["source_outline"])
    dispatcher = Studio::OfflineAiDispatcher.new(actor: @owner, workspace: @ws, intake: @intake)
    assert_equal 0, dispatcher.call(purpose: "source_outline")[:source_metadata_count]
    result = dispatcher.call(purpose: "source_outline", source_ids: [@one.id])
    assert_equal 1, result[:source_metadata_count]
    assert_equal 0, result[:external_calls]
    assert_equal 0, result[:billable_usd]
    assert_raises(Studio::OfflineSourceSelector::Denied) do
      dispatcher.call(purpose: "source_outline", source_ids: [@other.id])
    end
  end

  private

  def selector
    Studio::OfflineSourceSelector.new(actor: @owner, workspace: @ws, intake: @intake)
  end

  def new_intake(workspace, client)
    workspace.project_intakes.create!(client: client, title: "Synthetic selection",
      project_type: "website", goal: "Synthetic metadata-only source selection.",
      demo_consent_at: Time.current)
  end

  def add_source(registry, client, intake, body)
    report = Studio::SourceInspector.new.call(filename: "synthetic.md", bytes: body)
    registry.register_preview!(client: client, intake: intake, report: report)
  end
end
