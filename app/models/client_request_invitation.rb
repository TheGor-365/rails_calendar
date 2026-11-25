# A single scoped owner proposal and one-time invitation.
# The owner-authored seed is never treated as an accepted client requirement.
class ClientRequestInvitation < ApplicationRecord
  TTL = 48.hours
  FACT_KEYS = %w[title project_type goal].freeze
  FACT_STATES = %w[suggested confirmed unknown].freeze

  belongs_to :workspace
  belongs_to :owner_ai_entry, class_name: "AiSpendEntry", optional: true
  belongs_to :claimed_by_user, class_name: "User", optional: true
  belongs_to :project_intake, optional: true

  validates :token_digest, presence: true, uniqueness: true,
            format: { with: /\A[0-9a-f]{64}\z/ }
  validates :seed_title, presence: true, length: { maximum: 120 }
  validates :seed_project_type, inclusion: { in: ProjectIntake::TYPES }
  validates :seed_goal, presence: true, length: { minimum: 10, maximum: 1200 }
  validates :expires_at, presence: true
  validate :service_versions_are_published, on: :create
  validate :valid_fact_reviews
  validate :valid_brief_choices
  validates :brief_notes, length: { maximum: 350 }
  validates :approved_client_preview, length: { maximum: 1200 }
  validate :owner_ai_entry_is_scoped

  def self.digest_for(raw_token)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "rc-e2-invitation-v1:#{raw_token}")
  end

  def state
    return :revoked if revoked_at.present?
    return :submitted if submitted_at.present?
    return :claimed if claimed_at.present?
    return :expired if expires_at <= Time.current
    :invited
  end

  def fact_state(key)
    client_fact_reviews.fetch(key.to_s, "suggested")
  end

  def published_versions
    ServiceOfferingVersion.joins(:service_offering)
      .where(id: service_version_ids)
      .where(service_offerings: { workspace_id: workspace_id })
      .where("service_offerings.published_version_id = service_offering_versions.id")
      .order(:id).to_a
  end

  def valid_published_versions?
    ids = service_version_ids
    ids.is_a?(Array) && ids.size <= 6 && ids.uniq.size == ids.size &&
      ids.all? { |id| id.is_a?(Integer) && id.positive? } &&
      published_versions.size == ids.size
  end

  # Enqueue within the same transaction as the invitation change.
  # Existing after_commit events remain as immediate, idempotent projections.
  after_create :enqueue_invitation_issued
  after_update :enqueue_invitation_transitions
  after_create_commit :record_invitation_issued
  after_update_commit :record_invitation_transitions

  def enqueue_invitation_issued
    DomainOutboxEvent.enqueue_invitation_transition!(self, kind: "invitation_issued")
  end

  def enqueue_invitation_transitions
    { "claimed_at" => "invitation_claimed", "submitted_at" => "invitation_submitted",
      "revoked_at" => "invitation_revoked" }.each do |attribute, kind|
      next unless saved_change_to_attribute?(attribute) && public_send(attribute).present?
      DomainOutboxEvent.enqueue_invitation_transition!(self, kind: kind)
    end
  end

  def record_invitation_issued
    Activity::Recorder.record!(workspace: workspace, subject: self,
      kind: "invitation_issued", title: seed_title, occurred_at: created_at)
  end

  def record_invitation_transitions
    { "claimed_at" => "invitation_claimed", "submitted_at" => "invitation_submitted",
      "revoked_at" => "invitation_revoked" }.each do |attribute, kind|
      next unless saved_change_to_attribute?(attribute) && public_send(attribute).present?
      Activity::Recorder.record!(workspace: workspace, subject: self,
        kind: kind, title: seed_title, occurred_at: public_send(attribute))
    end
  end


  private

  def valid_fact_reviews
    ok = client_fact_reviews.is_a?(Hash) &&
      client_fact_reviews.all? { |key, value| FACT_KEYS.include?(key) && FACT_STATES.include?(value) }
    errors.add(:client_fact_reviews, "contains an unsupported fact decision") unless ok
  end

  def valid_brief_choices
    errors.add(:brief_selections, "contains unsupported choices") unless InvitationBriefTaxonomy.valid?(brief_selections)
    errors.add(:brief_decisions, "contains unsupported choices") unless InvitationBriefTaxonomy.valid_decisions?(brief_decisions)
  end

  def owner_ai_entry_is_scoped
    return if owner_ai_entry_id.blank?
    entry = owner_ai_entry
    valid = entry&.status == "settled" && entry&.operation == OwnerAi::Composer::VERSION &&
      entry.professional_profile_id == workspace.professional_profile&.id &&
      entry.result.is_a?(Hash) && OwnerAi::PageActionRegistry.allowed?(:invitation, entry.result["purpose"])
    errors.add(:owner_ai_entry, "must be an authorized, settled invitation AI draft") unless valid
  end

  def service_versions_are_published
    errors.add(:service_version_ids, "must be unique published versions from this workspace") unless valid_published_versions?
  end
end
