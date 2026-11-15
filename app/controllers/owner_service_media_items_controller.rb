class OwnerServiceMediaItemsController < ApplicationController
  before_action :require_owner!
  before_action :require_local_pilot!
  before_action :load_offering
  before_action :load_media, only: %i[approve archive file]

  def create
    source = @offering.draft_version || @offering.approved_version || @offering.published_version
    return head :not_found unless source

    attributes = params.require(:media).permit(:media_kind, :caption, :file)
    @media = @offering.media_items.build(
      media_kind: attributes[:media_kind],
      caption: attributes[:caption].to_s.strip,
      service_offering_version: source,
      uploaded_by_user: current_user
    )
    @media.file.attach(attributes[:file]) if attributes[:file].present?

    if @media.save
      redirect_to owner_service_path(@offering, anchor: "offering-media"),
                  notice: t("owner_services.media_uploaded")
    else
      redirect_to owner_service_path(@offering, anchor: "offering-media"),
                  alert: t("owner_services.media_invalid")
    end
  rescue ActionController::ParameterMissing
    redirect_to owner_service_path(@offering, anchor: "offering-media"),
                alert: t("owner_services.media_invalid")
  end

  def approve
    @media.with_lock do
      raise ActiveRecord::RecordInvalid, @media if @media.archived_at.present? || @media.approved?
      @media.update!(approved_at: Time.current)
    end
    redirect_to owner_service_path(@offering, anchor: "offering-media"),
                notice: t("owner_services.media_approved")
  rescue ActiveRecord::RecordInvalid
    redirect_to owner_service_path(@offering, anchor: "offering-media"),
                alert: t("owner_services.media_invalid")
  end

  def archive
    @media.with_lock do
      raise ActiveRecord::RecordInvalid, @media if @media.archived_at.present?
      @media.update!(archived_at: Time.current)
    end
    redirect_to owner_service_path(@offering, anchor: "offering-media"),
                notice: t("owner_services.media_archived")
  rescue ActiveRecord::RecordInvalid
    redirect_to owner_service_path(@offering, anchor: "offering-media"),
                alert: t("owner_services.media_invalid")
  end

  def file
    return head :not_found unless @media.file.attached? && @media.archived_at.nil?

    blob = @media.file.blob
    # Never issue Active Storage signed URLs or redirects. This controller
    # verifies owner/workspace/media relationships for every byte request.
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data blob.download,
              type: @media.image? ? blob.content_type : "application/octet-stream",
              disposition: @media.image? ? "inline" : "attachment",
              filename: blob.filename.to_s
  end

  private

  def require_owner!
    redirect_to sign_in_path unless owner_signed_in?
  end

  def require_local_pilot!
    head :not_found unless Rails.env.test? || (Rails.env.development? && request.local?)
  end

  def load_offering
    workspace = current_user.owner_workspace
    @offering = workspace&.service_offerings&.find_by(id: params[:id])
    head :not_found unless @offering
  end

  def load_media
    @media = @offering.media_items.find_by(id: params[:media_id])
    head :not_found unless @media
  end
end
