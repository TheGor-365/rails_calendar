require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerServicesCatalogueTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("owner-services-service@example.test")
    @workspace, @profile, @snapshot, @capabilities = approved_profile_for(@owner)
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
  end

  test "creation is private and binds the exact approved source and capability" do
    assert_difference({"ServiceOffering.count" => 1, "ServiceOfferingVersion.count" => 1}) do
      @offering = @catalogue.create_draft!(service_fields(@capabilities.first))
    end
    draft = @offering.draft_version
    assert_equal 1, draft.version
    assert_equal @snapshot.id, draft.professional_context_snapshot_id
    assert_equal @capabilities.first.id, draft.professional_capability_id
    assert_equal "direct", draft.delivery_mode
    assert_equal 64, draft.digest.length
    assert_nil draft.approved_at
    assert_nil @offering.approved_version
    assert_nil @offering.published_version
    assert_equal 0, ServiceOfferingPublication.count
  end

  test "owner must approve and separately enable, and the publication journal is immutable" do
    offer = @catalogue.create_draft!(service_fields(@capabilities.first))
    draft = offer.draft_version
    assert_raises(OwnerServices::Catalogue::PolicyError) do
      @catalogue.approve!(offering: offer, version: draft.version, digest: draft.digest, confirmed: false)
    end
    assert_nil offer.reload.approved_version
    approved = @catalogue.approve!(offering: offer, version: draft.version, digest: draft.digest, confirmed: true)
    assert approved.approved?
    assert_nil offer.reload.published_version
    assert_raises(ActiveRecord::ReadOnlyError) { approved.update!(title: "Changed approved description") }
    assert_raises(ActiveRecord::ReadOnlyError) { approved.destroy! }

    assert_raises(OwnerServices::Catalogue::PolicyError) do
      @catalogue.publish!(offering: offer, version_id: approved.id, digest: approved.digest, confirmed: false, owner: @owner)
    end
    assert_nil offer.reload.published_version

    assert_difference("ServiceOfferingPublication.count", 1) do
      @catalogue.publish!(offering: offer, version_id: approved.id, digest: approved.digest, confirmed: true, owner: @owner)
    end
    assert_equal approved.id, offer.reload.published_version_id
    publication = offer.publications.last
    assert_equal "publish", publication.event
    assert_equal approved.id, publication.service_offering_version_id
    assert_raises(ActiveRecord::ReadOnlyError) { publication.update!(event: "unpublish") }

    assert_difference("ServiceOfferingPublication.count", 1) do
      @catalogue.unpublish!(offering: offer, owner: @owner, confirmed: true)
    end
    assert_nil offer.reload.published_version
    assert_equal %w[publish unpublish], offer.publications.order(:id).pluck(:event)
  end

  test "replay and stale versions fail without modifying approved content" do
    offer = @catalogue.create_draft!(service_fields(@capabilities.first))
    original = offer.draft_version
    old_digest = original.digest

    @catalogue.update_draft!(
      offering: offer,
      attributes: service_fields(@capabilities.first).merge(summary: "Revised fictional brief with a clearer QA check and narrower limits."),
      version: original.version, digest: old_digest
    )
    revised = offer.reload.draft_version
    refute_equal old_digest, revised.digest

    assert_raises(OwnerServices::Catalogue::Conflict) do
      @catalogue.update_draft!(
        offering: offer, attributes: service_fields(@capabilities.first).merge(title: "Second stale edit"),
        version: revised.version, digest: old_digest
      )
    end
    assert_raises(OwnerServices::Catalogue::Conflict) do
      @catalogue.approve!(offering: offer, version: revised.version, digest: old_digest, confirmed: true)
    end
    assert_nil offer.reload.approved_version
    approved = @catalogue.approve!(
      offering: offer, version: revised.version, digest: revised.digest, confirmed: true
    )
    assert_equal "Fix a fictional Rails error", approved.title
    assert_raises(OwnerServices::Catalogue::Conflict) do
      @catalogue.approve!(offering: offer, version: approved.version, digest: approved.digest, confirmed: true)
    end
  end

  test "conditional AI-assisted capability stays conditional and cannot be elevated" do
    assisted = @capabilities.last
    offer = @catalogue.create_draft!(service_fields(assisted, title: "Investigate a fictional React prototype"))
    draft = offer.draft_version
    assert_equal "conditional", draft.delivery_mode
    assert_raises(ActiveRecord::RecordInvalid) do
      draft.update!(delivery_mode: "direct")
    end
    refute draft.reload.approved?
  end

  test "a second owner or excluded capability cannot be used as source" do
    other = make_test_owner("owner-services-other@example.test")
    other_workspace, other_profile, other_snap, other_caps = approved_profile_for(other)
    assert_raises(OwnerServices::Catalogue::PolicyError) do
      @catalogue.create_draft!(service_fields(other_caps.first))
    end
    @capabilities.first.update_column(:willingness, "not_interested") # Test fixture only: approved source itself remains unchanged in real app.
    assert_raises(OwnerServices::Catalogue::PolicyError) do
      @catalogue.create_draft!(service_fields(@capabilities.first))
    end
    assert_equal 0, @workspace.service_offerings.count
  end

  test "profile revisions block old approval and publication; new revision preserves old versions" do
    offer = @catalogue.create_draft!(service_fields(@capabilities.first))
    draft = offer.draft_version
    @profile.update!(onboarding_state: "draft")
    assert_raises(OwnerServices::Catalogue::PolicyError) do
      @catalogue.approve!(offering: offer, version: draft.version, digest: draft.digest, confirmed: true)
    end
    @profile.update!(onboarding_state: "approved")
    approved_v1 = @catalogue.approve!(offering: offer, version: draft.version, digest: draft.digest, confirmed: true)
    @catalogue.publish!(offering: offer, version_id: approved_v1.id, digest: approved_v1.digest, confirmed: true, owner: @owner)

    @profile.professional_context_snapshots.create!(
      version: 2, digest: Digest::SHA256.hexdigest("second fictional context"),
      payload: { "source" => "owner_confirmed" }, approved_at: Time.current
    )
    new_cap = @profile.professional_capabilities.create!(
      snapshot_version: 2, domain: "rails", delivery_mode: "direct",
      experience_claim: "practiced", evidence_status: "self_reported",
      willingness: "actively_offer", privacy_scope: "private", review_required: true,
      conditions: "synthetic"
    )
    assert_raises(OwnerServices::Catalogue::Conflict) do
      @catalogue.publish!(offering: offer, version_id: approved_v1.id, digest: approved_v1.digest, confirmed: true, owner: @owner)
    end

    draft_v2 = @catalogue.new_revision!(offering: offer)
    assert_equal 2, draft_v2.version
    assert_equal new_cap.id, draft_v2.professional_capability_id
    assert_equal approved_v1.id, offer.reload.published_version_id
    assert_equal approved_v1.title, draft_v2.title
    assert_raises(ActiveRecord::ReadOnlyError) { approved_v1.update!(summary: "Overwritten") }
    approved_v2 = @catalogue.approve!(
      offering: offer, version: draft_v2.version, digest: draft_v2.digest, confirmed: true
    )
    assert_equal approved_v2.id, offer.reload.approved_version_id
    assert_equal approved_v1.id, offer.published_version_id, "Publishing requires another distinct approval"
  end
end
