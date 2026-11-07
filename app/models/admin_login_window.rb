# Each PostgreSQL row is an atomic per-minute counter shared across Rails
# workers/instances. Raw IPs and credentials never enter the table.
class AdminLoginWindow < ApplicationRecord
  WINDOW_SECONDS = 60
  MAX_ATTEMPTS = 5
  RETENTION_SECONDS = 2.days.to_i

  def self.throttled?(remote_ip:, now: Time.current)
    epoch = (now.to_i / WINDOW_SECONDS) * WINDOW_SECONDS
    digest = OpenSSL::HMAC.hexdigest(
      "SHA256", Rails.application.secret_key_base, "rails-calendar-admin-login:\#{remote_ip}"
    )

    sql = <<~SQL
      INSERT INTO admin_login_windows
        (client_digest, window_start_epoch, attempts, created_at, updated_at)
      VALUES ($1, $2, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (client_digest, window_start_epoch)
      DO UPDATE SET
        attempts = admin_login_windows.attempts + 1,
        updated_at = CURRENT_TIMESTAMP
      RETURNING attempts
    SQL

    binds = [
      ActiveRecord::Relation::QueryAttribute.new(
        "client_digest", digest, ActiveRecord::Type::String.new
      ),
      ActiveRecord::Relation::QueryAttribute.new(
        "window_start_epoch", epoch, ActiveRecord::Type::Integer.new(limit: 8)
      )
    ]

    attempts = connection.exec_query(sql, "Admin login rate-limit", binds).rows.first.first.to_i
    attempts > MAX_ATTEMPTS
  end

  # Invoke from a scheduled, independently monitored maintenance job.
  # This is not tied to login requests to keep their latency predictable.
  def self.prune_expired!(now: Time.current)
    where("window_start_epoch < ?", now.to_i - RETENTION_SECONDS).delete_all
  end
end
