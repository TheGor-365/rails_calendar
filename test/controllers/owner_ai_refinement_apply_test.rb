require "test_helper"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiRefinementApplyTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("ai-refine-owner@example.test")
    @client = make_test_client("ai-refine-client@example.test")
    @other = make_test_owner("ai-refine-other@example.test")
    @workspace, @profile, @snapshot, @caps = approved_profile_for(@owner)
    @other_workspace, @other_profile, = approved_profile_for(@other)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    @offering = @catalogue.create_draft!(service_fields(@caps.first))
    @entry = sample_entry(@profile)
  end

  test "navigation has fixed owner-only destinations and never reserves AI spend" do
    assert_equal "services", OwnerAi::Navigator.resolve("открой услуги")
    assert_equal "catalogue_ai", OwnerAi::Navigator.resolve("открой ИИ каталог")
    assert_equal "cabinet", OwnerAi::Navigator.resolve("open cabinet")
    assert_equal "calendar", OwnerAi::Navigator.resolve("открой календарь")
    assert_equal "consultations", OwnerAi::Navigator.resolve("открой консультации")
    assert_nil OwnerAi::Navigator.resolve("https://evil.example")
    assert_nil OwnerAi::Navigator.resolve("open https://evil.example")

    assert_no_difference("AiSpendEntry.count") do
      post navigate_owner_ai_path, params: { command: "открой услуги" }
      assert_redirected_to sign_in_path
      login(@client)
      post navigate_owner_ai_path, params: { command: "открой услуги" }
      assert_redirected_to sign_in_path
      delete sign_out_path

      login(@owner)
      post navigate_owner_ai_path, params: { command: "открой услуги" }
      assert_redirected_to owner_services_path
      post navigate_owner_ai_path, params: { command: "open cabinet" }
      assert_redirected_to owner_cabinet_path
      post navigate_owner_ai_path, params: { command: "open https://evil.example" }
      assert_redirected_to owner_ai_assistant_path
      get owner_cabinet_path
      assert_select "form[action=?]", navigate_owner_ai_path
    end
  end


  test "navigation accepts bare words stems synonyms typo and contextual page names without AI" do
    assert_equal "services", OwnerAi::Navigator.resolve("услуги")
    assert_equal "services", OwnerAi::Navigator.resolve("услуг")
    assert_equal "services", OwnerAi::Navigator.resolve("усл")
    assert_equal "services", OwnerAi::Navigator.resolve("ус")
    assert_equal "services", OwnerAi::Navigator.resolve("слуг")
    assert_equal "services", OwnerAi::Navigator.resolve("мои услуги")
    assert_equal "services", OwnerAi::Navigator.resolve("мне нужны мои услуги")
    assert_equal "services", OwnerAi::Navigator.resolve("серв")
    assert_equal "services", OwnerAi::Navigator.resolve("покажи мне каталог услуг")
    assert_equal "assistant", OwnerAi::Navigator.resolve("AI Workspace")
    assert_equal "assistant", OwnerAi::Navigator.resolve("ИИ студия")
    assert_equal "cabinet", OwnerAi::Navigator.resolve("кабин")
    assert_equal "practice", OwnerAi::Navigator.resolve("практика")
    assert_equal "calendar", OwnerAi::Navigator.resolve("кален")
    assert_equal "today", OwnerAi::Navigator.resolve("сегoдня".tr("o", "о"))
    assert_equal "catalogue_ai", OwnerAi::Navigator.resolve("ИИ каталог")
    assert_equal :ambiguous, OwnerAi::Navigator.search("ИИ").status
    assert_equal "service_new", OwnerAi::Navigator.resolve("новая услуга")
    assert_equal "public_services", OwnerAi::Navigator.resolve("витрина")
    assert_nil OwnerAi::Navigator.resolve("https://example.com")
    assert_nil OwnerAi::Navigator.resolve("/admin/secret")
    assert_nil OwnerAi::Navigator.resolve("")
    assert_nil OwnerAi::Navigator.resolve("x")

    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      %w[услуги услуг усл ус слуг].each do |word|
        post navigate_owner_ai_path, params: { command: word }
        assert_redirected_to owner_services_path
      end
      post navigate_owner_ai_path, params: { command: "кабин" }
      assert_redirected_to owner_cabinet_path
      post navigate_owner_ai_path, params: { command: "практика" }
      assert_redirected_to owner_practice_path
      post navigate_owner_ai_path, params: { command: "новая услуга" }
      assert_redirected_to new_owner_service_path
      post navigate_owner_ai_path, params: { command: "https://evil.example" }
      assert_redirected_to owner_ai_assistant_path
    end
  end

  test "ambiguous matching offers choices only for pages in the current owner workspace" do
    first = @catalogue.create_draft!(service_fields(@caps.first,
      title: "Rails API integration for fictional customers"))
    second = @catalogue.create_draft!(service_fields(@caps.first,
      title: "Rails data cleanup for fictional customers"))
    foreign_catalogue = OwnerServices::Catalogue.new(workspace: @other_workspace)
    foreign_caps = @other_profile.professional_capabilities
    foreign_catalogue.create_draft!(service_fields(foreign_caps.first,
      title: "Rails secret for another workspace"))
    result = OwnerAi::Navigator.search("Rails", workspace: @workspace)
    assert_equal :ambiguous, result.status
    assert result.candidates.any? { |candidate| candidate.key == "service:#{first.id}" }
    assert result.candidates.any? { |candidate| candidate.key == "service:#{second.id}" }
    assert result.candidates.none? { |candidate| candidate.label.include?("Rails secret") }

    login(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post navigate_owner_ai_path, params: { command: "Rails" }
      assert_redirected_to owner_ai_assistant_path(nav_query: "Rails")
      follow_redirect!
      assert_response :success
      assert_select ".wa-ai-nav-results__links a", minimum: 2
      assert_select ".wa-ai-nav-results__links a[href=?]", owner_service_path(first)
      assert_select ".wa-ai-nav-results__links a[href=?]", owner_service_path(second)
      assert_select ".wa-ai-nav-results", text: /Rails secret/, count: 0

      post navigate_owner_ai_path, params: { command: "Rails API integ" }
      assert_redirected_to owner_service_path(first)
    end
  end

  test "client and unauthenticated sessions cannot use word-fragment owner navigation" do
    assert_no_difference("AiSpendEntry.count") do
      post navigate_owner_ai_path, params: { command: "услуг" }
      assert_redirected_to sign_in_path
      login(@client)
      post navigate_owner_ai_path, params: { command: "услуг" }
      assert_redirected_to sign_in_path
    end
  end

  test "reviewed apply changes one draft summary and preserves every boundary" do
    old_draft = @offering.draft_version
    before = old_draft.attributes.slice("title", "included_scope", "excluded_scope",
                                        "requirements_prompt", "project_category")
    login(@owner)

    get owner_ai_assistant_path(entry_id: @entry.id, offering_id: @offering.id)
    assert_response :success
    assert_select ".wa-ai-apply__comparison"
    assert_select "form[action=?]", apply_owner_ai_draft_path(@entry)
    assert_select ".wa-ai-conversation__history"

    summary = "Prepare a bounded, fictional Ruby on Rails diagnosis with reproducible tests and no delivery promises."
    assert_no_difference("ServiceOfferingPublication.count") do
      post apply_owner_ai_draft_path(@entry), params: {
        offering_id: @offering.id, base_version: old_draft.version,
        base_digest: old_draft.digest, summary: summary, confirmed: "1"
      }
    end
    assert_redirected_to owner_service_path(@offering)
    draft = @offering.reload.draft_version
    assert_equal summary, draft.summary
    assert_equal before, draft.attributes.slice(*before.keys)
    assert_nil @offering.approved_version
    assert_nil @offering.published_version
    assert_equal 0, ServiceOfferingPublication.count
  end

  test "forged foreign AI entry, missing confirmation and stale digest fail closed" do
    old_draft = @offering.draft_version
    summary = "Owner accepted a fictional updated Rails service with bounded review and tests."
    login(@other)
    post apply_owner_ai_draft_path(@entry), params: {
      offering_id: @offering.id, base_version: old_draft.version,
      base_digest: old_draft.digest, summary: summary, confirmed: "1"
    }
    assert_redirected_to owner_ai_assistant_path(entry_id: @entry.id, offering_id: @offering.id)
    delete sign_out_path

    login(@owner)
    assert_no_changes -> { @offering.reload.draft_version.summary } do
      post apply_owner_ai_draft_path(@entry), params: {
        offering_id: @offering.id, base_version: old_draft.version,
        base_digest: old_draft.digest, summary: summary, confirmed: "0"
      }
      assert_redirected_to owner_ai_assistant_path(entry_id: @entry.id, offering_id: @offering.id)
    end

    changed = @catalogue.update_draft!(
      offering: @offering, version: old_draft.version, digest: old_draft.digest,
      attributes: service_fields(@caps.first, title: "Manually revised fictional Rails support")
    )
    assert_no_changes -> { @offering.reload.draft_version.digest } do
      post apply_owner_ai_draft_path(@entry), params: {
        offering_id: @offering.id, base_version: old_draft.version,
        base_digest: old_draft.digest, summary: summary, confirmed: "1"
      }
      assert_redirected_to owner_ai_assistant_path(entry_id: @entry.id, offering_id: @offering.id)
    end

    @catalogue.approve!(offering: @offering, version: changed.version, digest: changed.digest, confirmed: true)
    assert_no_difference("ServiceOfferingVersion.count") do
      post apply_owner_ai_draft_path(@entry), params: {
        offering_id: @offering.id, base_version: changed.version,
        base_digest: changed.digest, summary: summary, confirmed: "1"
      }
    end
    assert_equal changed.id, @offering.reload.approved_version_id
    assert_nil @offering.draft_version
  end

  test "only matching owner can refine a settled prior draft and every turn needs consent" do
    foreign_entry = sample_entry(@other_profile)
    login(@owner)

    assert_no_difference("AiSpendEntry.count") do
      post create_owner_ai_draft_path, params: {
        operation: "service_copy", brief: "Please refine this synthetic service description.",
        parent_entry_id: @entry.id, paid_consent: "0"
      }
      assert_redirected_to owner_ai_assistant_path(operation: "service_copy")
      post create_owner_ai_draft_path, params: {
        operation: "service_copy", brief: "Please refine this synthetic service description.",
        parent_entry_id: foreign_entry.id, paid_consent: "1"
      }
      assert_redirected_to owner_ai_assistant_path(operation: "service_copy")
    end

    assert_raises(OwnerAi::Composer::Unavailable) do
      OwnerAi::Composer.new(workspace: @workspace).generate!(
        operation: "service_copy", brief: "A safe fictional revision request", parent: foreign_entry
      )
    end
  end

  test "mocked next turn stores only new owner result; no hidden private profile or network request" do
    @profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("refine-snapshot-v2"),
      payload: {
        "headline" => "Rails developer", "public_summary" => "Safe synthetic small Rails tasks",
        "private_summary" => "NEVER_SEND_PRIVATE_CONTEXT"
      }, approved_at: Time.current
    )
    parent = sample_entry(@profile, profile_version: 2)
    response = Struct.new(:code, :body).new("200", JSON.generate(
      status: "completed", id: "mock-refine-2",
      output: [{ type: "message", content: [{ type: "output_text", text: JSON.generate(
        heading: "Second version", draft: "A revised fictional small Ruby on Rails task description with no guaranteed outcome.",
        questions: ["Can we verify the bug?"], cautions: ["Owner review required"],
        next_step: "Owner compares both revisions"
      ) }] }],
      usage: { input_tokens: 120, output_tokens: 100, total_tokens: 220, cost_in_usd_ticks: 10_000 }
    ))
    captured = []
    fake = Object.new
    fake.define_singleton_method(:request) do |request|
      captured << JSON.parse(request.body)
      response
    end
    old_key = ENV["XAI_API_KEY"]
    ENV["XAI_API_KEY"] = "xai-fictitious-test-only"
    login(@owner)
    assert_difference("AiSpendEntry.count", 1) do
      OwnerIntelligence::Grok.stub(:enabled?, true) do
        IntakeAiQuota.stub(:reserve_call!, true) do
          Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake) }) do
            post create_owner_ai_draft_path, params: {
              operation: "service_copy", brief: "Refine this service to emphasize bounded deliverables.",
              parent_entry_id: parent.id, paid_consent: "1"
            }
          end
        end
      end
    end
    refined = @profile.ai_spend_entries.order(id: :desc).first
    assert_equal "settled", refined.status
    assert_equal 2, refined.result["turn"]
    assert_equal parent.id, refined.result["parent_entry_id"]
    assert_equal "service_copy", refined.result["purpose"]
    assert_equal 1, captured.size
    payload = captured.first.fetch("input").last.fetch("content")
    assert_includes payload, "Safe synthetic small Rails tasks"
    assert_includes payload, parent.result["draft"]
    refute_includes payload, "NEVER_SEND_PRIVATE_CONTEXT"
    assert_redirected_to owner_ai_assistant_path(entry_id: refined.id, operation: "service_copy")
    get owner_ai_assistant_path(entry_id: refined.id)
    assert_select ".wa-ai-conversation__turn", count: 2
  ensure
    ENV["XAI_API_KEY"] = old_key
  end

  private

  def sample_entry(profile, profile_version: 1)
    AiSpendEntry.create!(
      professional_profile: profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("refinement-#{profile.id}-#{SecureRandom.hex(6)}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => "A synthetic service description",
        "draft" => "Review one fictional Ruby on Rails error and propose a small testable correction.",
        "questions" => [], "cautions" => ["No delivery promise"],
        "next_step" => "Review before using",
        "purpose" => "service_copy", "profile_version" => profile_version, "turn" => 1
      }, resolved_at: Time.current
    )
  end

  def login(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end
end
