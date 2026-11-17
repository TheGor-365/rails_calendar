# Do not show avatars outside their verified client's local session.
module ClientAvatarHelper
  def local_client_avatar_enabled?
    Rails.env.test? || (Rails.env.development? && request.local?)
  end

  def local_client_avatar_attachment(user)
    return nil unless local_client_avatar_enabled? && user&.verified_client?

    user.client_avatars_attachments.order(created_at: :desc, id: :desc).first
  end
end
