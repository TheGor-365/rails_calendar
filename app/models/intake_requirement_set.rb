# Private, append-only candidate requirements; NOT an approved specification.
# Requirement IDs remain stable for the same source section across revisions.
class IntakeRequirementSet < ApplicationRecord
  belongs_to :project_intake
  belongs_to :intake_scope_revision

  validates :version, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :project_intake_id }
  validate :requirements_integrity

  def readonly?
    persisted?
  end

  private

  def requirements_integrity
    unless requirements.is_a?(Array) && requirements.length <= 96 &&
           requirements.all? { |row| self.class.valid_row?(row, intake_scope_revision_id) } &&
           requirements.pluck("id").uniq.length == requirements.length
      errors.add(:requirements, "must be traceable candidate requirements")
    end
  end

  def self.valid_row?(row, revision_id)
    row.is_a?(Hash) &&
      row.keys.sort == %w[acceptance_criteria id source statement status] &&
      row["id"].is_a?(String) && row["id"].match?(/\AR-\d{3,6}\z/) &&
      row["source"].is_a?(Hash) &&
      row["source"].keys.sort == %w[revision_id section type] &&
      IntakeScopeSections::KEYS.include?(row["source"]["section"]) &&
      row["source"]["revision_id"] == revision_id &&
      row["source"]["type"] == "intake_scope_revision" &&
      row["statement"].is_a?(String) && row["statement"].length.between?(1, 1600) &&
      %w[suggested unknown excluded].include?(row["status"]) &&
      row["acceptance_criteria"].is_a?(Array) &&
      row["acceptance_criteria"].length <= 8 &&
      row["acceptance_criteria"].all? { |v| v.is_a?(String) && v.length.between?(1, 500) }
  end
end
