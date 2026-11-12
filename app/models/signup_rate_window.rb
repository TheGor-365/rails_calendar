# Shared database-backed throttles. Never store raw IP addresses in this table.
class SignupRateWindow < ApplicationRecord
  PURPOSES = %w[request_ip request_email verify_ip verify_email].freeze

  def self.blocked?(purpose:, identifier:, seconds:, limit:)
    raise ArgumentError unless PURPOSES.include?(purpose) && [60, 600, 3600].include?(seconds) && limit.between?(1, 40)
    digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "rc-signup-limit:#{purpose}:#{identifier}")
    binds = [
      ActiveRecord::Relation::QueryAttribute.new("digest", digest, ActiveRecord::Type::String.new),
      ActiveRecord::Relation::QueryAttribute.new("purpose", purpose, ActiveRecord::Type::String.new),
      ActiveRecord::Relation::QueryAttribute.new("seconds", seconds, ActiveRecord::Type::Integer.new)
    ]
    sql = <<~SQL
      INSERT INTO signup_rate_windows (identity_digest, purpose, window_start_epoch, attempts, created_at, updated_at)
      VALUES ($1, $2, (floor(extract(epoch FROM clock_timestamp()) / $3)::bigint * $3), 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (purpose, identity_digest, window_start_epoch)
      DO UPDATE SET attempts = signup_rate_windows.attempts + 1, updated_at = CURRENT_TIMESTAMP
      RETURNING attempts
    SQL
    connection.exec_query(sql, "Signup throttle", binds).rows.first.first.to_i > limit
  end
end
