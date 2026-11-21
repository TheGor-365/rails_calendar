# Private client photo storage; separate from owner media and publication.
class ClientAvatarsController < ApplicationController
  ALLOWED = { "image/jpeg" => %w[.jpg .jpeg], "image/png" => %w[.png],
              "image/webp" => %w[.webp] }.freeze
  MAX_BYTES = 3.megabytes

  before_action :require_verified_client!
  before_action :require_local_only!

  def create
    file = params.require(:avatar).require(:file)
    return redirect_to client_cabinet_path(anchor: "client-avatar"),
                       alert: t("account_hub.avatar_invalid") unless valid_avatar?(file)

    # Append revisions and keep the older media intact.
    current_user.client_avatars.attach(file)
    redirect_to client_cabinet_path(anchor: "client-avatar"), notice: t("account_hub.avatar_uploaded")
  rescue ActionController::ParameterMissing
    redirect_to client_cabinet_path(anchor: "client-avatar"), alert: t("account_hub.avatar_invalid")
  end

  def file
    attachment = current_user.client_avatars_attachments.find_by(id: params[:attachment_id])
    return head :not_found unless attachment && ALLOWED.key?(attachment.blob.content_type)

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data attachment.blob.download, type: attachment.blob.content_type,
              disposition: "inline", filename: attachment.blob.filename.to_s
  rescue ActiveStorage::FileNotFoundError
    head :not_found
  end

  private

  def valid_avatar?(file)
    return false unless file.respond_to?(:tempfile)
    mime = file.content_type.to_s.downcase
    ALLOWED.fetch(mime, []).include?(File.extname(file.original_filename.to_s).downcase) &&
      file.size.positive? && file.size <= MAX_BYTES &&
      Marcel::MimeType.for(file.tempfile, name: file.original_filename) == mime
  end

  def require_verified_client!
    redirect_to sign_in_path unless client_signed_in?
  end

  def require_local_only!
    head :not_found unless Rails.env.test? || (Rails.env.development? && request.local?)
  end
end
