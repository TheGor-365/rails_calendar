class UserSession < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true,
                           format: { with: /\A[0-9a-f]{64}\z/ }
  validates :expires_at, presence: true

  def active?
    expires_at.future?
  end
end
