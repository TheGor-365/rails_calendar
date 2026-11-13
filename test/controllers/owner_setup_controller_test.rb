require "test_helper"

class OwnerSetupControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "owner-profile-test-password-2026".freeze

  setup do
    @owner = User.create!(email: "owner-setup@example.test", role: "owner", password: PASSWORD)
    @client = User.create!(email: "owner-setup-client@example.test", role: "client", password: PASSWORD,
                           email_verified_at: Time.current, signup_consent_at: Time.current,
                           signup_policy_version: "test-2026")
  end

  def login_as(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_response :redirect
  end

  def complete_interview
    samples = {
      "A" => %w[rails_bugfix rails_api adjacent_web],
      "B" => %w[ruby rails postgresql testing],
      "C" => %w[react nextjs],
      "D" => %w[regulated security],
      "E" => %w[micro remote learn_before_quote],
      "F" => %w[github certificates]
    }
    samples.each do |key, values|
      patch owner_setup_section_path(section_key: key), params: {
        owner_answer: { selected_options: values, notes: "Synthetic owner statement #{key}",
                        unsure: "0" }
      }
      assert_response :redirect
    end
    samples
  end

  test "anonymous and verified clients cannot view or mutate private owner context" do
    get owner_setup_path
    assert_redirected_to sign_in_path
    get owner_practice_path
    assert_redirected_to sign_in_path
    post owner_setup_suggest_path, params: { ai_consent: "1" }
    assert_redirected_to sign_in_path
    assert_equal 0, Workspace.count

    login_as(@client)
    get owner_setup_path
    assert_redirected_to sign_in_path
    get owner_setup_review_path
    assert_redirected_to sign_in_path
    get owner_practice_path
    assert_redirected_to sign_in_path
    get owner_ai_activity_path
    assert_redirected_to sign_in_path
    patch owner_setup_section_path(section_key: "A"), params: {
      owner_answer: { selected_options: ["rails_bugfix"], notes: "Forbidden" }
    }
    assert_redirected_to sign_in_path
    post owner_setup_approve_path, params: { confirmation: "1" }
    assert_redirected_to sign_in_path
    assert_equal 0, ProfessionalProfile.count
  end

  test "owner can resume six cards, edits create revision, approves v1 and later v2" do
    login_as(@owner)
    get workspace_path
    assert_response :success
    assert_select "a[href=?]", owner_setup_path

    get owner_setup_path
    assert_response :success
    assert_select "#owner-setup h1", text: I18n.t("owner_setup.title")
    assert_select "form[action=?]", owner_setup_section_path(section_key: "A")
    assert_equal 1, Workspace.count

    patch owner_setup_section_path(section_key: "A"), params: {
      owner_answer: { selected_options: %w[rails_bugfix adjacent_web],
                      notes: "Small Rails bugs and adjacent work", unsure: "0" }
    }
    assert_redirected_to owner_setup_path(step: "B")
    get owner_setup_path
    assert_response :success
    assert_select "form[action=?]", owner_setup_section_path(section_key: "B")
    profile = @owner.reload.owner_workspace.professional_profile
    answer = profile.owner_interview_answers.find_by!(section_key: "A")
    assert_equal 1, answer.revision

    patch owner_setup_section_path(section_key: "A"), params: {
      owner_answer: { selected_options: %w[rails_bugfix adjacent_web],
                      notes: "Small Rails bugs and adjacent work", unsure: "0" }
    }
    assert_equal 1, answer.reload.revision

    patch owner_setup_section_path(section_key: "A"), params: {
      owner_answer: { selected_options: %w[rails_bugfix adjacent_web],
                      notes: "Rails first; assess adjacent stack", unsure: "0" }
    }
    assert_equal 2, answer.reload.revision
    assert_equal 2, answer.owner_interview_answer_revisions.count

    samples = complete_interview
    get owner_setup_review_path
    assert_response :success
    assert_select "form[action=?]", owner_setup_approve_path
    assert_select "form[action=?]", owner_setup_suggest_path, count: 0

    assert_difference({ "ProfessionalContextSnapshot.count" => 1,
                        "ProfessionalCapability.count" => 6,
                        "WorkPolicy.count" => 1 }) do
      post owner_setup_approve_path, params: {
        professional_profile: {
          headline: "Ruby on Rails developer",
          private_summary: "Rails bugs, PostgreSQL and API work with scoped adjacent experiments",
          public_summary: "Rails development and assessed adjacent web projects"
        }, confirmation: "1"
      }
    end
    assert_redirected_to owner_practice_path
    v1 = profile.reload.approved_snapshot
    assert_equal 1, v1.version
    assert_equal "owner_confirmed", v1.payload.fetch("source")
    assert_equal samples["C"], v1.payload.fetch("capabilities").select { |c| c["delivery_mode"] == "ai_assisted" }.map { |c| c["domain"] }
    assert v1.payload.fetch("capabilities").all? { |c| c["review_required"] }
    assert_equal %w[regulated security], profile.work_policies.find_by!(snapshot_version: 1).hard_no_go
    assert profile.professional_capabilities.where(snapshot_version: 1, domain: "react", delivery_mode: "ai_assisted").exists?

    get owner_practice_path
    assert_response :success
    assert_select "#owner-practice", count: 1
    assert_select "a[href=?]", owner_setup_path(step: "A")
    get services_path
    assert_response :success
    assert_no_match(/Rails development and assessed adjacent web projects/, response.body)

    patch owner_setup_section_path(section_key: "C"), params: {
      owner_answer: { selected_options: ["vue"], notes: "Prefer Vue trials", unsure: "0" }
    }
    assert_equal "draft", profile.reload.onboarding_state
    assert_equal 1, profile.approved_snapshot.version
    assert_equal "react", v1.reload.payload.fetch("capabilities").find { |c| c["delivery_mode"] == "ai_assisted" }.fetch("domain")

    post owner_setup_approve_path, params: {
      professional_profile: { headline: "Ruby and Rails development",
        private_summary: "Rails delivery plus carefully scoped Vue experiments",
        public_summary: "Rails-focused development" }, confirmation: "1"
    }
    assert_redirected_to owner_practice_path
    assert_equal 2, profile.reload.approved_snapshot.version
    assert_equal 2, ProfessionalContextSnapshot.where(professional_profile: profile).count
    assert_equal ["vue"], profile.approved_snapshot.payload.fetch("capabilities").select { |c| c["delivery_mode"] == "ai_assisted" }.map { |c| c["domain"] }
    assert_equal samples["C"], v1.reload.payload.fetch("capabilities").select { |c| c["delivery_mode"] == "ai_assisted" }.map { |c| c["domain"] }
  end

  test "owner cannot publish incomplete profile and never publishes through /services" do
    login_as(@owner)
    post owner_setup_approve_path, params: { professional_profile: {
      headline: "Ruby on Rails", private_summary: "This is an incomplete draft" }, confirmation: "1" }
    assert_redirected_to owner_setup_path
    assert_equal 0, ProfessionalContextSnapshot.count

    patch owner_setup_section_path(section_key: "B"), params: {
      owner_answer: { selected_options: ["invented_technology"], notes: "No", unsure: "0" }
    }
    assert_redirected_to owner_setup_path(step: "B")
    assert_equal 0, OwnerInterviewAnswer.count
  end
end
