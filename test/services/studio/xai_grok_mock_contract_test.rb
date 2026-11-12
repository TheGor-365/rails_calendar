require "test_helper"

class StudioXaiGrokMockContractTest < ActiveSupport::TestCase
  setup do
    nonce = SecureRandom.hex(5)
    password = "synthetic-grok-mock-test-password"
    @owner = User.create!(email: "grok-owner-#{nonce}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @outsider = User.create!(email: "grok-outsider-#{nonce}@example.test",
      role: "owner", password: password, password_confirmation: password)
    @workspace = Workspace.create!(owner_user: @owner, name: "Fictional Grok pilot",
      slug: "grok-mock-#{nonce}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    client = @workspace.clients.create!(display_name: "Fictional customer")
    @intake = @workspace.project_intakes.create!(client: client,
      title: "PRIVATE FICTIONAL TITLE", project_type: "website",
      goal: "PRIVATE FICTIONAL GOAL", demo_consent_at: Time.current)
  end

  test "mocked xAI 200 contract returns review-only metadata with zero actual spend" do
    observed = nil
    client = pilot(->(request) { observed = request; example_response })
    result = client.call(purpose: "clarify", source_ids: [101, 102])
    assert_equal "grok-4.7", result[:model]
    assert_equal "mock_only", result[:provider_executed]
    assert_equal "needs_human_review", result[:status]
    assert_equal 2, result[:source_metadata_count]
    assert_equal 300_000, result[:reported_mock_cost_ticks]
    assert_equal 0, result[:billed_usd_ticks]
    assert_equal 0, result[:external_calls]
    assert_equal false, result[:auto_approved]
    assert_equal [], observed[:tools]
    assert_equal "synthetic", observed[:source_classification]
    refute_includes observed.to_s, @intake.title
    refute_includes result.to_s, @intake.goal
  end

  test "malformed json, missing price and falsified tokens deny mock admission" do
    bad_json = pilot(->(_) { "{invalid" })
    assert_raises(contract::InvalidResponse) { bad_json.call(purpose: "clarify", source_ids: [101, 102]) }

    missing = JSON.parse(example_response)
    missing["usage"].delete("cost_in_usd_ticks")
    assert_raises(contract::InvalidResponse) do
      pilot(->(_) { missing.to_json }).call(purpose: "clarify", source_ids: [101, 102])
    end

    large = JSON.parse(example_response)
    large["usage"]["cost_in_usd_ticks"] = 100_000_001
    assert_raises(contract::InvalidResponse) do
      pilot(->(_) { large.to_json }).call(purpose: "clarify", source_ids: [101, 102])
    end

    large["usage"]["cost_in_usd_ticks"] = 300_000
    large["usage"]["output_tokens"] = 401
    assert_raises(contract::InvalidResponse) do
      pilot(->(_) { large.to_json }).call(purpose: "clarify", source_ids: [101, 102])
    end
  end

  test "forged approval, cross-source claims and extra output fields are rejected" do
    %w[approved confirmed].each do |status|
      modified_proposal = payload
      modified_proposal["status"] = status
      assert_raises(contract::InvalidResponse) do
        pilot(->(_) { example_response(proposal: modified_proposal) })
          .call(purpose: "clarify", source_ids: [101, 102])
      end
    end

    wrong_sources = payload.merge("source_ids" => [999])
    assert_raises(contract::InvalidResponse) do
      pilot(->(_) { example_response(proposal: wrong_sources) })
        .call(purpose: "clarify", source_ids: [101, 102])
    end

    extra = payload.merge("price_approved" => true)
    assert_raises(contract::InvalidResponse) do
      pilot(->(_) { example_response(proposal: extra) })
        .call(purpose: "clarify", source_ids: [101, 102])
    end
  end

  test "foreign owner and revoked membership are denied before responder call" do
    calls = 0
    responder = ->(_) { calls += 1; example_response }
    assert_raises(SecurityError) do
      contract.new(actor: @outsider, workspace: @workspace, intake: @intake,
        response_adapter: responder)
    end

    client = pilot(responder)
    @workspace.workspace_memberships.find_by!(user: @owner).update!(status: "revoked")
    assert_raises(SecurityError) do
      client.call(purpose: "clarify", source_ids: [101, 102])
    end
    assert_equal 0, calls
  end

  test "production and non-synthetic admissions are blocked without an API call" do
    calls = 0
    responder = ->(_) { calls += 1; example_response }
    Rails.env.stub(:production?, true) do
      assert_raises(contract::Denied) { pilot(responder) }
    end
    assert_raises(contract::Denied) do
      pilot(responder).call(purpose: "clarify", data_class: "client", source_ids: [101, 102])
    end
    assert_raises(contract::Denied) do
      pilot(responder).call(purpose: "clarify", source_ids: ["untrusted"])
    end
    assert_raises(contract::Denied) do
      pilot(responder).call(purpose: "not_supported", source_ids: [101])
    end
    assert_equal 0, calls
  end

  private

  def contract
    Studio::AiProviders::XaiGrokMockContract
  end

  def pilot(responder)
    contract.new(actor: @owner, workspace: @workspace, intake: @intake,
      response_adapter: responder)
  end

  def payload
    { "source_ids" => [101, 102], "suggestions" => ["Ask about accepted browsers"],
      "unknowns" => ["Target browser versions"], "why_ask" => "Scope remains unclear",
      "confidence" => 0.6, "status" => "needs_human_review" }
  end

  def example_response(proposal: payload)
    { "model" => "grok-4.7",
      "usage" => { "input_tokens" => 180, "output_tokens" => 65, "cost_in_usd_ticks" => 300_000 },
      "output" => [{ "type" => "message",
        "content" => [{ "type" => "output_text", "text" => proposal.to_json }] }]
    }.to_json
  end
end
