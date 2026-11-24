require "test_helper"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiAssistantTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("ai-assistant-owner@example.test")
    @other = make_test_owner("ai-assistant-foreign@example.test")
    @client = make_test_client("ai-assistant-client@example.test")
    @workspace, @profile, = approved_profile_for(@owner)
    @foreign_workspace, @foreign_profile, = approved_profile_for(@other)
  end

  test "owner assistant and floating launcher are access restricted and GET is free" do
    assert_no_difference("AiSpendEntry.count") do
      get owner_ai_assistant_path
      assert_redirected_to sign_in_path

      login(@client)
      get owner_ai_assistant_path
      assert_redirected_to sign_in_path
      get owner_cabinet_path
      assert_redirected_to sign_in_path
      delete sign_out_path

      login(@owner)
      get owner_ai_assistant_path
      assert_response :success
      assert_select "#owner-ai-assistant"
      assert_select "#owner-ai-dock"
      assert_select "summary[aria-label]"
      assert_select "form[action=?]", create_owner_ai_draft_path,
                  count: OwnerIntelligence::Grok.enabled? ? 2 : 1
      get owner_cabinet_path
      assert_response :success
      assert_select "#owner-ai-dock"
    end
  end

  test "AI Workspace is discoverable in owner navigation and dock, never client header" do
    assert_no_difference("AiSpendEntry.count") do
      login(@owner)
      get owner_cabinet_path
      assert_response :success
      assert_select ".rc-nav-group a.wa-ai-nav-entry[href=?]", owner_ai_assistant_path, count: 1
      assert_select ".app-nav a.wa-ai-header-shortcut[href=?]", owner_ai_assistant_path, count: 1
      assert_select "#owner-ai-dock a.wa-ai-dock__workspace-link[href=?]", owner_ai_assistant_path, count: 1
      get owner_ai_assistant_path
      assert_response :success
      assert_select ".rc-nav-group a.wa-ai-nav-entry[aria-current='page']", count: 1
      assert_select "nav.wa-ai-page__wayfinder a[href='#wa-ai-compose-heading']", count: 1
      assert_select "nav.wa-ai-page__wayfinder a[href='#owner-ai-knowledge']", count: 1
      assert_select "nav.wa-ai-page__wayfinder a[href='#owner-ai-draft-library']", count: 1
      assert_select "#owner-ai-knowledge .wa-ai-knowledge__item", count: 4
      assert_select "#owner-ai-knowledge .wa-ai-knowledge__item--profile", count: 1
      assert_select "#owner-ai-knowledge .wa-ai-knowledge__item--documents", count: 1
      delete sign_out_path
      login(@client)
      get client_cabinet_path
      assert_response :success
      assert_select ".rc-nav-group a.wa-ai-nav-entry", count: 0
      assert_select ".app-nav a.wa-ai-header-shortcut", count: 0
      assert_select "#owner-ai-dock", count: 0
    end
  end

  test "invalid operation or missing explicit paid consent cannot reserve provider spend" do
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post create_owner_ai_draft_path, params: {
        operation: "delete_everything", brief: "Do something destructive", paid_consent: "1"
      }
      assert_redirected_to owner_ai_assistant_path
      post create_owner_ai_draft_path, params: {
        operation: "service_copy", brief: "Draft synthetic service copy", paid_consent: "0"
      }
      assert_redirected_to owner_ai_assistant_path(operation: "service_copy")
    end
  end

  test "only the matching owner can see a previously stored draft; output is escaped" do
    entry = AiSpendEntry.create!(
      professional_profile: @profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("owner-assistant-#{@profile.id}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => "Synthetic test result",
        "draft" => "<script>alert('bad')</script> A fictional service draft.",
        "questions" => ["What should the form collect?"],
        "cautions" => ["No promised release dates"],
        "next_step" => "Owner reviews before publishing",
        "purpose" => "service_copy", "profile_version" => 1
      }, resolved_at: Time.current
    )
    login(@other)
    get owner_ai_assistant_path(entry_id: entry.id)
    assert_response :success
    assert_select ".wa-ai-page__draft", count: 0
    delete sign_out_path

    login(@owner)
    get owner_ai_assistant_path(entry_id: entry.id)
    assert_response :success
    assert_select ".wa-ai-page__draft", text: /fictional service draft/
    assert_select "script", text: /alert\('bad'\)/, count: 0
    assert_select "form[action=?]", create_owner_ai_draft_path,
                  count: OwnerIntelligence::Grok.enabled? ? 2 : 1
  end

  test "operation registry rejects forged keys and output validation rejects malformed schema" do
    assert_equal 4, OwnerAi::OperationRegistry.keys.size
    assert_nil OwnerAi::OperationRegistry.fetch("system_command")
    composer = OwnerAi::Composer.new(workspace: @workspace)
    safe = {
      "heading" => "A synthetic private service",
      "draft" => "A bounded fictional service description with no promises.",
      "questions" => [], "cautions" => [], "next_step" => "Owner must review."
    }
    assert composer.send(:validate_result!, safe)
    assert_raises(OwnerAi::Composer::Unavailable) do
      composer.send(:validate_result!, safe.merge("tool_call" => "approve"))
    end
    assert_raises(OwnerAi::Composer::Unavailable) do
      composer.send(:validate_result!, safe.merge("draft" => "too short"))
    end
  end

  test "knowledge inventory is scoped, read-only, and never exposes private profile summary" do
    catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    catalogue.create_draft!(service_fields(@profile.professional_capabilities.first,
      title: "Synthetic owner-only knowledge service"))
    another = OwnerServices::Catalogue.new(workspace: @foreign_workspace)
    another.create_draft!(service_fields(@foreign_profile.professional_capabilities.first,
      title: "FOREIGN_PRIVATE_KNOWLEDGE_NEVER_VISIBLE"))

    readiness = OwnerAi::KnowledgeReadiness.new(workspace: @workspace)
    assert_equal 1, readiness.private_service_count
    assert_equal 0, readiness.approved_service_count
    refute readiness.approved_public_facts?
    refute readiness.service_catalogue_available_to_composer?
    refute readiness.documents_available_to_ai?
    refute readiness.faq_and_prices_available_to_client_ai?

    @profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("synthetic-public-facts-ready"),
      payload: {
        "headline" => "Approved fictional Rails professional",
        "public_summary_draft" => "Approved shareable fictional services statement",
        "private_summary" => "OWNER_PRIVATE_NOT_FOR_KNOWLEDGE_UI"
      }, approved_at: Time.current
    )
    assert OwnerAi::KnowledgeReadiness.new(workspace: @workspace).approved_public_facts?

    assert_no_difference("AiSpendEntry.count") do
      login(@client)
      get owner_ai_assistant_path
      assert_redirected_to sign_in_path
      delete sign_out_path
      login(@owner)
      get owner_ai_assistant_path
      assert_response :success
      assert_select "#owner-ai-knowledge"
      assert_select ".wa-ai-knowledge__item", count: 4
      assert_select "#owner-ai-knowledge", text: /OWNER_PRIVATE_NOT_FOR_KNOWLEDGE_UI/, count: 0
      assert_select "#owner-ai-knowledge", text: /FOREIGN_PRIVATE_KNOWLEDGE_NEVER_VISIBLE/, count: 0
      assert_select "#owner-ai-knowledge", text: /1.*0/
    end
  end

  test "catalogue context excludes drafts foreign services private fields and stale snapshots" do
    catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    offering = catalogue.create_draft!(service_fields(@profile.professional_capabilities.first, title: "Public synthetic Rails service"))
    draft = offering.draft_version
    catalogue.approve!(offering: offering, version: draft.version, digest: draft.digest, confirmed: true)
    approved = offering.reload.approved_version
    catalogue.publish!(offering: offering, version_id: approved.id, digest: approved.digest, confirmed: true, owner: @owner)
    catalogue.create_draft!(service_fields(@profile.professional_capabilities.first, title: "PRIVATE_UNPUBLISHED_SERVICE"))
    foreign_catalogue = OwnerServices::Catalogue.new(workspace: @foreign_workspace)
    foreign = foreign_catalogue.create_draft!(service_fields(@foreign_profile.professional_capabilities.first, title: "FOREIGN_PUBLISHED_SERVICE"))
    foreign_draft = foreign.draft_version
    foreign_catalogue.approve!(offering: foreign, version: foreign_draft.version, digest: foreign_draft.digest, confirmed: true)
    foreign_approved = foreign.reload.approved_version
    foreign_catalogue.publish!(offering: foreign, version_id: foreign_approved.id, digest: foreign_approved.digest, confirmed: true, owner: @other)

    assert_no_difference("AiSpendEntry.count") do
      entries = OwnerAi::CatalogueContext.new(workspace: @workspace).entries
      assert_equal 1, entries.length
      assert_equal %w[delivery_mode included_scope summary title version], entries.first.keys.sort
      assert_equal "Public synthetic Rails service", entries.first["title"]
      refute_includes JSON.generate(entries), "FOREIGN_PUBLISHED_SERVICE"
      refute_includes JSON.generate(entries), "PRIVATE_UNPUBLISHED_SERVICE"
      assert OwnerAi::KnowledgeReadiness.new(workspace: @workspace).service_catalogue_available_to_composer?
      @profile.update!(onboarding_state: "draft")
      assert_empty OwnerAi::CatalogueContext.new(workspace: @workspace).entries
      @profile.update!(onboarding_state: "approved")
      @profile.professional_context_snapshots.create!(
        version: 2, digest: Digest::SHA256.hexdigest("catalogue-stale-snapshot"),
        payload: { "headline" => "New synthetic profile" }, approved_at: Time.current
      )
      assert_empty OwnerAi::CatalogueContext.new(workspace: @workspace).entries
    end
  end

  test "explicitly consented draft uses bounded provider schema, ledger and no automatic apply" do
    @profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("approved-owner-v2"),
      payload: {
        "headline" => "Fictional Rails freelancer",
        "public_summary_draft" => "Small Ruby on Rails tasks only",
        "private_summary" => "NEVER_SEND_PRIVATE_CONTEXT"
      }, approved_at: Time.current
    )
    response = Struct.new(:code, :body).new("200", JSON.generate(
      status: "completed", id: "provider-synthetic-1",
      output: [{ type: "message", content: [{ type: "output_text", text: JSON.generate(
        heading: "An example Rails service",
        draft: "Investigate one fictional Rails issue and prepare a bounded change with test evidence.",
        questions: ["What is the smallest reproduction?"], cautions: ["No fixed delivery promise."],
        next_step: "Owner checks the brief and deliverables."
      ) }] }],
      usage: { input_tokens: 120, output_tokens: 180, total_tokens: 300, cost_in_usd_ticks: 120_000 }
    ))
    seen_payload = []
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      seen_payload << JSON.parse(request.body)
      response
    end
    network_stub = lambda { |*_args, **_kwargs, &block| block.call(fake_http) }
    old_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictitious-test-value-never-for-network"
    login(@owner)
    assert_difference("AiSpendEntry.count", 1) do
      assert_no_difference("ServiceOfferingVersion.count") do
        OwnerIntelligence::Grok.stub(:enabled?, true) do
          IntakeAiQuota.stub(:reserve_call!, true) do
            Net::HTTP.stub(:start, network_stub) do
              post create_owner_ai_draft_path, params: {
                operation: "service_copy",
                brief: "Draft a short fictional Ruby on Rails bugfix service for a small project.",
                paid_consent: "1"
              }
            end
          end
        end
      end
    end
    entry = @profile.ai_spend_entries.order(id: :desc).first
    assert_redirected_to owner_ai_assistant_path(entry_id: entry.id, operation: "service_copy")
    assert_equal "settled", entry.status
    assert_equal "owner_ai_composer_v1", entry.operation
    assert_equal 120_000, entry.charged_ticks
    assert_equal 1, seen_payload.length
    assert_equal [], seen_payload.first["tools"]
    source_text = seen_payload.first.fetch("input").last.fetch("content")
    assert_includes source_text, "Small Ruby on Rails tasks only"
    refute_includes source_text, "NEVER_SEND_PRIVATE_CONTEXT"
    assert_equal "service_copy", entry.result["purpose"]
    assert_equal 2, entry.result["profile_version"]
    assert_nil JSON.parse(source_text)["published_service_catalogue"]
  ensure
    ENV["XAI_API_KEY"] = old_key
  end

  test "explicit catalogue opt-in sends only current published fields to mocked provider" do
    catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    offering = catalogue.create_draft!(service_fields(@profile.professional_capabilities.first, title: "Consented public service"))
    draft = offering.draft_version
    catalogue.approve!(offering: offering, version: draft.version, digest: draft.digest, confirmed: true)
    approved = offering.reload.approved_version
    catalogue.publish!(offering: offering, version_id: approved.id, digest: approved.digest, confirmed: true, owner: @owner)
    catalogue.create_draft!(service_fields(@profile.professional_capabilities.first, title: "SECRET_DRAFT_NOT_SENT"))
    response = Struct.new(:code, :body).new("200", JSON.generate(
      status: "completed", id: "provider-catalogue-synthetic",
      output: [{ type: "message", content: [{ type: "output_text", text: JSON.generate(
        heading: "Synthetic catalogue draft", draft: "Review the published service before confirming the task.",
        questions: [], cautions: [], next_step: "Owner reviews."
      ) }] }],
      usage: { input_tokens: 120, output_tokens: 180, total_tokens: 300, cost_in_usd_ticks: 120_000 }
    ))
    payloads = []
    http = Object.new
    http.define_singleton_method(:request) { |request| payloads << JSON.parse(request.body); response }
    old_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictional-catalogue-test"
    login(@owner)
    OwnerIntelligence::Grok.stub(:enabled?, true) do
      IntakeAiQuota.stub(:reserve_call!, true) do
        Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
          assert_no_difference("AiSpendEntry.count") do
            post create_owner_ai_draft_path, params: { operation: "service_copy", brief: "Review the fictional service catalogue.", include_catalogue: "1" }
          end
          assert_empty payloads
          assert_difference("AiSpendEntry.count", 1) do
            assert_no_difference("ServiceOfferingVersion.count") do
              post create_owner_ai_draft_path, params: { operation: "service_copy", brief: "Review the fictional service catalogue.", include_catalogue: "1", paid_consent: "1" }
            end
          end
        end
      end
    end
    assert_equal 1, payloads.size
    source = JSON.parse(payloads.first.fetch("input").last.fetch("content"))
    assert_equal [{ "title" => approved.title, "summary" => approved.summary, "included_scope" => approved.included_scope, "delivery_mode" => approved.delivery_mode, "version" => approved.version }], source.fetch("published_service_catalogue")
    refute_includes JSON.generate(source), "SECRET_DRAFT_NOT_SENT"
    refute_includes JSON.generate(source), approved.excluded_scope
    assert_equal "settled", @profile.ai_spend_entries.order(:id).last.status
  ensure
    ENV["XAI_API_KEY"] = old_key
  end

  test "owner sees only their saved AI draft history and review GET never bills" do
    owner_entry = create_saved_draft(@profile, "Owner private synthetic AI draft")
    foreign_entry = create_saved_draft(@foreign_profile, "FOREIGN_PRIVATE_DRAFT_NOT_VISIBLE")
    assert_no_difference("AiSpendEntry.count") do
      login(@owner)
      get owner_ai_assistant_path
      assert_response :success
      assert_select "#owner-ai-draft-library"
      assert_select "#owner-ai-draft-library a[href=?]",
                    owner_ai_assistant_path(entry_id: owner_entry.id, operation: "service_copy", anchor: "wa-ai-result-heading"), count: 1
      assert_select "#owner-ai-draft-library", text: /FOREIGN_PRIVATE_DRAFT_NOT_VISIBLE/, count: 0

      get owner_ai_assistant_path(entry_id: foreign_entry.id)
      assert_response :success
      assert_select ".wa-ai-page__draft", count: 0
      assert_select "#owner-ai-draft-library a[href=?]",
                    owner_ai_assistant_path(entry_id: foreign_entry.id, operation: "service_copy", anchor: "wa-ai-result-heading"), count: 0

      get owner_ai_assistant_path(entry_id: owner_entry.id, operation: "service_copy", anchor: "wa-ai-result-heading")
      assert_select ".wa-ai-page__draft", text: /Owner private synthetic AI draft/
    end
  end

  test "cabinet practice capabilities and catalogue provide owner contextual AI entrypoints" do
    # Use a complete, separate synthetic approved snapshot: practice UI requires
    # headline/private/public summaries; the basic catalogue fixture omits them.
    @profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("context-entrypoints-#{@owner.id}"),
      payload: {
        "headline" => "Fictional Rails consultant",
        "private_summary" => "Private synthetic owner career history for test screens.",
        "public_summary_draft" => "Synthetic Rails services with prior review.",
        "capabilities" => [], "desired_services" => [], "interview_answers" => {}
      }, approved_at: Time.current
    )
    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      get owner_cabinet_path
      assert_response :success
      assert_select "a.ws-account-tool[href=?]", owner_ai_assistant_path, count: 0
      assert_select "header.app-header a[href=?]", owner_ai_assistant_path, minimum: 1

      get owner_practice_path
      assert_response :success
      assert_select "a[href=?]", owner_ai_assistant_path(operation: "client_reply")

      get owner_capabilities_path
      assert_response :success
      assert_select "a[href=?]", owner_ai_assistant_path(operation: "intake_questions")

      get owner_services_path
      assert_response :success
      assert_select "a[href=?]", owner_ai_assistant_path(operation: "service_copy")
    end
  end

  private

  def create_saved_draft(profile, draft)
    AiSpendEntry.create!(
      professional_profile: profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("#{profile.id}-#{draft}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => draft, "draft" => "#{draft}. A complete synthetic Rails service description.",
        "questions" => [], "cautions" => [], "next_step" => "Manual owner review.",
        "purpose" => "service_copy", "profile_version" => 1, "turn" => 1
      }, resolved_at: Time.current
    )
  end


  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
