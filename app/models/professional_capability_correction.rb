class ProfessionalCapabilityCorrection < ApplicationRecord
  belongs_to :professional_profile

  MODES = %w[direct ai_assisted evaluate_first excluded].freeze
  EXPERIENCE = %w[practiced learning new_to_me].freeze
  WILLINGNESS = %w[actively_offer consider only_if_simple not_interested].freeze

  validates :domain, presence: true, length: { maximum: 80 },
                     uniqueness: { scope: :professional_profile_id }
  validates :base_snapshot_version, numericality: { only_integer: true, greater_than: 0 }
  validates :delivery_mode, inclusion: { in: MODES }
  validates :experience_claim, inclusion: { in: EXPERIENCE }
  validates :willingness, inclusion: { in: WILLINGNESS }
  validates :conditions, length: { maximum: 600 }, allow_nil: true
  validate :coherent_acceptance

  def snapshot_values
    {
      "domain" => domain, "delivery_mode" => delivery_mode,
      "experience_claim" => experience_claim,
      "willingness" => willingness, "conditions" => conditions.to_s
    }
  end

  private

  def coherent_acceptance
    case delivery_mode
    when "direct"
      errors.add(:experience_claim, "must be practiced for direct work") unless experience_claim == "practiced"
      errors.add(:willingness, "must allow direct work") unless %w[actively_offer consider].include?(willingness)
    when "ai_assisted", "evaluate_first"
      errors.add(:willingness, "requires human review") unless %w[consider only_if_simple].include?(willingness)
    when "excluded"
      errors.add(:willingness, "must be not_interested") unless willingness == "not_interested"
    end
  end
end
