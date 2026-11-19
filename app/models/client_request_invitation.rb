# A single scoped owner proposal and one-time invitation.
# The owner-authored seed is never treated as an accepted client requirement.
class ClientRequestInvitation < ApplicationRecord
  TTL = 48.hours
  FACT_KEYS = %w[title project_type goal].freeze
  FACT_STATES = %w[suggested confirmed unknown].freeze

  belongs_to :workspace
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

  def service_versions_are_published
    errors.add(:service_version_ids, "must be unique published versions from this workspace") unless valid_published_versions?
  end
end
