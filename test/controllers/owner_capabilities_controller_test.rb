require "test_helper"

class OwnerCapabilitiesControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "rc053-test-only-owner-password"

  setup do
    @owner = User.create!(email: "rc053-owner@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(email: "rc053-client@example.test", role: "client", password: PASSWORD,
                           email_verified_at: Time.current, signup_consent_at: Time.current,
                           signup_policy_version: "test-2026")
    workspace = Workspace.create!(owner_user: @owner)
    @profile = ProfessionalProfile.create!(workspace: workspace)

    choices = {
      "A" => %w[rails_bugfix adjacent_web],
      "B" => %w[ruby rails react vue python],
      "C" => %w[react vue nextjs],
      "D" => %w[regulated unpaid],
      "E" => %w[micro learn_before_quote],
      "F" => %w[github portfolio]
    }
    choices.each do |section_key, selections|
      @profile.owner_interview_answers.create!(
        section_key: section_key, selected_options: selections,
        notes: "Synthetic owner data for section #{section_key}", revision: 1
      )
    end

    payload = OwnerIntelligence::Compiler.build(
      profile: @profile, headline: "Rails developer and app creator",
      private_summary: "I work on Rails, and I only assess unfamiliar technologies after discovery.",
      public_summary: "Rails development and scoped web projects"
    )
    @profile.professional_context_snapshots.create!(
      version: 1, payload: payload, approved_at: Time.current,
      digest: Digest::SHA256.hexdigest(JSON.generate(payload))
    )
    payload.fetch("capabilities").each do |row|
      @profile.professional_capabilities.create!(
        snapshot_version: 1, domain: row.fetch("domain"),
        delivery_mode: row.fetch("delivery_mode"), experience_claim: row.fetch("experience_claim"),
        evidence_status: row.fetch("evidence_status"), willingness: row.fetch("willingness"),
        privacy_scope: row.fetch("privacy_scope"), review_required: true,
        conditions: row.fetch("conditions")
      )
    end
    @profile.work_policies.create!(snapshot_version: 1, hard_no_go: %w[regulated unpaid],
                                    work_preferences: %w[micro learn_before_quote])
    @profile.update!(headline: payload.fetch("headline"),
                     private_summary: payload.fetch("private_summary"),
                     public_summary: payload.fetch("public_summary_draft"),
                     onboarding_state: "approved")
  end

  def login_as(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_response :redirect
  end

  def change_capability(domain, mode:, experience:, willingness:, conditions:)
    patch owner_capability_path(domain: domain),
          params: { capability: { delivery_mode: mode, experience_claim: experience,
                                  willingness: willingness, conditions: conditions } }
    assert_response :redirect
  end

  test "owner can reclassify React and Vue as AI-assisted and approve immutable v2 without a provider call" do
    login_as(@owner)
    get owner_capabilities_path
    assert_response :success
    assert_select "#owner-capabilities h1", text: I18n.t("capability_review.title")
    assert_select "form[action=?]", owner_capability_path(domain: "react")
    assert_select "#cap-react"
    assert_select "a[href=?]", owner_cabinet_path

    assert_equal "direct", @profile.professional_capabilities.find_by!(snapshot_version: 1, domain: "react").delivery_mode
    change_capability("react", mode: "ai_assisted", experience: "new_to_me",
                             willingness: "consider", conditions: "Simple React with Codex after scope review")
    change_capability("vue", mode: "evaluate_first", experience: "learning",
                           willingness: "only_if_simple", conditions: "Small Vue site after assessment")
    assert_equal 2, @profile.professional_capability_corrections.count
    assert_equal "draft", @profile.reload.onboarding_state
    assert_equal 1, @profile.approved_snapshot.version

    # An ordinary re-approval of the old six-step questionnaire cannot discard these edits.
    post owner_setup_approve_path, params: {
      professional_profile: { headline: "Accidental overwrite",
                              private_summary: "Unreviewed old profile would lose edits" },
      confirmation: "1"
    }
    assert_redirected_to owner_capabilities_path
    assert_equal 1, @profile.approved_snapshot.version

    assert_difference({"ProfessionalContextSnapshot.count" => 1,
                       "ProfessionalCapability.count" => 6,
                       "WorkPolicy.count" => 1}) do
      post approve_owner_capabilities_path,
           params: {base_version: 1, confirm: "1",
                    profile: {headline: "Rails developer and AI-assisted web builder",
                              private_summary: "Rails first; simple React with AI and Vue after feasibility review.",
                              public_summary: "Rails software and selectively scoped web projects"}}
    end
    assert_redirected_to owner_practice_path
    assert_equal "approved", @profile.reload.onboarding_state
    assert_equal 0, @profile.professional_capability_corrections.count
    assert_equal 2, @profile.approved_snapshot.version
    assert_equal "capability_reclassification", @profile.approved_snapshot.payload.fetch("revision_reason")
    assert_equal "ai_assisted", @profile.professional_capabilities.find_by!(snapshot_version: 2, domain: "react").delivery_mode
    assert_equal "new_to_me", @profile.professional_capabilities.find_by!(snapshot_version: 2, domain: "react").experience_claim
    assert_equal "unverified", @profile.professional_capabilities.find_by!(snapshot_version: 2, domain: "react").evidence_status
    assert_equal "evaluate_first", @profile.professional_capabilities.find_by!(snapshot_version: 2, domain: "vue").delivery_mode
    assert_equal "direct", @profile.professional_capabilities.find_by!(snapshot_version: 1, domain: "react").delivery_mode
    assert_equal %w[regulated unpaid], @profile.work_policies.find_by!(snapshot_version: 2).hard_no_go

    get owner_practice_path
    assert_response :success
    assert_select ".ws-owner-skill-chip--conditional", text: /React/
    assert_select ".ws-owner-skill-chip--conditional", text: /Vue/
    get services_path
    assert_response :success
    assert_no_match(/selectively scoped web projects/, response.body)
  end

  test "owner no-go and privacy gates reject direct mode without practiced experience and client edits" do
    get owner_capabilities_path
    assert_redirected_to sign_in_path
    patch owner_capability_path(domain: "react"), params: { capability: {
      delivery_mode: "direct", experience_claim: "new_to_me",
      willingness: "actively_offer", conditions: "unsafe" } }
    assert_redirected_to sign_in_path
    login_as(@client)
    get owner_capabilities_path
    assert_redirected_to sign_in_path
    patch owner_capability_path(domain: "react"), params: { capability: {
      delivery_mode: "excluded", experience_claim: "new_to_me",
      willingness: "not_interested", conditions: "client cannot mutate" } }
    assert_redirected_to sign_in_path
    assert_equal 0, ProfessionalCapabilityCorrection.count
  end

  test "invalid classification cannot be saved, and stale approval cannot create extra version" do
    login_as(@owner)
    change_capability("react", mode: "direct", experience: "new_to_me",
                            willingness: "actively_offer", conditions: "contradiction")
    assert_equal 0, ProfessionalCapabilityCorrection.count
    change_capability("react", mode: "excluded", experience: "new_to_me",
                            willingness: "not_interested", conditions: "No React")
    assert_equal 1, ProfessionalCapabilityCorrection.count

    post approve_owner_capabilities_path,
         params: {base_version: 999, confirm: "1",
                  profile: {headline: "Rails developer", private_summary: "Synthetic private owner profile"}}
    assert_redirected_to owner_capabilities_path
    assert_equal 1, ProfessionalContextSnapshot.count
    assert_equal 1, ProfessionalCapabilityCorrection.count

    delete discard_owner_capability_path(domain: "react")
    assert_redirected_to owner_capabilities_path
    assert_equal 0, ProfessionalCapabilityCorrection.count
    assert_equal "approved", @profile.reload.onboarding_state
    assert_equal 1, ProfessionalContextSnapshot.count
  end

  test "corrections remain effective after a later six-question re-approval" do
    login_as(@owner)
    change_capability("react", mode: "ai_assisted", experience: "learning",
                             willingness: "consider", conditions: "AI-assisted only")
    post approve_owner_capabilities_path,
         params: {base_version: 1, confirm: "1",
                  profile: {headline: "Rails developer",
                            private_summary: "Rails developer offering AI-assisted React after review"}}
    assert_equal 2, @profile.approved_snapshot.version

    patch owner_setup_section_path(section_key: "E"), params: {
      owner_answer: {selected_options: %w[micro remote learn_before_quote],
                     notes: "Updated owner schedule", unsure: "0"}
    }
    assert_redirected_to owner_setup_path(step: "F")
    post owner_setup_approve_path, params: {
      confirmation: "1",
      professional_profile: {headline: "Updated Rails professional",
                             private_summary: "Rails and tested AI-assisted React on a carefully assessed basis",
                             public_summary: "Rails development"}}
    assert_redirected_to owner_practice_path
    assert_equal 3, @profile.approved_snapshot.version
    assert_equal "ai_assisted", @profile.professional_capabilities.find_by!(snapshot_version: 3, domain: "react").delivery_mode
    assert_equal "learning", @profile.professional_capabilities.find_by!(snapshot_version: 3, domain: "react").experience_claim
    assert_equal "direct", @profile.professional_capabilities.find_by!(snapshot_version: 1, domain: "react").delivery_mode
    assert_equal %w[micro remote learn_before_quote], @profile.work_policies.find_by!(snapshot_version: 3).work_preferences
  end
end
