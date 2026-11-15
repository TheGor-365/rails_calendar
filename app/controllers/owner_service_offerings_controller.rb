class OwnerServiceOfferingsController < ApplicationController
  before_action :require_owner!
  before_action :load_catalogue
  before_action :load_offering, only: %i[show update_draft approve publish unpublish new_revision]

  def index
    @offerings = @workspace.service_offerings.includes(
      :approved_version, :published_version, :versions
    ).order(:position, :id)
    @bulk_approval = OwnerServices::BulkApproval.new(workspace: @workspace)
    @draft_count = @bulk_approval.drafts.size
    @draft_fingerprint = @bulk_approval.fingerprint
    @media_cover_by_offering_id = {}
    if Rails.env.test? || (Rails.env.development? && request.local?)
      ServiceOfferingMediaItem.visible
        .where(service_offering_id: @offerings.map(&:id), media_kind: %w[banner image])
        .where.not(approved_at: nil)
        .includes(file_attachment: :blob).each do |media|
          current = @media_cover_by_offering_id[media.service_offering_id]
          if current.nil? || (media.media_kind == "banner" && current.media_kind != "banner")
            @media_cover_by_offering_id[media.service_offering_id] = media
          end
        end
    end
  end

  def approve_all
    count = OwnerServices::BulkApproval.new(workspace: @workspace).approve_all!(
      expected_fingerprint: params[:fingerprint]
    )
    redirect_to owner_services_path, notice: t("owner_services.bulk_approved", count: count)
  rescue OwnerServices::BulkApproval::Conflict, OwnerServices::Catalogue::Conflict
    redirect_to owner_services_path, alert: t("owner_services.stale")
  rescue OwnerServices::Catalogue::PolicyError, ActiveRecord::RecordInvalid
    redirect_to owner_services_path, alert: t("owner_services.review_required")
  end

  def sync
    result = OwnerServices::AutoCatalogue.new(workspace: @workspace).sync!
    redirect_to owner_services_path,
                notice: t("owner_services.auto_sync_result", created: result.created,
                          revised: result.revised, deferred: result.deferred)
  rescue OwnerServices::Catalogue::PolicyError, ActiveRecord::RecordInvalid
    redirect_to owner_services_path, alert: t("owner_services.auto_sync_blocked")
  end

  def new
    @form_values = { "project_category" => "rails_bugfix" }
  end

  def create
    @form_values = offering_params.to_h
    @offering = @catalogue.create_draft!(offering_params.to_h.symbolize_keys)
    redirect_to owner_service_path(@offering), notice: t("owner_services.created")
  rescue ActiveRecord::RecordInvalid, OwnerServices::Catalogue::PolicyError,
         ActionController::ParameterMissing
    @error = t("owner_services.invalid")
    render :new, status: :unprocessable_entity
  end

  def show
    @draft = @offering.draft_version
    @approved = @offering.approved_version
    @published = @offering.published_version
    @history = @offering.versions.order(version: :desc)
    @publications = @offering.publications.order(id: :desc).limit(12)
    @eligible = current_capability?(@draft || @approved)
    @media_enabled = Rails.env.test? || (Rails.env.development? && request.local?)
    @media_items = @media_enabled ? @offering.media_items.visible.includes(:service_offering_version).to_a : []
  end

  def update_draft
    @catalogue.update_draft!(
      offering: @offering, attributes: offering_params.to_h.symbolize_keys,
      version: params[:base_version], digest: params[:base_digest]
    )
    redirect_to owner_service_path(@offering), notice: t("owner_services.saved")
  rescue ActiveRecord::RecordInvalid, OwnerServices::Catalogue::PolicyError,
         ActionController::ParameterMissing
    redirect_to owner_service_path(@offering), alert: t("owner_services.invalid")
  rescue OwnerServices::Catalogue::Conflict
    redirect_to owner_service_path(@offering), alert: t("owner_services.stale")
  end

  def approve
    @catalogue.approve!(
      offering: @offering, version: params[:version], digest: params[:digest],
      confirmed: params[:confirm] == "1"
    )
    redirect_to approval_return_path, notice: t("owner_services.approved")
  rescue OwnerServices::Catalogue::Conflict
    redirect_to approval_return_path, alert: t("owner_services.stale")
  rescue OwnerServices::Catalogue::PolicyError, ActiveRecord::RecordInvalid
    redirect_to approval_return_path, alert: t("owner_services.review_required")
  end

  def publish
    @catalogue.publish!(
      offering: @offering, version_id: params[:version_id], digest: params[:digest],
      confirmed: params[:confirm] == "1", owner: current_user
    )
    redirect_to owner_service_path(@offering), notice: t("owner_services.published")
  rescue OwnerServices::Catalogue::Conflict
    redirect_to owner_service_path(@offering), alert: t("owner_services.stale")
  rescue OwnerServices::Catalogue::PolicyError, ActiveRecord::RecordInvalid
    redirect_to owner_service_path(@offering), alert: t("owner_services.review_required")
  end

  def unpublish
    @catalogue.unpublish!(
      offering: @offering, owner: current_user, confirmed: params[:confirm] == "1"
    )
    redirect_to owner_service_path(@offering), notice: t("owner_services.unpublished")
  rescue OwnerServices::Catalogue::Conflict, OwnerServices::Catalogue::PolicyError,
         ActiveRecord::RecordInvalid
    redirect_to owner_service_path(@offering), alert: t("owner_services.stale")
  end

  def new_revision
    @catalogue.new_revision!(offering: @offering)
    redirect_to owner_service_path(@offering), notice: t("owner_services.revision_created")
  rescue OwnerServices::Catalogue::Conflict, OwnerServices::Catalogue::PolicyError,
         ActiveRecord::RecordInvalid
    redirect_to owner_service_path(@offering), alert: t("owner_services.review_required")
  end

  private

  # Only these two internal destinations are allowed; never accept a client
  # supplied redirect URL after a state-changing POST.
  def approval_return_path
    params[:return_to_catalog] == "1" ? owner_services_path : owner_service_path(@offering)
  end

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_catalogue
    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
    @catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    @profile = @catalogue.profile
    @snapshot = @catalogue.snapshot
    @eligible_capabilities = @catalogue.eligible_capabilities.to_a
    @policy = @snapshot && @profile.work_policies.find_by(snapshot_version: @snapshot.version)
  end

  def load_offering
    @offering = @workspace.service_offerings.find_by(id: params[:id])
    head :not_found unless @offering
  end

  def offering_params
    params.require(:service_offering).permit(
      :professional_capability_id, :project_category, :title, :summary,
      :included_scope, :excluded_scope, :requirements_prompt
    )
  end

  def current_capability?(version)
    @snapshot && version && version.professional_context_snapshot_id == @snapshot.id &&
      @eligible_capabilities.any? { |capability| capability.id == version.professional_capability_id } &&
      @profile.onboarding_state == "approved" &&
      @profile.professional_capability_corrections.none?
  end
end
