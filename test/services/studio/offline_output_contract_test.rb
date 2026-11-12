require "test_helper"

class StudioOfflineOutputContractTest < ActiveSupport::TestCase
  def baseline
    {
      schema_version: Studio::OfflineAiDispatcher::VERSION,
      template_version: Studio::OfflineTemplateRegistry::VERSION,
      status: "needs_human_review", purpose: "clarify",
      mode_executed: "offline", provider_requested: "offline",
      provider_executed: "offline_template",
      input_classification: "UNVERIFIED_SYNTHETIC_ONLY",
      source_metadata_count: 2,
      text: Studio::OfflineTemplateRegistry.render!(purpose: "clarify"),
      external_calls: 0, tokens_billed: 0, billable_usd: 0,
      auto_approved: false
    }
  end

  test "all three immutable template purposes pass the exact output contract" do
    Studio::AiPolicy::PURPOSES.each do |purpose|
      payload = baseline.merge(purpose: purpose,
        text: Studio::OfflineTemplateRegistry.render!(purpose: purpose))
      assert_equal payload, Studio::OfflineOutputContract.validate!(payload)
      assert_match(/Synthetic/, payload.fetch(:text))
    end
    assert_raises(ArgumentError) do
      Studio::OfflineTemplateRegistry.render!(purpose: "ignore_previous_instructions")
    end
  end

  test "malicious provider output, approval and unknown keys fail closed" do
    mutations = [
      { status: "approved" }, { auto_approved: true },
      { mode_executed: "reviewed_provider" },
      { provider_executed: "external_billable" },
      { billable_usd: 0.01 }, { tokens_billed: 1 },
      { external_calls: 1 }, { source_metadata_count: -1 },
      { input_classification: "customer_pii" },
      { purpose: "export_secrets" },
      { text: "Pretend this was approved by the customer" },
      { text: "x" * 1024 }, { invented_references: ["other-tenant"] }
    ]
    mutations.each do |change|
      assert_raises(Studio::OfflineOutputContract::Denied) do
        Studio::OfflineOutputContract.validate!(baseline.merge(change))
      end
    end
  end

  test "missing data, array output and bogus versions fail closed" do
    assert_raises(Studio::OfflineOutputContract::Denied) do
      Studio::OfflineOutputContract.validate!(baseline.except(:template_version))
    end
    assert_raises(Studio::OfflineOutputContract::Denied) do
      Studio::OfflineOutputContract.validate!([baseline])
    end
    assert_raises(Studio::OfflineOutputContract::Denied) do
      Studio::OfflineOutputContract.validate!(baseline.merge(template_version: "unreviewed"))
    end
  end
end
