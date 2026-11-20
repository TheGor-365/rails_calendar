require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"
require "uri"

class E2ClientInvitationTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @prior_pilot = ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"]
    @prior_ai = ENV["RC_GROK_ENABLED"]
    ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = "true"
    ENV["RC_GROK_ENABLED"] = "false"
    @owner = make_test_owner("e2-own-#{SecureRandom.hex(5)}@example.test")
    @owner_b = make_test_owner("e2-other-#{SecureRandom.hex(5)}@example.test")
    @client = make_test_client("e2-client-#{SecureRandom.hex(5)}@example.test")
    @client_b = make_test_client("e2-other-client-#{SecureRandom.hex(5)}@example.test")
    @workspace, _, _, caps = approved_profile_for(@owner)
    @workspace_b, _, _, = approved_profile_for(@owner_b)
    @offering = published_service(@workspace, caps.first)
    @seed = "Owner's unverified confidential synthetic requirements for a Rails form."
  end

  teardown do
    @prior_pilot.nil? ? ENV.delete("RC_LOCAL_CLIENT_REQUESTS_ENABLED") : ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] = @prior_pilot
    @prior_ai.nil? ? ENV.delete("RC_GROK_ENABLED") : ENV["RC_GROK_ENABLED"] = @prior_ai
  end

  test "owner can locate sent invitations in workspace, inbox and cabinet without a guessed URL" do
    login(@owner)
    issue_invitation
    invitation = @workspace.client_request_invitations.order(:id).last
    assert invitation

    get workspace_path
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), minimum: 1
    assert_select "a[href=?]", owner_invitations_path(anchor: "invitation-history"), minimum: 1

    get admin_project_intakes_path
    assert_response :success
    assert_select "h1", text: "Requests"
    assert_select "[data-controller='wa-requests']", count: 1
    assert_select "button[role='tab'][data-view='incoming'][aria-selected='true']", count: 1
    assert_select "button[role='tab'][data-view='outgoing'][aria-selected='false']", count: 1
    assert_select "#wa-requests-outgoing[hidden] details", minimum: 1
    assert_select "#wa-requests-outgoing a[href=?]", owner_invitation_path(invitation), minimum: 1

    get owner_cabinet_path
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), minimum: 1

    get owner_artifacts_path
    assert_response :success
    assert_select "a[href=?]", export_owner_artifact_path(kind: "invitation", id: invitation.id), minimum: 1
    get export_owner_artifact_path(kind: "invitation", id: invitation.id)
    assert_response :success
    assert_equal "text/plain", response.media_type
    archive = JSON.parse(response.body)
    assert_equal invitation.seed_title, archive.fetch("title")
    assert_equal "invitation", archive.fetch("type")
    refute archive.key?("token_digest")


    get root_path(start_date: invitation.created_at.in_time_zone.to_date.iso8601)
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), minimum: 1

    get calendar_day_path(date: invitation.created_at.in_time_zone.to_date.iso8601)
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), minimum: 1

    sign_out
    login(@owner_b)
    get workspace_path
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), count: 0
    get owner_artifacts_path
    assert_response :success
    assert_select "a[href=?]", export_owner_artifact_path(kind: "invitation", id: invitation.id), count: 0
    get export_owner_artifact_path(kind: "invitation", id: invitation.id)
    assert_response :not_found
    get calendar_day_path(date: invitation.created_at.in_time_zone.to_date.iso8601)
    assert_response :success
    assert_select "a[href=?]", owner_invitation_path(invitation), count: 0
  end

  test "owner invitation is scoped, one-time digest only and never lists another owner seed" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.order(:id).last
    assert_equal @workspace, invitation.workspace
    assert_equal 64, raw.length
    assert_equal ClientRequestInvitation.digest_for(raw), invitation.token_digest
    refute_equal raw, invitation.token_digest
    assert_equal :invited, invitation.state
    get owner_invitations_path
    assert_response :success
    assert_select "section.wa-invite-compose form[data-controller~='wa-invitation-brief']", count: 1
    assert_select "input[data-wa-invitation-brief-target='service'][data-wa-service-search]", minimum: 1
    assert_select "#e2-invite-link", count: 0 # link available only immediately after issue
    sign_out
    login(@owner_b)
    get owner_invitations_path
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(invitation.seed_title)}/, count: 0
    post revoke_owner_invitation_path(invitation)
    assert_response :not_found
  end

  test "JSON invitation issuance keeps the page and exposes one-time token only once" do
    login(@owner)
    assert_difference("ClientRequestInvitation.count", 1) do
      post owner_invitations_path, as: :json, params: {
        proposal: proposal.merge(
          brief_selections: { tasks: ["bugfix"] },
          approved_client_preview: "Please check when the fictional contact form fails.",
          share_preview: "1"
        ), service_version_ids: [@offering.published_version_id]
      }
      assert_response :created
      assert_equal "no-store", response.headers["Cache-Control"]
    end

    invitation = ClientRequestInvitation.order(:id).last
    data = response.parsed_body
    assert_equal invitation.id, data.fetch("invitation_id")
    assert_match(/token=[0-9a-f]{64}\z/, data.fetch("url"))
    assert_equal "Please check when the fictional contact form fails.", invitation.approved_client_preview

    get owner_invitation_path(invitation)
    assert_response :success
    assert_select ".wa-invite-owner-artifact__text", text: /fictional contact form/
    assert_select "footer.wa-invite-artifact-tools", count: 1
    assert_select "footer.wa-invite-artifact-tools a[href=?]", owner_invitation_path(invitation, format: :json)
    assert_select "details.wa-invite-artifact-recover", count: 0
    get owner_invitation_path(invitation, format: :json)
    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    export = JSON.parse(response.body)
    assert_nil export["token"]
    assert_equal invitation.seed_title, export["title"]
    assert_equal invitation.approved_client_preview, export["approved_client_preview"]

    sign_out
    post client_invitation_preview_path, params: { invite_token: URI(data.fetch("url")).fragment.delete_prefix("token=") }
    assert_redirected_to client_invitation_preview_path
    get client_invitation_preview_path
    assert_response :success
    assert_select "body", text: /Please check when the fictional contact form fails/
    assert_select "body", text: /Owner's unverified confidential synthetic requirements/, count: 0

    login(@client)
    assert_redirected_to client_invitation_preview_path
    post claim_client_invitation_path
    intake = @client.client_project_intakes.order(:id).last
    assert intake
    assert_equal "Please check when the fictional contact form fails.", intake.goal
    assert_equal @seed, invitation.reload.seed_goal

    get owner_invitation_path(invitation)
    assert_redirected_to sign_in_path
    get owner_invitation_path(invitation, format: :json)
    assert_redirected_to sign_in_path
  end

  test "owner can reuse a revoked invitation's structured brief without reviving its token" do
    login(@owner)
    raw = issue_invitation
    source = ClientRequestInvitation.order(:id).last
    source.update!(brief_decisions: { "deployment" => "client" })
    post revoke_owner_invitation_path(source)
    assert_redirected_to owner_invitations_path
    assert_equal :revoked, source.reload.state

    assert_no_difference("ClientRequestInvitation.count") do
      get owner_invitations_path(from_invitation_id: source.id)
      assert_response :success
      assert_select "input#proposal_seed_title[value=?]", source.seed_title
      assert_select "textarea#proposal_seed_goal", text: source.seed_goal
      assert_select "input[name='proposal[brief_selections][tasks][]'][value='bugfix'][checked]"
      assert_select "select[name='proposal[brief_decisions][deployment]'] option[value='client'][selected]"
      assert_select "input#proposal_owner_ai_entry_id"
      assert_select ".wa-invite-issued[hidden]", count: 1
    end
    assert_equal :revoked, source.reload.state
    assert_equal ClientRequestInvitation.digest_for(raw), source.token_digest

    sign_out
    login(@owner_b)
    get owner_invitations_path(from_invitation_id: source.id)
    assert_response :not_found
    get owner_invitations_path(from_invitation_id: "invalid")
    assert_response :not_found
  end

  test "reused invitation shows saved AI draft but does not publish client preview or generate again" do
    login(@owner)
    issue_invitation
    source = ClientRequestInvitation.order(:id).last
    entry = AiSpendEntry.create!(
      professional_profile: @workspace.professional_profile,
      operation: OwnerAi::Composer::VERSION, model: "test-only-local",
      request_digest: Digest::SHA256.hexdigest(SecureRandom.hex(16)),
      status: "settled", reserved_ticks: 0, charged_ticks: 0,
      result: {
        "purpose" => "intake_questions",
        "heading" => "Questions for a fictional client",
        "draft" => "Please describe when the contact form stops working.",
        "questions" => ["What happens when you submit the form?"],
        "cautions" => ["Do not send private data."],
        "next_step" => "Review questions before sharing."
      }
    )
    source.update!(owner_ai_entry: entry)
    assert_no_difference(["AiSpendEntry.count", "ClientRequestInvitation.count"]) do
      get owner_invitations_path(from_invitation_id: source.id)
      assert_response :success
      assert_select ".wa-invite-ai__result:not([hidden])", count: 1
      assert_select "[data-wa-invitation-ai-target='heading']", text: /Questions for a fictional client/
      assert_select "[data-wa-invitation-ai-target='draft']", text: /contact form stops working/
      assert_select "[data-wa-invitation-ai-target='questions'] li", text: /submit the form/
      assert_select "textarea#proposal_approved_client_preview", text: "", count: 1
      assert_select "input#proposal_share_preview:not([checked])", count: 1
      assert_select "input#proposal_owner_ai_entry_id[value=?]", entry.id.to_s
    end
    assert_nil source.reload.approved_client_preview
    sign_out
    login(@owner_b)
    get owner_invitations_path(from_invitation_id: source.id)
    assert_response :not_found
  end

  test "only the owner can link an existing private AI record" do
    login(@owner)
    post owner_invitations_path, as: :json, params: {
      proposal: proposal, service_version_ids: []
    }
    assert_response :created
    invitation = ClientRequestInvitation.order(:id).last
    assert_nil invitation.owner_ai_entry_id

    patch attach_owner_invitation_ai_draft_path(invitation), params: { entry_id: 987_654_321 }
    assert_response :not_found
    assert_nil invitation.reload.owner_ai_entry_id

    sign_out
    login(@owner_b)
    get owner_invitation_path(invitation)
    assert_response :not_found
    patch attach_owner_invitation_ai_draft_path(invitation), params: { entry_id: 987_654_321 }
    assert_response :not_found
  end

  test "guest sees no extra preview text unless explicitly shared" do
    login(@owner)
    post owner_invitations_path, as: :json, params: {
      proposal: proposal.merge(approved_client_preview: "Owner-only draft should stay private.", share_preview: "0"),
      service_version_ids: []
    }
    assert_response :created
    assert_nil ClientRequestInvitation.last.approved_client_preview
    raw = URI(response.parsed_body.fetch("url")).fragment.delete_prefix("token=")
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw }
    get client_invitation_preview_path
    assert_response :success
    assert_select "body", text: /Owner-only draft should stay private/, count: 0
  end

  test "guest sees public preview only; verified claim leads to one editable canonical intake" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.order(:id).last
    sign_out

    assert_no_difference("ProjectIntake.count") do
      get client_invitation_path
      assert_response :success
      assert_select "form[action=?]", client_invitation_preview_path
      post client_invitation_preview_path, params: { invite_token: raw }
      assert_redirected_to client_invitation_preview_path
      get client_invitation_preview_path
      assert_response :success
      assert_select "body", text: /#{Regexp.escape(@seed)}/, count: 0
      assert_select "body", text: /#{Regexp.escape(@offering.published_version.title)}/
    end

    login(@client)
    assert_redirected_to client_invitation_preview_path
    get client_invitation_preview_path
    assert_response :success
    assert_select "form[action=?]", claim_client_invitation_path do
      assert_select "input[name='demo_consent']", count: 0
      assert_select "button[type='submit']", text: /Start my project request/
    end
    assert_difference("ProjectIntake.count", 1) do
      assert_difference("IntakeServiceSelection.count", 1) do
        post claim_client_invitation_path
      end
    end
    intake = @client.client_project_intakes.last
    assert_redirected_to edit_client_request_path(intake)
    assert_equal @workspace.id, intake.workspace_id
    assert_equal [@offering.published_version_id], intake.selected_service_offering_versions.pluck(:id)
    assert_equal 0, intake.client_message_count
    get client_home_path
    assert_response :success
    assert_select "a[href=?]", edit_client_request_path(intake), minimum: 1
    assert_select "a[href=?]", client_request_path(intake), count: 0
    assert_select ".wa-client-home__request .rc-status-pill", text: /#{Regexp.escape(I18n.t("e2_resume.draft", locale: :en))}/
    assert_equal 1, intake.intake_brief_revisions.count
    owner_brief = intake.latest_brief_revision
    assert_equal "owner", owner_brief.author_role
    assert_equal({ "tasks" => %w[bugfix tests], "backend" => ["rails"] }, owner_brief.selections)
    assert_equal({ "deployment" => "client" }, owner_brief.decisions)
    assert_equal "Synthetic test job", owner_brief.notes
    client_prompt = IntakeBrief::PromptContext.new(revision: owner_brief, audience: "client", locale: :ru).as_json
    owner_prompt = IntakeBrief::PromptContext.new(revision: owner_brief, audience: "owner", locale: :en).as_json
    assert_equal "client", client_prompt.fetch("audience")
    assert client_prompt.fetch("sections").first.fetch("choices").first.fetch("plain_explanation").present?
    refute owner_prompt.fetch("sections").first.fetch("choices").first.key?("plain_explanation")
    refute_includes client_prompt.to_s, invitation.token_digest
    assert_equal @client.id, invitation.reload.claimed_by_user_id
    assert_equal intake.id, invitation.project_intake_id
    get client_invitation_preview_path
    assert_response :success
    assert_select "a[href=?]", edit_client_request_path(intake)

    assert_no_difference("ProjectIntake.count") do
      post claim_client_invitation_path
      assert_redirected_to edit_client_request_path(intake)
    end
    assert_no_difference("IntakeMessage.count") do
      post submit_client_request_path(intake)
      assert_response :unprocessable_entity
    end
    patch client_request_path(intake), params: {
      project_intake: {
        title: "Client revised the test task", project_type: "rails_bugfix",
        goal: "Client now requests a synthetic form with two named acceptance scenarios."
      },
      fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
      brief: {
        selections: { tasks: ["bugfix"], backend: ["rails"], frontend: ["bootstrap"] },
        decisions: { deployment: "owner" }, notes: "Please improve the mobile form first."
      }
    }
    assert_redirected_to edit_client_request_path(intake)
    assert_equal 2, intake.intake_brief_revisions.count
    assert_equal "client", intake.latest_brief_revision.author_role
    assert_equal({ "frontend" => ["bootstrap"] }, intake.latest_brief_revision.selections.slice("frontend"))
    assert_equal({ "deployment" => "owner" }, intake.latest_brief_revision.decisions)
    assert_equal "owner", intake.intake_brief_revisions.find_by!(version: 1).author_role
    assert_equal %w[bugfix tests], intake.intake_brief_revisions.find_by!(version: 1).selections.fetch("tasks")
    assert_no_difference("IntakeBriefRevision.count") do
      patch client_request_path(intake), params: {
        project_intake: { title: "Client revised the test task", project_type: "rails_bugfix",
          goal: "Client now requests a synthetic form with two named acceptance scenarios." },
        fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
        brief: {
          selections: { tasks: ["bugfix"], backend: ["rails"], frontend: ["bootstrap"] },
          decisions: { deployment: "owner" }, notes: "Please improve the mobile form first."
        }
      }
      assert_redirected_to edit_client_request_path(intake)
    end
    assert_equal "Client revised the test task", intake.reload.title
    assert_equal @seed, invitation.reload.seed_goal
    assert_equal "unknown", invitation.fact_state("goal")
    assert_equal "confirmed", invitation.fact_state("title")

    assert_difference("IntakeMessage.count", 2) do
      post submit_client_request_path(intake)
    end
    assert_redirected_to client_request_path(intake)
    assert invitation.reload.submitted_at.present?
    get client_home_path
    assert_response :success
    assert_select "a[href=?]", client_request_path(intake), minimum: 1
    assert_select "a[href=?]", edit_client_request_path(intake), count: 0
    assert_equal 1, intake.client_message_count
    assert_no_difference("IntakeMessage.count") { post submit_client_request_path(intake) }
  end

  test "client discovery saves twelve editable sections as immutable versions without provider calls" do
    login(@owner)
    raw = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw }
    login(@client)
    post claim_client_invitation_path
    intake = @client.client_project_intakes.last
    assert intake

    get edit_client_request_path(intake)
    assert_response :success
    assert_select ".wa-scope__section", count: 12
    assert_select "textarea[name='scope[business_goal][text]']", count: 1
    assert_select "select[name='scope[estimate][responsibility]']", count: 1

    payload = {
      project_intake: { title: intake.title, project_type: intake.project_type,
                        goal: intake.goal },
      fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
      scope: {
        business_goal: { text: "A form sends a confirmation message.", status: "confirmed", responsibility: "client" },
        data: { text: "", status: "unknown", responsibility: "owner" }
      }
    }
    assert_no_difference("AiSpendEntry.count") do
      assert_difference("IntakeScopeRevision.count", 1) do
        patch client_request_path(intake), params: payload
        assert_redirected_to edit_client_request_path(intake)
      end
    end
    first = intake.latest_scope_revision
    assert_equal 1, first.version
    assert_equal "client", first.author_role
    assert_equal "owner", first.answers.fetch("data").fetch("responsibility")
    assert first.readonly?

    assert_no_difference("IntakeScopeRevision.count") do
      patch client_request_path(intake), params: payload
      assert_redirected_to edit_client_request_path(intake)
    end

    payload[:scope][:business_goal][:text] = "The form confirms delivery and saves a record."
    assert_difference("IntakeScopeRevision.count", 1) do
      patch client_request_path(intake), params: payload
      assert_redirected_to edit_client_request_path(intake)
    end
    assert_equal 2, intake.latest_scope_revision.version
    assert_equal "A form sends a confirmation message.",
      intake.intake_scope_revisions.find_by!(version: 1).answers.fetch("business_goal").fetch("text")

    payload[:scope][:rogue_admin] = { text: "hidden", status: "confirmed", responsibility: "client" }
    assert_no_difference("IntakeScopeRevision.count") do
      patch client_request_path(intake), params: payload
      assert_response :unprocessable_entity
    end
    assert_equal 2, intake.latest_scope_revision.version

    sign_out
    login(@owner)
    get project_intake_path(intake)
    assert_response :success
    assert_select ".wa-scope-owner__item", count: 12
    assert_select ".wa-scope-owner__client", text: /The form confirms delivery/
    sign_out
    login(@owner_b)
    get project_intake_path(intake)
    assert_response :not_found
  end

  test "owner creates immutable source-traced requirement candidates with stable IDs and no AI charges" do
    login(@owner)
    token = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: token }
    login(@client)
    post claim_client_invitation_path
    intake = @client.client_project_intakes.last
    assert intake

    patch client_request_path(intake), params: {
      project_intake: { title: intake.title, project_type: intake.project_type, goal: intake.goal },
      fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
      scope: {
        business_goal: { text: "Visitors can submit a form.", status: "confirmed", responsibility: "client" },
        data: { text: "Store request records.", status: "unknown", responsibility: "owner" }
      }
    }
    assert_redirected_to edit_client_request_path(intake)
    sign_out
    login(@owner)

    get owner_requirements_path(intake)
    assert_response :success
    assert_select ".wa-req-review__item", count: 0
    assert_no_difference("AiSpendEntry.count") do
      assert_difference("IntakeRequirementSet.count", 1) do
        post owner_requirements_path(intake)
        assert_redirected_to owner_requirements_path(intake)
      end
    end
    set = intake.latest_requirement_set
    assert_equal 1, set.version
    assert set.readonly?
    assert_equal %w[R-001 R-002], set.requirements.pluck("id")
    assert_equal ["suggested"], set.requirements.map { |r| r["status"] }.uniq
    assert_equal intake.latest_scope_revision.id, set.requirements.first.dig("source", "revision_id")
    assert_equal [], set.requirements.first.fetch("acceptance_criteria")
    assert_equal "Visitors can submit a form.", set.requirements.first.fetch("statement")

    get owner_requirements_path(intake)
    assert_response :success
    assert_select ".wa-req-review__item", count: 2
    assert_no_difference("IntakeRequirementSet.count") do
      post owner_requirements_path(intake)
      assert_redirected_to owner_requirements_path(intake)
    end
    sign_out
    login(@owner_b)
    get owner_requirements_path(intake)
    assert_response :not_found
    post owner_requirements_path(intake)
    assert_response :not_found
    sign_out
    login(@client)
    get owner_requirements_path(intake)
    assert_response :not_found
  end

  test "E2.4 owner review creates immutable criteria with stale replay protection" do
    login(@owner)
    token = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: token }
    login(@client)
    post claim_client_invitation_path
    intake = @client.client_project_intakes.order(:id).last
    patch client_request_path(intake), params: {
      project_intake: { title: intake.title, project_type: intake.project_type, goal: intake.goal },
      fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
      scope: { business_goal: {
        text: "Visitors submit a contact form.", status: "confirmed", responsibility: "client"
      } }
    }
    assert_redirected_to edit_client_request_path(intake)
    sign_out
    login(@owner)
    post owner_requirements_path(intake)
    assert_redirected_to owner_requirements_path(intake)
    original = intake.latest_requirement_set
    assert_equal 1, original.version

    get owner_requirements_path(intake)
    assert_response :success
    assert_select "textarea[name='edits[0][statement]']", count: 1
    changes = { base_version: original.version, edits: {
      "0" => { statement: "Visitors can send the contact form.",
               status: "suggested",
               acceptance_criteria: "A successful request is displayed.\nA record is stored." }
    } }
    assert_no_difference("AiSpendEntry.count") do
      assert_difference("IntakeRequirementSet.count", 1) do
        patch owner_requirements_path(intake), params: changes
        assert_redirected_to owner_requirements_path(intake)
      end
    end
    current = intake.latest_requirement_set
    assert_equal 2, current.version
    assert_equal original.intake_scope_revision_id, current.intake_scope_revision_id
    assert_equal original.requirements.first.fetch("id"), current.requirements.first.fetch("id")
    assert_equal original.requirements.first.fetch("source"), current.requirements.first.fetch("source")
    assert_equal ["A successful request is displayed.", "A record is stored."],
      current.requirements.first.fetch("acceptance_criteria")
    assert_equal [], original.reload.requirements.first.fetch("acceptance_criteria")
    assert original.readonly?

    assert_no_difference("IntakeRequirementSet.count") do
      patch owner_requirements_path(intake), params: changes
      assert_redirected_to owner_requirements_path(intake)
    end
    malicious = { base_version: current.version, edits: {
      "0" => { statement: "Tampered", status: "confirmed", acceptance_criteria: "done",
               source: { revision_id: 999 } }
    } }
    assert_no_difference("IntakeRequirementSet.count") do
      patch owner_requirements_path(intake), params: malicious
      assert_redirected_to owner_requirements_path(intake)
    end
    assert_equal 2, intake.latest_requirement_set.version

    atomic = { base_version: current.version, edits: {
      "0" => { statement: current.requirements.first.fetch("statement"),
               status: "suggested",
               acceptance_criteria: current.requirements.first.fetch("acceptance_criteria").join("\n") }
    }, new_requirement: {
      section: "business_goal",
      statement: "The form notifies the visitor after submission.",
      acceptance_criteria: "A visible success message appears."
    } }
    assert_difference("IntakeRequirementSet.count", 1) do
      patch owner_requirements_path(intake), params: atomic
      assert_redirected_to owner_requirements_path(intake)
    end
    expanded = intake.latest_requirement_set
    assert_equal 3, expanded.version
    assert_equal %w[R-001 R-002], expanded.requirements.pluck("id")
    assert_equal "business_goal", expanded.requirements.last.dig("source", "section")
    assert_equal ["A visible success message appears."],
      expanded.requirements.last.fetch("acceptance_criteria")
    assert_equal 1, current.reload.requirements.size

    sign_out
    login(@client)
    patch owner_requirements_path(intake), params: changes
    assert_response :not_found
  end

  test "different client cannot claim, alter or view someone else's invitation draft" do
    login(@owner)
    raw = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw }
    login(@client)
    post claim_client_invitation_path
    intake = @client.client_project_intakes.last
    sign_out
    login(@client_b)
    get client_request_path(intake)
    assert_response :not_found
    get edit_client_request_path(intake)
    assert_response :not_found
    patch client_request_path(intake), params: { project_intake: { title: "Forgery" } }
    assert_response :not_found
    post claim_client_invitation_path
    assert_response :conflict
    assert_equal @client.id, ClientRequestInvitation.last.claimed_by_user_id
    assert_equal 1, ClientRequestInvitation.last.project_intake.intake_service_selections.count
  end

  test "expired revoked and invalid invitations do not create intakes" do
    login(@owner)
    raw = issue_invitation
    invitation = ClientRequestInvitation.last
    invitation.update!(expires_at: 1.minute.ago)
    sign_out
    assert_no_difference("ProjectIntake.count") do
      post client_invitation_preview_path, params: { invite_token: raw }
      assert_response :gone
      post client_invitation_preview_path, params: { invite_token: "a" * 64 }
      assert_response :not_found
      post client_invitation_preview_path, params: { invite_token: "wrong" }
      assert_response :not_found
    end

    login(@owner)
    raw2 = issue_invitation
    second = ClientRequestInvitation.last
    post revoke_owner_invitation_path(second)
    assert_redirected_to owner_invitations_path
    sign_out
    post client_invitation_preview_path, params: { invite_token: raw2 }
    assert_response :gone
    assert second.reload.revoked_at.present?
  end

  test "owner cannot create invitation with forged technical choices" do
    login(@owner)
    assert_no_difference("ClientRequestInvitation.count") do
      post owner_invitations_path, params: {
        proposal: proposal.merge(
          brief_selections: { tasks: ["exploit_hidden_data"] },
          brief_decisions: { deployment: "skip" }
        ),
        service_version_ids: []
      }
      assert_response :unprocessable_entity
    end
  end

  test "client cannot save forged technical taxonomy values" do
    login(@owner)
    token = issue_invitation
    sign_out
    post client_invitation_preview_path, params: { invite_token: token }
    login(@client)
    post claim_client_invitation_path
    intake = @client.client_project_intakes.last
    assert_no_difference("IntakeBriefRevision.count") do
      patch client_request_path(intake), params: {
        project_intake: { title: "Rejected edit", goal: "A fictional request updated by client", project_type: "rails_bugfix" },
        fact_review: { title: "confirmed", project_type: "confirmed", goal: "unknown" },
        brief: { selections: { backend: ["unknown_secret_framework"] }, decisions: { tasks: "skip" } }
      }
      assert_response :unprocessable_entity
    end
    refute_equal "Rejected edit", intake.reload.title
  end

  test "cross-owner published versions cannot be embedded in an owner draft" do
    login(@owner)
    other, _, _, caps = approved_profile_for(@owner_b, version: 2)
    foreign = published_service(other, caps.first)
    assert_no_difference("ClientRequestInvitation.count") do
      post owner_invitations_path, params: {
        proposal: proposal, service_version_ids: [foreign.published_version_id]
      }
      assert_response :unprocessable_entity
    end
  end

  test "invitation page exposes contextual AI controls but no generation on GET" do
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      get owner_invitations_path
      assert_response :success
      assert_select ".wa-invite-ai[data-controller='wa-invitation-ai']", count: 1
      assert_select ".wa-invite-ai__action", count: 3
      assert_select ".wa-invite-ai__result[hidden]", count: 1
      assert_select ".wa-invite-ai button[data-wa-invitation-ai-target='generate'][disabled]", count: 1
    end
  end

  test "AI invitation endpoint rejects missing paid consent and forged purposes without charges" do
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post owner_invitation_ai_draft_path, as: :json, params: {
        operation: "intake_questions", paid_consent: "0",
        seed_title: "Synthetic Rails form", seed_goal: @seed
      }
      assert_response :unprocessable_entity
      assert_equal "consent_required", response.parsed_body["error"]

      post owner_invitation_ai_draft_path, as: :json, params: {
        operation: "delete_records", paid_consent: "1",
        seed_title: "Synthetic Rails form", seed_goal: @seed
      }
      assert_response :unprocessable_entity
      assert_equal "unsupported_operation", response.parsed_body["error"]
    end
  end

  test "consented invitation AI returns a private saved draft without issuing invitation" do
    login(@owner)
    entry = Struct.new(:id, :result).new(71_019, {
      "heading" => "Fictional Rails task",
      "draft" => "Investigate the Rails form problem and propose clear acceptance checks.",
      "questions" => ["When does the error appear?"],
      "cautions" => ["Do not promise completion dates."],
      "next_step" => "Review the proposed questions."
    })
    fake = Object.new
    seen = []
    fake.define_singleton_method(:generate!) do |**args|
      seen << args
      entry
    end
    assert_no_difference("ClientRequestInvitation.count") do
      OwnerAi::Composer.stub(:new, fake) do
        post owner_invitation_ai_draft_path, as: :json, params: {
          operation: "intake_questions", paid_consent: "1",
          seed_title: "Synthetic Rails form", seed_goal: @seed,
          brief_selections: { tasks: %w[bugfix tests] }
        }
      end
      assert_response :success
    end
    assert_equal 1, seen.size
    assert_equal "intake_questions", seen.first.fetch(:operation)
    assert_includes seen.first.fetch(:brief), "bugfix"
    assert_equal "Fictional Rails task", response.parsed_body["heading"]
    assert_equal owner_ai_assistant_path(entry_id: entry.id, operation: "intake_questions"),
      response.parsed_body["review_url"]
  end

  test "client cannot access owner invitation AI and disabled provider does not bill" do
    login(@client)
    assert_no_difference("AiSpendEntry.count") do
      post owner_invitation_ai_draft_path, as: :json, params: {
        operation: "intake_questions", paid_consent: "1",
        seed_title: "Synthetic Rails form", seed_goal: @seed
      }
      assert_response :redirect
    end
    sign_out
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post owner_invitation_ai_draft_path, as: :json, params: {
        operation: "intake_questions", paid_consent: "1",
        seed_title: "Synthetic Rails form", seed_goal: @seed
      }
      assert_response :service_unavailable
      assert_equal "provider_unavailable", response.parsed_body["error"]
    end
  end

  private

  def proposal
    { seed_title: "Fictional Rails form change", seed_project_type: "rails_bugfix", seed_goal: @seed }
  end

  def issue_invitation
    post owner_invitations_path, params: {
      proposal: proposal.merge(
        brief_selections: { tasks: %w[bugfix tests], backend: ["rails"] },
        brief_decisions: { deployment: "client" },
        brief_notes: "Synthetic test job"
      ),
      service_version_ids: [@offering.published_version_id]
    }
    assert_redirected_to owner_invitations_path
    follow_redirect!
    assert_response :success
    element = css_select("#e2-invite-link").first
    assert element, "one-time owner copyable link missing"
    url = element["value"]
    match = URI(url).fragment.to_s.match(/\Atoken=([0-9a-f]{64})\z/)
    assert match, "token should appear only in fragment"
    match[1]
  end

  def published_service(workspace, capability)
    offering = OwnerServices::Catalogue.new(workspace: workspace).create_draft!(
      service_fields(capability, title: "Fix a synthetic Rails form")
    )
    version = offering.latest_version
    version.update!(approved_at: Time.current)
    offering.update!(approved_version: version, published_version: version)
    offering
  end

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "owner" ? workspace_path :
                         (ClientRequestInvitation.exists? && response.headers["Location"].include?("invite") ?
                           client_invitation_preview_path : client_home_path))
  end

  def sign_out
    delete sign_out_path
    assert_redirected_to root_path
  end
end
