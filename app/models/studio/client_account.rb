require "openssl"

module Studio
  # Isolated client credential store. Does not extend User(owner) or workspace roles.
  # Store deterministic HMAC of mailbox, not a recoverable email address.
  class ClientAccount < ApplicationRecord
    self.table_name = "studio_client_accounts"
    has_secure_password
    has_many :client_sessions, class_name: "Studio::ClientSession",
             foreign_key: :studio_client_account_id, dependent: :restrict_with_exception
    has_many :client_project_grants, class_name: "Studio::ClientProjectGrant",
             foreign_key: :studio_client_account_id, dependent: :restrict_with_exception

    validates :email_digest, presence: true, uniqueness: true,
              format: { with: /\A[0-9a-f]{64}\z/ }
    validates :status, inclusion: { in: %w[active suspended] }
    validates :password, length: { minimum: 12, maximum: 72 }, if: -> { password.present? }

    def active?
      status == "active"
    end

    def self.email_digest_for(raw)
      email = raw.to_s.strip.downcase
      unless email.bytesize.between?(3, 254) && email.match?(URI::MailTo::EMAIL_REGEXP)
        raise ArgumentError, "Invalid client mailbox"
      end
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
                            "rc036-invite-recipient-v1:#{email}")
    end
  end
end
