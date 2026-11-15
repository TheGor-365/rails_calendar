require "digest"
require "json"

class ServiceOfferingVersion < ApplicationRecord
  belongs_to :service_offering, inverse_of: :versions
  belongs_to :professional_context_snapshot
  belongs_to :professional_capability

  validates :version, numericality: { only_integer: true, greater_than: 0 },
                      uniqueness: { scope: :service_offering_id }
  validates :title, presence: true, length: { minimum: 5, maximum: 120 }
  validates :summary, presence: true, length: { minimum: 25, maximum: 1000 }
  validates :included_scope, presence: true, length: { minimum: 15, maximum: 1600 }
  validates :excluded_scope, presence: true, length: { minimum: 10, maximum: 1600 }
  validates :requirements_prompt, length: { maximum: 600 }
  validates :project_category, inclusion: { in: ProjectIntake::TYPES }
  validates :delivery_mode, inclusion: { in: %w[direct conditional evaluate_first] }
  validates :source_capability_domain, presence: true, length: { maximum: 80 }
  validates :digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :source_matches_approved_owner_context

  before_validation :compute_digest
  before_update :protect_approved_record
  before_destroy :protect_approved_record

  def approved?
    approved_at.present?
  end

  def canonical_data
    {
      "version" => version,
      "professional_context_snapshot_id" => professional_context_snapshot_id,
      "professional_capability_id" => professional_capability_id,
      "source_capability_domain" => source_capability_domain,
      "delivery_mode" => delivery_mode,
      "project_category" => project_category,
      "title" => title,
      "summary" => summary,
      "included_scope" => included_scope,
      "excluded_scope" => excluded_scope,
      "requirements_prompt" => requirements_prompt.to_s
    }
  end

  private

  def compute_digest
    self.digest = Digest::SHA256.hexdigest(JSON.generate(canonical_data))
  end

  def protect_approved_record
    # Approval is the one permitted transition; all subsequent edits,
    # destroys and changes of a previously approved version are forbidden.
    if approved_at_in_database.present?
      raise ActiveRecord::ReadOnlyError, "Approved service offering versions are immutable"
    end
  end

  def source_matches_approved_owner_context
    return unless service_offering && professional_context_snapshot && professional_capability
    profile = service_offering.workspace&.professional_profile
    snapshot = professional_context_snapshot
    capability = professional_capability
    valid = profile &&
      snapshot.professional_profile_id == profile.id &&
      capability.professional_profile_id == profile.id &&
      capability.snapshot_version == snapshot.version &&
      capability.domain == source_capability_domain &&
      capability.delivery_mode != "excluded" &&
      capability.willingness != "not_interested"
    errors.add(:base, "Source capability is not approved for this workspace snapshot") unless valid

    expected_mode = OwnerServices::Catalogue.delivery_mode_for(capability)
    errors.add(:delivery_mode, "does not match approved capability") unless expected_mode == delivery_mode
  end
end
