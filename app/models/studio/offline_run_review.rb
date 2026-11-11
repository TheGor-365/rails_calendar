require "json"
require "openssl"

module Studio
  # Separate, immutable synthetic-review decision, never a client approval.
  class OfflineRunReview < ApplicationRecord
    self.table_name = "studio_offline_run_reviews"
    DECISIONS = %w[reviewed_synthetic discarded_synthetic].freeze
    VERSION = "rc037-offline-review-v1"

    belongs_to :workspace
    belongs_to :offline_run, class_name: "Studio::OfflineRun",
               foreign_key: :studio_offline_run_id
    belongs_to :reviewer_user, class_name: "User"

    validates :decision, inclusion: { in: DECISIONS }
    validates :recorded_at, presence: true
    validates :run_digest, :event_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validate :verified_run_scope
    before_update :block_mutation
    before_destroy :block_mutation

    def self.compute_digest(studio_offline_run_id:, workspace_id:, client_id:,
                            project_intake_id:, reviewer_user_id:, decision:,
                            run_digest:, recorded_at:)
      values = [VERSION, studio_offline_run_id, workspace_id, client_id,
                project_intake_id, reviewer_user_id, decision, run_digest,
                recorded_at.utc.iso8601(6)]
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, JSON.generate(values))
    end

    def verify!
      offline_run.verified_payload!
      unless verified_scope? &&
             ActiveSupport::SecurityUtils.secure_compare(run_digest, offline_run.event_digest) &&
             ActiveSupport::SecurityUtils.secure_compare(event_digest, self.class.compute_digest(
               studio_offline_run_id: studio_offline_run_id, workspace_id: workspace_id,
               client_id: client_id, project_intake_id: project_intake_id,
               reviewer_user_id: reviewer_user_id, decision: decision,
               run_digest: run_digest, recorded_at: recorded_at
             ))
        raise SecurityError, "Offline synthetic review integrity failure"
      end
      true
    end

    private

    def verified_scope?
      workspace_id == offline_run&.workspace_id &&
        client_id == offline_run&.client_id &&
        project_intake_id == offline_run&.project_intake_id &&
        workspace&.owner_access?(reviewer_user)
    end

    def verified_run_scope
      errors.add(:base, "Review must match an active owner and exact run scope") unless verified_scope?
      errors.add(:run_digest, "must match the recorded run") if offline_run && run_digest != offline_run.event_digest
    end

    def block_mutation
      errors.add(:base, "Offline review decisions are append-only")
      throw :abort
    end
  end
end
