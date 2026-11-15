require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServicesAutoCatalogueTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("auto-catalogue-owner@example.test")
    @interests = %w[rails_bugfix rails_crud rails_api rails_tests websites
                    automation ai_integrations data_tasks adjacent_web]
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(
      @owner, capabilities: %w[rails api testing html_css automation postgresql react],
      desired_services: @interests
    )
    @generator = OwnerServices::AutoCatalogue.new(workspace: @workspace)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
  end

  test "approved v1 creates at most one private draft per interested service" do
    result = nil
    assert_difference "ServiceOffering.count", 9 do
      assert_difference "ServiceOfferingVersion.count", 9 do
        result = @generator.sync!
      end
    end
    assert_equal 9, result.created
    assert_equal 0, result.revised
    assert_equal 0, ServiceOfferingPublication.count
    assert @workspace.service_offerings.pluck(:key).all? { |key| key.start_with?("auto-") }
    @workspace.service_offerings.each do |offering|
      draft = offering.draft_version
      assert_equal @snapshot.id, draft.professional_context_snapshot_id
      assert draft.summary.length >= 25
      assert draft.included_scope.length >= 15
      assert draft.excluded_scope.length >= 10
      assert_nil offering.approved_version_id
      assert_nil offering.published_version_id
      assert_equal 64, draft.digest.length
    end
    conditional = @workspace.service_offerings.find_by!(key: "auto-ai-integrations").draft_version
    assert_equal "conditional", conditional.delivery_mode
    assert_match(/предварительная проверка/, conditional.summary)
  end

  test "repeat does not create duplicate offers or override owner-edited copy" do
    @generator.sync!
    offer = @workspace.service_offerings.find_by!(key: "auto-rails-bugfix")
    draft = offer.draft_version
    @catalogue.update_draft!(
      offering: offer,
      attributes: service_fields(@capabilities.first, title: "Индивидуальный текст владельца Rails"),
      version: draft.version, digest: draft.digest
    )
    assert_no_difference ["ServiceOffering.count", "ServiceOfferingVersion.count"] do
      result = @generator.sync!
      assert_equal 0, result.created
      assert_equal 0, result.revised
      assert_equal 9, result.unchanged
    end
    assert_equal "Индивидуальный текст владельца Rails", offer.reload.draft_version.title
  end

  test "next approved profile creates only a private v2 without replacing approved or enabled v1" do
    @generator.sync!
    offer = @workspace.service_offerings.find_by!(key: "auto-rails-bugfix")
    first = offer.draft_version
    approved = @catalogue.approve!(
      offering: offer, version: first.version, digest: first.digest, confirmed: true
    )
    @catalogue.publish!(
      offering: offer, version_id: approved.id, digest: approved.digest,
      confirmed: true, owner: @owner
    )

    create_next_approved_snapshot!(version: 2, desired_services: ["rails_bugfix"])
    result = @generator.sync!
    assert_equal 1, result.revised
    assert_equal 0, result.created
    assert_equal 2, offer.reload.draft_version.version
    assert_equal 2, offer.draft_version.professional_context_snapshot.version
    assert_equal approved.id, offer.approved_version_id
    assert_equal approved.id, offer.published_version_id
    assert_nil offer.draft_version.approved_at

    assert_no_difference "ServiceOfferingVersion.count" do
      @generator.sync!
    end
  end

  test "old manually edited draft is deferred after a new profile snapshot" do
    @generator.sync!
    offer = @workspace.service_offerings.find_by!(key: "auto-rails-bugfix")
    previous_id = offer.draft_version.id
    create_next_approved_snapshot!(version: 2, desired_services: ["rails_bugfix"])
    result = @generator.sync!
    assert_equal 1, result.deferred
    assert_equal previous_id, offer.reload.draft_version.id
    assert_equal 1, offer.draft_version.professional_context_snapshot.version
  end

  test "excluded work, absent approved interest, and pending corrections never generate offers" do
    @profile.update!(onboarding_state: "draft")
    assert_raises(OwnerServices::Catalogue::PolicyError) { @generator.sync! }
    @profile.update!(onboarding_state: "approved")

    create_next_approved_snapshot!(version: 2, desired_services: %w[unknown_interview_option])
    result = @generator.sync!
    assert_equal 0, result.created
    assert_equal 0, ServiceOffering.count
  end

  private

  def create_next_approved_snapshot!(version:, desired_services:)
    @profile.professional_context_snapshots.create!(
      version: version, digest: Digest::SHA256.hexdigest("synthetic-current-context-v#{version}"),
      payload: { "source" => "owner_confirmed", "desired_services" => desired_services },
      approved_at: Time.current
    )
    @profile.professional_capabilities.create!(
      snapshot_version: version, domain: "rails", delivery_mode: "direct",
      experience_claim: "practiced", evidence_status: "self_reported",
      willingness: "actively_offer", privacy_scope: "private",
      review_required: true, conditions: "Synthetic owner-only declaration"
    )
  end
end
