class ProjectSource < ApplicationRecord
  belongs_to :workspace
  belongs_to :client
  belongs_to :project_intake
  belongs_to :recorded_by, class_name: "User"

  FORMATS = %w[markdown text json].freeze
  PARSER_VERSION = "rc036-preview-v1"

  validates :source_sha256, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :byte_size, numericality: { only_integer: true, greater_than: 0,
                                         less_than_or_equal_to: Studio::SourceInspector::MAX_BYTES }
  validates :source_format, inclusion: { in: FORMATS }
  validates :parser_version, inclusion: { in: [PARSER_VERSION] }
  validates :state, inclusion: { in: ["metadata_only"] }
  validate :matching_tenant

  before_update :reject_mutation
  before_destroy :reject_mutation

  # No byte storage is wired. Metadata must never be treated as a
  # scanned, consented, encrypted or downloadable file.
  def downloadable?
    false
  end

  private

  def matching_tenant
    errors.add(:client, "is outside workspace") if client && client.workspace_id != workspace_id
    return unless project_intake

    if project_intake.workspace_id != workspace_id || project_intake.client_id != client_id
      errors.add(:project_intake, "is outside the selected client scope")
    end
  end

  def reject_mutation
    errors.add(:base, "Source registration is immutable")
    throw :abort
  end
end
