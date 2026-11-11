require "openssl"
require "json"

module Studio
  # Immutable through supported Rails model operations. HMAC verifies the
  # append-only chain against accidental or hostile row tampering. This is NOT
  # a substitute for DB-role write restrictions and separately stored backups.
  class AiPolicyRevision < ApplicationRecord
    self.table_name = "studio_ai_policy_revisions"
    GENESIS = "0" * 64
    ACTIONS = %w[created updated].freeze
    ORIGINS = %w[owner_ui internal_unattributed].freeze

    belongs_to :workspace
    belongs_to :ai_policy, class_name: "Studio::AiPolicy",
               foreign_key: :studio_ai_policy_id
    belongs_to :actor_user, class_name: "User", optional: true
    belongs_to :project_intake, optional: true

    validates :revision, numericality: { only_integer: true, greater_than: 0 }
    validates :action, inclusion: { in: ACTIONS }
    validates :origin, inclusion: { in: ORIGINS }
    validates :settings, presence: true
    validates :previous_digest, :event_digest,
              format: { with: /\A[0-9a-f]{64}\z/ }
    validates :recorded_at, presence: true
    validate :policy_scope_matches

    before_update :block_mutation
    before_destroy :block_mutation

    def self.compute_digest(workspace_id:, studio_ai_policy_id:,
                            project_intake_id:, actor_user_id:, revision:,
                            action:, origin:, recorded_at:, previous_digest:,
                            settings:)
      canonical = [
        "rc037-ai-policy-revision-v1", workspace_id, studio_ai_policy_id,
        project_intake_id, actor_user_id, revision, action, origin,
        recorded_at.utc.iso8601(6), previous_digest, settings.sort.to_h
      ]
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
                            JSON.generate(canonical))
    end

    def self.verify_chain!(policy:)
      raise ArgumentError, "Policy must be persisted" unless policy.is_a?(AiPolicy) && policy.persisted?
      prior = GENESIS
      expected_revision = 1
      events = where(studio_ai_policy_id: policy.id, workspace_id: policy.workspace_id)
        .order(:revision).to_a
      raise SecurityError, "AI policy audit chain is missing" if events.empty?

      events.each do |event|
        expected = compute_digest(
          workspace_id: event.workspace_id,
          studio_ai_policy_id: event.studio_ai_policy_id,
          project_intake_id: event.project_intake_id,
          actor_user_id: event.actor_user_id,
          revision: event.revision, action: event.action, origin: event.origin,
          recorded_at: event.recorded_at, previous_digest: event.previous_digest,
          settings: event.settings
        )
        unless event.revision == expected_revision &&
               event.previous_digest == prior &&
               ActiveSupport::SecurityUtils.secure_compare(event.event_digest, expected)
          raise SecurityError, "AI policy audit chain integrity failure"
        end
        prior = event.event_digest
        expected_revision += 1
      end

      unless events.last.settings == policy.audit_snapshot &&
             events.last.project_intake_id == policy.project_intake_id
        raise SecurityError, "AI policy differs from the latest audited revision"
      end
      true
    end

    private

    def policy_scope_matches
      return unless ai_policy
      if workspace_id != ai_policy.workspace_id ||
         project_intake_id != ai_policy.project_intake_id
        errors.add(:base, "AI policy revision scope mismatch")
      end
    end

    def block_mutation
      errors.add(:base, "AI policy revision is append-only")
      throw :abort
    end
  end
end
