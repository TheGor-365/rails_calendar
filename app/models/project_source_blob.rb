class ProjectSourceBlob < ApplicationRecord
  belongs_to :workspace
  belongs_to :client
  belongs_to :project_intake
  belongs_to :project_source
  has_one :studio_source_scan_task, class_name: "Studio::SourceScanTask",
          dependent: :restrict_with_exception

  STATES = %w[quarantined clean infected failed revoked].freeze

  validates :scan_state, inclusion: { in: STATES }
  validates :object_key, format: { with: /\Aq\/[0-9a-f]{64}\z/ }
  validates :expires_at, presence: true
  validate :consistent_scope
  validate :clean_has_verified_digest
  before_update :guard_state_transition
  before_destroy :prevent_destroy

  def downloadable?
    scan_state == "clean" && scanned_at.present? && scanner_engine.present? &&
      scan_sha256 == project_source.source_sha256 && expires_at > Time.current
  end

  private

  def consistent_scope
    errors.add(:client, "does not belong to workspace") if client && client.workspace_id != workspace_id
    if project_intake && (project_intake.workspace_id != workspace_id || project_intake.client_id != client_id)
      errors.add(:project_intake, "does not match client")
    end
    if project_source && [project_source.workspace_id, project_source.client_id,
                          project_source.project_intake_id] != [workspace_id, client_id, project_intake_id]
      errors.add(:project_source, "does not match tenant")
    end
  end

  def clean_has_verified_digest
    return unless scan_state == "clean"
    if scanner_engine.blank? || scanned_at.blank? || scan_sha256 != project_source&.source_sha256
      errors.add(:scan_state, "requires attested scan of the exact original bytes")
    end
  end

  def guard_state_transition
    fields = changes_to_save.keys - ["updated_at"]
    scan_fields = %w[scan_state scanner_engine scan_sha256 scanned_at]
    old_state = scan_state_in_database
    allowed_transition = (
      %w[quarantined failed].include?(old_state) &&
      %w[clean infected failed].include?(scan_state)
    ) || (scan_state == "revoked" && old_state != "revoked")
    return if fields.present? && (fields - scan_fields).empty? &&
              fields.include?("scan_state") && allowed_transition

    errors.add(:base, "Blob metadata may change only through scan/revocation state transitions")
    throw :abort
  end

  def prevent_destroy
    errors.add(:base, "Blob audit metadata is retained")
    throw :abort
  end
end
