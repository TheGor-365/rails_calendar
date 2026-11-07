class IntakeSpecVersion < ApplicationRecord
  belongs_to :project_intake

  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :project_intake_id }
  validates :source, inclusion: { in: %w[grok template] }
  validate :structured_document_is_valid

  def approved?
    owner_approved_at.present?
  end

  private

  def structured_document_is_valid
    required = %w[summary goals deliverables acceptance_criteria unknowns exclusions milestones]
    unless document.is_a?(Hash) && required.all? { |key| document.key?(key) } &&
           document["summary"].is_a?(String) &&
           (required - ["summary"]).all? { |key| document[key].is_a?(Array) }
      errors.add(:document, "must contain a complete structured proposal")
    end
  end
end
