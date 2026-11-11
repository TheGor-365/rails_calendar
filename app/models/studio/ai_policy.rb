module Studio
  # Preferences only; neither consent nor a model choice can enable egress.
  class AiPolicy < ApplicationRecord
    self.table_name = "studio_ai_policies"
    MODES = %w[off offline reviewed_provider].freeze
    PURPOSES = %w[clarify source_outline document_proposal].freeze

    AUDITED_FIELDS = %w[
      workspace_id project_intake_id mode purposes token_cap_per_call
      token_cap_per_day usd_cap_per_call usd_cap_per_month external_consent
    ].freeze

    attr_accessor :audit_actor
    has_many :revisions, class_name: "Studio::AiPolicyRevision",
             foreign_key: :studio_ai_policy_id, dependent: :restrict_with_exception

    after_save :append_audit_revision!, if: :audited_fields_saved?
    validate :active_audit_actor, if: -> { audit_actor.present? }

    belongs_to :workspace
    belongs_to :project_intake, optional: true

    validates :mode, inclusion: { in: MODES }
    validates :token_cap_per_call, :token_cap_per_day,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :usd_cap_per_call, :usd_cap_per_month,
              numericality: { greater_than_or_equal_to: 0 }
    validate :allowed_purposes_only
    validate :scoped_project

    # Fixed non-PII policy snapshot: never persist raw prompts, files or keys.
    def audit_snapshot
      {
        "mode" => mode,
        "purposes" => purposes.sort,
        "token_cap_per_call" => token_cap_per_call,
        "token_cap_per_day" => token_cap_per_day,
        "usd_cap_per_call" => usd_cap_per_call.to_s("F"),
        "usd_cap_per_month" => usd_cap_per_month.to_s("F"),
        "external_consent" => external_consent
      }
    end

    private

    def audited_fields_saved?
      (saved_changes.keys & AUDITED_FIELDS).any?
    end

    def active_audit_actor
      return if workspace&.owner_access?(audit_actor)
      errors.add(:base, "Audit actor must be active workspace owner")
    end

    def append_audit_revision!
      previous = revisions.order(revision: :desc).first
      revision = previous ? previous.revision + 1 : 1
      previous_digest = previous&.event_digest || AiPolicyRevision::GENESIS
      action = previous ? "updated" : "created"
      origin = audit_actor ? "owner_ui" : "internal_unattributed"
      changed_by = audit_actor&.id
      timestamp = Time.current.utc
      snapshot = audit_snapshot
      digest = AiPolicyRevision.compute_digest(
        workspace_id: workspace_id, studio_ai_policy_id: id,
        project_intake_id: project_intake_id, actor_user_id: changed_by,
        revision: revision, action: action, origin: origin,
        recorded_at: timestamp, previous_digest: previous_digest,
        settings: snapshot
      )
      revisions.create!(
        workspace_id: workspace_id, project_intake_id: project_intake_id,
        actor_user_id: changed_by, revision: revision, action: action, origin: origin,
        settings: snapshot, previous_digest: previous_digest,
        event_digest: digest, recorded_at: timestamp
      )
    end

    def allowed_purposes_only
      unless purposes.is_a?(Array) && purposes.uniq == purposes &&
             purposes.all? { |value| PURPOSES.include?(value) }
        errors.add(:purposes, "must be a unique set of registered purposes")
      end
    end

    def scoped_project
      return unless project_intake
      unless project_intake.persisted? && project_intake.workspace_id == workspace_id
        errors.add(:project_intake, "must belong to the same workspace")
      end
    end
  end
end
