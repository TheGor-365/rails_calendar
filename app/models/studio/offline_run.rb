require "json"
require "openssl"

module Studio
  # An append-only snapshot of fixed synthetic output, never a client artifact.
  class OfflineRun < ApplicationRecord
    self.table_name = "studio_offline_runs"
    VERSION = "rc037-offline-run-v1"
    MAX_PER_INTAKE = 25

    belongs_to :workspace
    belongs_to :client
    belongs_to :project_intake
    belongs_to :actor_user, class_name: "User"
    has_one :review, class_name: "Studio::OfflineRunReview",
            foreign_key: :studio_offline_run_id, dependent: :restrict_with_exception

    validates :version, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_PER_INTAKE }
    validates :purpose, inclusion: { in: AiPolicy::PURPOSES }
    validates :recorded_at, presence: true
    validates :input_fingerprint, :event_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validate :strict_synthetic_output
    validate :scoped_owner
    before_update :block_mutation
    before_destroy :block_mutation

    def self.compute_digest(workspace_id:, client_id:, project_intake_id:,
                            actor_user_id:, version:, purpose:, input_fingerprint:,
                            output_payload:, recorded_at:)
      fields = [
        VERSION, workspace_id, client_id, project_intake_id, actor_user_id,
        version, purpose, input_fingerprint, output_payload.sort.to_h,
        recorded_at.utc.iso8601(6)
      ]
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, JSON.generate(fields))
    end

    def verified_payload!
      normalized = output_payload.deep_symbolize_keys
      OfflineOutputContract.validate!(normalized)
      unless normalized.fetch(:purpose) == purpose &&
             scoped_owner_valid? &&
             ActiveSupport::SecurityUtils.secure_compare(event_digest, self.class.compute_digest(
               workspace_id: workspace_id, client_id: client_id, project_intake_id: project_intake_id,
               actor_user_id: actor_user_id, version: version, purpose: purpose,
               input_fingerprint: input_fingerprint, output_payload: output_payload,
               recorded_at: recorded_at
             ))
        raise SecurityError, "Offline run integrity failure"
      end
      normalized
    rescue OfflineOutputContract::Denied, ArgumentError, KeyError
      raise SecurityError, "Offline run output contract failure"
    end

    private

    def strict_synthetic_output
      candidate = output_payload.deep_symbolize_keys
      if candidate[:purpose] != purpose
        errors.add(:output_payload, "purpose must match the run")
        return
      end
      OfflineOutputContract.validate!(candidate)
    rescue OfflineOutputContract::Denied, NoMethodError
      errors.add(:output_payload, "must match the synthetic output contract")
    end

    def scoped_owner_valid?
      workspace_id == project_intake&.workspace_id &&
        client_id == project_intake&.client_id &&
        client_id == client&.id && client&.workspace_id == workspace_id &&
        workspace&.owner_access?(actor_user)
    end

    def scoped_owner
      errors.add(:base, "Offline run requires an active exact workspace owner") unless scoped_owner_valid?
    end

    def block_mutation
      errors.add(:base, "Offline runs are append-only")
      throw :abort
    end
  end
end
