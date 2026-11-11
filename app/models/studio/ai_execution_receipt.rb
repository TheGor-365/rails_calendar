require "digest"
require "json"

module Studio
  # An immutable receipt for an executed $0 deterministic plan only.
  # This is NOT a paid-model budget reservation or an approval record.
  class AiExecutionReceipt < ApplicationRecord
    self.table_name = "studio_ai_execution_receipts"
    belongs_to :workspace
    belongs_to :project_intake
    belongs_to :requested_by, class_name: "User"

    validates :state, inclusion: { in: ["completed_offline"] }
    validates :purpose, inclusion: { in: ["document_plan"] }
    validates :registry_key, inclusion: { in: ["offline_document_plan_v1"] }
    validates :request_fingerprint, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :tokens_reserved, :tokens_used, :usd_reserved, :usd_used, numericality: { equal_to: 0 }
    validates :completed_at, presence: true

    before_update :prevent_changes
    before_destroy :prevent_changes

    def self.record_offline!(actor:, workspace:, intake:, purpose:, evidence:, registry_key:)
      access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      access.assert_owner!
      unless (Rails.env.test? || (Rails.env.development? &&
              ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true")) && !Rails.env.production?
        raise SecurityError, "Offline receipt unavailable in production"
      end
      unless intake.is_a?(ProjectIntake) && intake.workspace_id == workspace.id &&
             intake.client_id.present? && workspace.clients.exists?(id: intake.client_id)
        raise SecurityError, "Assigned intake required"
      end
      raise ArgumentError, "Unsupported local model" unless purpose == "document_plan" &&
        registry_key == "offline_document_plan_v1" && evidence.is_a?(Hash) &&
        evidence.keys.all? { |key| key.is_a?(String) } &&
        evidence.values.all? { |value| value == true || value == false }

      # Non-sensitive evidence flags only, canonicalized by key for retry safety.
      fingerprint = Digest::SHA256.hexdigest(
        JSON.generate(["rc037-offline-v1", workspace.id, intake.id,
                       registry_key, purpose, evidence.sort.to_h])
      )
      create_or_find_by!(workspace_id: workspace.id,
                         project_intake_id: intake.id,
                         request_fingerprint: fingerprint) do |row|
        row.requested_by = actor
        row.purpose = purpose
        row.registry_key = registry_key
        row.state = "completed_offline"
        row.completed_at = Time.current
      end
    end

    private

    def prevent_changes
      errors.add(:base, "Completed AI audit receipt is immutable")
      throw :abort
    end
  end
end
