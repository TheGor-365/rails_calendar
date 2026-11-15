module OwnerServiceCatalogueTestData
  PASSWORD = "fictional-owner-services-browser-2026".freeze

  def make_test_owner(email)
    User.create!(email: email, role: "owner", password: PASSWORD)
  end

  def make_test_client(email)
    User.create!(
      email: email, role: "client", password: PASSWORD,
      email_verified_at: Time.current, signup_consent_at: Time.current,
      signup_policy_version: "fictional-offerings"
    )
  end

  def approved_profile_for(owner, version: 1, capabilities: %w[rails react])
    workspace = owner.owner_workspace || owner.create_owner_workspace!
    profile = workspace.professional_profile || workspace.create_professional_profile!(onboarding_state: "approved")
    profile.update!(onboarding_state: "approved")
    snapshot = profile.professional_context_snapshots.create!(
      version: version, digest: Digest::SHA256.hexdigest("fictional-offering-source-#{owner.id}-#{version}"),
      payload: { "source" => "owner_confirmed", "capabilities" => capabilities },
      approved_at: Time.current
    )
    rows = capabilities.map do |domain|
      assisted = domain != "rails"
      profile.professional_capabilities.create!(
        snapshot_version: version, domain: domain,
        delivery_mode: assisted ? "ai_assisted" : "direct",
        experience_claim: assisted ? "new_to_me" : "practiced",
        evidence_status: assisted ? "unverified" : "self_reported",
        willingness: assisted ? "consider" : "actively_offer",
        privacy_scope: "private", review_required: true,
        conditions: assisted ? "Fictional conditional work; review first" : "Fictional self-report"
      )
    end
    profile.work_policies.create!(
      snapshot_version: version, hard_no_go: %w[regulated security],
      work_preferences: %w[micro], notes: "Synthetic policy"
    )
    [workspace, profile, snapshot, rows]
  end

  def service_fields(capability, title: "Fix a fictional Rails error")
    {
      professional_capability_id: capability.id, project_category: "rails_bugfix",
      title: title,
      summary: "Review a fictional Rails 500 error and describe a bounded fix and test plan.",
      included_scope: "Reproduce one synthetic bug, implement one fix and a regression test.",
      excluded_scope: "No production access, permanent on-call support or unscoped redesign.",
      requirements_prompt: "Synthetic reproduction steps and expected vs actual response."
    }
  end
end
