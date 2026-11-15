require "test_helper"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerCatalogueAiTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("copilot-owner@example.test")
    @client = make_test_client("copilot-client@example.test")
    @other = make_test_owner("copilot-foreign-owner@example.test")
    @workspace, @profile, @snapshot, @caps = approved_profile_for(@owner)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    @offering = @catalogue.create_draft!(service_fields(@caps.first))
  end

  test "review console is owner-only and never initiates paid call from GET" do
    assert_no_difference("AiSpendEntry.count") do
      get owner_catalogue_ai_path
      assert_redirected_to sign_in_path
      sign_in(@client)
      get owner_catalogue_ai_path
      assert_redirected_to sign_in_path
      delete sign_out_path
      sign_in(@owner)
      get owner_catalogue_ai_path
      assert_response :success
      assert_select "#owner-catalogue-copilot"
      assert_select "form[action=?]", run_owner_catalogue_ai_path, count: 0 if !OwnerServices::CatalogueCopilot.enabled?
      assert_select "a[href=?]", owner_services_path
      post run_owner_catalogue_ai_path
      assert_redirected_to owner_catalogue_ai_path
    end
  end

  test "paid call without consent never reserves budget" do
    sign_in(@owner)
    assert_no_difference("AiSpendEntry.count") do
      post run_owner_catalogue_ai_path, params: { paid_consent: "0" }
      assert_redirected_to owner_catalogue_ai_path
    end
  end

  test "owner can apply an individually reviewed AI recommendation as draft only" do
    initial = @offering.draft_version
    @catalogue.approve!(
      offering: @offering, version: initial.version, digest: initial.digest, confirmed: true
    )
    original = @offering.reload.approved_version
    other_offering = @catalogue.create_draft!(service_fields(@caps.last,
      title: "Review a synthetic React web component"))
    row = suggestion_for(original)
    entry = stored_suggestion(@profile, row)

    sign_in(@owner)
    get owner_catalogue_ai_path
    assert_response :success
    assert_select ".wa-services__copilot-item", count: 1
    assert_select "form[action=?]", apply_owner_catalogue_ai_path(@offering), count: 1

    assert_difference("ServiceOfferingVersion.count", 1) do
      post apply_owner_catalogue_ai_path(@offering),
           params: { entry_id: entry.id, base_digest: original.digest }
    end
    assert_redirected_to owner_service_path(@offering)
    @offering.reload
    assert_equal original.id, @offering.approved_version_id
    assert_nil @offering.published_version
    assert_equal row["title"], @offering.draft_version.title
    assert_equal row["project_category"], @offering.draft_version.project_category
    assert_equal original.title, original.reload.title
    assert other_offering.reload.draft_version
    assert_equal 0, ServiceOfferingPublication.count

    # Replay is rejected, not applied twice.
    assert_no_difference("ServiceOfferingVersion.count") do
      post apply_owner_catalogue_ai_path(@offering),
           params: { entry_id: entry.id, base_digest: original.digest }
    end
    assert_redirected_to owner_catalogue_ai_path
  end

  test "owner applies every current recommendation atomically into draft versions" do
    first = @offering.draft_version
    @catalogue.approve!(offering: @offering, version: first.version,
                        digest: first.digest, confirmed: true)
    original = @offering.reload.approved_version
    second = @catalogue.create_draft!(
      service_fields(@caps.last, title: "Review an isolated fictional React form")
    )
    row1 = suggestion_for(original)
    row2 = suggestion_for(second.draft_version)
    row2["title"] = "Review a limited synthetic React form"
    entry = stored_suggestion(@profile, [row1, row2])
    copilot = OwnerServices::CatalogueCopilot.new(workspace: @workspace)
    key = copilot.batch_fingerprint(entry: entry)

    sign_in(@owner)
    get owner_catalogue_ai_path
    assert_select "form[action=?]", apply_all_owner_catalogue_ai_path

    assert_difference("ServiceOfferingVersion.count", 1) do
      post apply_all_owner_catalogue_ai_path,
           params: { entry_id: entry.id, fingerprint: key }
    end
    assert_redirected_to owner_catalogue_ai_path
    assert_equal row1["title"], @offering.reload.draft_version.title
    assert_equal original.id, @offering.approved_version_id
    assert_equal row2["title"], second.reload.draft_version.title
    assert_equal 0, ServiceOfferingPublication.count

    assert_no_difference("ServiceOfferingVersion.count") do
      post apply_all_owner_catalogue_ai_path,
           params: { entry_id: entry.id, fingerprint: key }
    end
    assert_redirected_to owner_catalogue_ai_path
  end

  test "stale batch cannot partially overwrite another service" do
    other = @catalogue.create_draft!(
      service_fields(@caps.last, title: "A fictional frontend review")
    )
    row1 = suggestion_for(@offering.draft_version)
    row2 = suggestion_for(other.draft_version)
    entry = stored_suggestion(@profile, [row1, row2])
    key = OwnerServices::CatalogueCopilot.new(workspace: @workspace).batch_fingerprint(entry: entry)

    sign_in(@owner)
    @catalogue.update_draft!(
      offering: other, version: other.draft_version.version,
      digest: other.draft_version.digest,
      attributes: service_fields(@caps.last, title: "Modified synthetic frontend work")
    )

    before = @offering.reload.draft_version.digest
    post apply_all_owner_catalogue_ai_path,
         params: { entry_id: entry.id, fingerprint: key }
    assert_redirected_to owner_catalogue_ai_path
    assert_equal before, @offering.reload.draft_version.digest
    assert_equal "Modified synthetic frontend work", other.reload.draft_version.title
  end

  test "stale, forged digest, client and foreign owner cannot apply AI copy" do
    row = suggestion_for(@offering.draft_version)
    entry = stored_suggestion(@profile, row)
    sign_in(@client)
    post apply_owner_catalogue_ai_path(@offering),
         params: { entry_id: entry.id, base_digest: row["base_digest"] }
    assert_redirected_to sign_in_path
    delete sign_out_path

    sign_in(@other)
    post apply_owner_catalogue_ai_path(@offering),
         params: { entry_id: entry.id, base_digest: row["base_digest"] }
    assert_redirected_to owner_catalogue_ai_path
    delete sign_out_path

    sign_in(@owner)
    post apply_owner_catalogue_ai_path(@offering),
         params: { entry_id: entry.id, base_digest: "a" * 64 }
    assert_redirected_to owner_catalogue_ai_path

    draft = @offering.draft_version
    @catalogue.update_draft!(
      offering: @offering, version: draft.version, digest: draft.digest,
      attributes: service_fields(@caps.first, title: "A manually changed fictional Rails service")
    )
    post apply_owner_catalogue_ai_path(@offering),
         params: { entry_id: entry.id, base_digest: row["base_digest"] }
    assert_redirected_to owner_catalogue_ai_path
    assert_equal "A manually changed fictional Rails service", @offering.reload.draft_version.title
  end

  private

  def sign_in(user)
    post account_session_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to(user.role == "client" ? client_home_path : workspace_path)
  end

  def suggestion_for(version)
    {
      "offering_id" => version.service_offering_id,
      "base_version" => version.version,
      "base_digest" => version.digest,
      "project_category" => version.project_category,
      "title" => "Improved synthetic Rails bugfix review",
      "summary" => "Investigate one reproducible synthetic Rails error and document a bounded, testable correction.",
      "included_scope" => "Reproduce one isolated bug, implement a limited change and add a regression test.",
      "excluded_scope" => "No production access, unlimited support, ongoing operations or security audit.",
      "requirements_prompt" => "Provide fictional reproduction steps and redacted error logs.",
      "rationale" => "Better distinguish diagnosis from guaranteed outcomes.",
      "risk_flags" => ["Keep unsupported results out of the offer."]
    }
  end

  def stored_suggestion(profile, row)
    rows = row.is_a?(Array) ? row : [row]
    AiSpendEntry.create!(
      professional_profile: profile,
      operation: OwnerServices::CatalogueCopilot::OPERATION,
      model: "grok-4.3", request_digest: Digest::SHA256.hexdigest("copilot-#{profile.id}-#{rows.first["base_digest"]}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: { "recommendations" => rows }, resolved_at: Time.current
    )
  end
end
