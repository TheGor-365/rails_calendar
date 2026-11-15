class OwnerAvatarsController < ApplicationController
  ALLOWED = {
    "image/jpeg" => %w[.jpg .jpeg],
    "image/png" => %w[.png],
    "image/webp" => %w[.webp]
  }.freeze
  MAX_BYTES = 3.megabytes

  before_action :require_owner!
  before_action :require_local_only!

  def create
    file = params.require(:avatar).require(:file)
    unless file.respond_to?(:tempfile) &&
           ALLOWED.fetch(file.content_type.to_s.downcase, []).include?(File.extname(file.original_filename.to_s).downcase) &&
           file.size.positive? && file.size <= MAX_BYTES
      return redirect_to owner_cabinet_path(anchor: "owner-avatar"), alert: t("account_hub.avatar_invalid")
    end

    # Append rather than replace: avatar history is never silently deleted.
    current_user.owner_avatars.attach(file)
    redirect_to owner_cabinet_path(anchor: "owner-avatar"), notice: t("account_hub.avatar_uploaded")
  rescue ActionController::ParameterMissing
    redirect_to owner_cabinet_path(anchor: "owner-avatar"), alert: t("account_hub.avatar_invalid")
  end

  def file
    attachment = current_user.owner_avatars_attachments.find_by(id: params[:attachment_id])
    return head :not_found unless attachment && ALLOWED.key?(attachment.blob.content_type)

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data attachment.blob.download,
              type: attachment.blob.content_type,
              disposition: "inline", filename: attachment.blob.filename.to_s
  end

  private

  def require_owner!
    redirect_to sign_in_path unless owner_signed_in?
  end

  def require_local_only!
    head :not_found unless Rails.env.test? || (Rails.env.development? && request.local?)
  end
end
