class ProfessionalProfile < ApplicationRecord
  belongs_to :workspace
  has_many :owner_interview_answers, dependent: :restrict_with_exception
  has_many :professional_context_snapshots, dependent: :restrict_with_exception
  has_many :professional_capabilities, dependent: :restrict_with_exception
  has_many :work_policies, dependent: :restrict_with_exception
  has_many :ai_spend_entries, dependent: :restrict_with_exception

  validates :workspace_id, uniqueness: true
  validates :onboarding_state, inclusion: { in: %w[draft approved] }
  validates :headline, length: { maximum: 160 }, allow_nil: true
  validates :private_summary, length: { maximum: 1500 }, allow_nil: true
  validates :public_summary, length: { maximum: 1000 }, allow_nil: true

  def approved_snapshot
    professional_context_snapshots.order(version: :desc).first
  end

  def completed_sections
    owner_interview_answers.where(section_key: OwnerIntelligence::Catalog::KEYS).count
  end

  def interview_complete?
    completed_sections == OwnerIntelligence::Catalog::KEYS.size
  end

  def current_answer_digest
    OwnerIntelligence::Catalog.answer_digest(self)
  end

  def fresh_ai_suggestion?
    ai_suggestion.present? && ai_input_digest == current_answer_digest
  end
end
