require "test_helper"

class ProfessionalCapabilityCorrectionTest < ActiveSupport::TestCase
  setup do
    owner = User.create!(email: "capcorrection-model-owner@example.test", role: "owner",
                         password: "rc053-model-test-password-only")
    workspace = Workspace.create!(owner_user: owner)
    @profile = ProfessionalProfile.create!(workspace: workspace)
  end

  test "classification consistency and one correction per domain" do
    correction = @profile.professional_capability_corrections.build(
      domain: "react", base_snapshot_version: 1,
      delivery_mode: "direct", experience_claim: "new_to_me",
      willingness: "actively_offer", conditions: "not practiced"
    )
    assert_not correction.valid?
    correction.delivery_mode = "ai_assisted"
    correction.willingness = "consider"
    assert correction.valid?
    correction.save!
    duplicate = @profile.professional_capability_corrections.build(
      domain: "react", base_snapshot_version: 1,
      delivery_mode: "evaluate_first", experience_claim: "new_to_me", willingness: "consider"
    )
    assert_not duplicate.valid?
  end
end
