module OwnerAvatarHelper
  def local_owner_avatar_enabled?
    Rails.env.test? || (Rails.env.development? && request.local?)
  end

  def local_owner_avatar_attachment(user)
    return nil unless local_owner_avatar_enabled? && user&.role == "owner"
    user.owner_avatars_attachments.order(created_at: :desc, id: :desc).first
  end
end
