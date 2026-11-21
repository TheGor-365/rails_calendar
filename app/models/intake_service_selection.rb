# Explicit, traceable selection of a published offering snapshot.
# Older versions remain valid evidence if the owner later updates the catalog.
class IntakeServiceSelection < ApplicationRecord
  belongs_to :project_intake
  belongs_to :service_offering_version

  validates :service_offering_version_id, uniqueness: { scope: :project_intake_id }
  validate :published_version_and_workspace_match

  private

  def published_version_and_workspace_match
    return unless project_intake && service_offering_version
    offering = service_offering_version.service_offering
    if offering.published_version_id != service_offering_version.id ||
       project_intake.workspace_id != offering.workspace_id
      errors.add(:service_offering_version, "must be published for the selected workspace")
    end
  end
end
