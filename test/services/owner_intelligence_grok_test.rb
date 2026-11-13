require "test_helper"
require "json"

class OwnerIntelligenceGrokTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)
  FakeHttp = Struct.new(:response) do
    def request(_request)
      response
    end
  end

  setup do
    @owner = User.create!(email: "owner-grok-test@example.test", role: "owner",
                          password: "safe-test-only-profile-password")
    @workspace = Workspace.create!(owner_user: @owner)
    @profile = ProfessionalProfile.create!(workspace: @workspace)
    OwnerIntelligence::Catalog::KEYS.each do |key|
      @profile.owner_interview_answers.create!(
        section_key: key,
        selected_options: [OwnerIntelligence::Catalog.options_for(key).keys.first],
        notes: "Synthetic professional self-report for #{key}",
        unsure: false, revision: 1
      )
    end
  end

  test "paid Grok owner context is charged in existing ledger, cached and never a fake client request" do
    payload = {
      "headline" => "Ruby on Rails developer — self-reported",
      "private_summary" => "The owner reports Rails experience and assesses other work before making commitments.",
      "public_summary" => "Ruby on Rails development, with scoped project assessment.",
      "suggested_services" => ["Rails bug fixing"],
      "possible_stretch" => ["Review adjacent tasks before quoting"],
      "missing_facts" => ["Verify evidence links"],
      "risk_flags" => ["No independent verification yet"]
    }
    body = JSON.generate(
      "id" => "resp_synthetic_owner", "status" => "completed",
      "output" => [{ "type" => "message", "content" => [{ "type" => "output_text", "text" => JSON.generate(payload) }] }],
      "usage" => { "input_tokens" => 350, "output_tokens" => 125,
                   "cost_in_usd_ticks" => 2_400_000 }
    )
    calls = 0
    fake = ->(*_args, **_opts, &block) do
      calls += 1
      block.call(FakeHttp.new(FakeResponse.new("200", body)))
    end
    previous = %w[RC_GROK_ENABLED XAI_API_KEY].to_h { |key| [key, ENV[key]] }
    ENV["RC_GROK_ENABLED"] = "true"
    ENV["XAI_API_KEY"] = "xai-synthetic-not-real-secret-1234567890"
    Net::HTTP.stub(:start, fake) do
      assert_equal payload, OwnerIntelligence::Grok.new(@profile).suggest!
      assert_equal payload, OwnerIntelligence::Grok.new(@profile).suggest!
    end
    assert_equal 1, calls
    assert_equal 0, ProjectIntake.count
    assert_equal 1, AiSpendEntry.count
    entry = AiSpendEntry.first
    assert_nil entry.project_intake_id
    assert_equal @profile.id, entry.professional_profile_id
    assert_equal "settled", entry.status
    assert_equal 2_400_000, entry.charged_ticks
    assert_equal 1, IntakeAiQuota.sum(:call_count)
    assert @profile.reload.fresh_ai_suggestion?
    assert_equal payload, @profile.ai_suggestion
  ensure
    previous&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "unknown billing remains reserved and manual approval is still possible" do
    fp = Digest::SHA256.hexdigest("owner-timeout-test")
    entry, = AiSpendLedger.reserve!(
      professional_profile: @profile, operation: "owner_profile_summary_v1",
      model: "grok-4.3", request_digest: fp
    )
    AiSpendLedger.uncertain!(entry: entry)
    assert_equal "uncertain", entry.reload.status
    assert_raises(AiSpendLedger::ReplayBlocked) do
      AiSpendLedger.reserve!(professional_profile: @profile,
        operation: "owner_profile_summary_v1", model: "grok-4.3", request_digest: fp)
    end
    assert_equal 1_000_000_000, AiSpendLedger.spend_summary[:held_ticks]
  end
end
