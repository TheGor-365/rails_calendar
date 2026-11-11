module Studio
  class ClientSession < ApplicationRecord
    self.table_name = "studio_client_sessions"
    belongs_to :client_account, class_name: "Studio::ClientAccount",
               foreign_key: :studio_client_account_id

    validates :token_digest, presence: true, uniqueness: true,
              format: { with: /\A[0-9a-f]{64}\z/ }
    validates :expires_at, presence: true

    def active?
      expires_at.future? && client_account.active?
    end
  end
end
