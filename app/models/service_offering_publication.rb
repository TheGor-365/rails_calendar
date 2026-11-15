class ServiceOfferingPublication < ApplicationRecord
  belongs_to :service_offering
  belongs_to :service_offering_version, optional: true
  belongs_to :owner_user, class_name: "User"

  validates :event, inclusion: { in: %w[publish unpublish] }
  validate :consistent_event

  before_update { raise ActiveRecord::ReadOnlyError, "Publication audit is immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyError, "Publication audit is immutable" }

  private

  def consistent_event
    if event == "publish"
      if service_offering_version.nil? ||
          service_offering_version.service_offering_id != service_offering_id
        errors.add(:service_offering_version, "must be an approved version of this service")
      end
    elsif service_offering_version.present?
      errors.add(:service_offering_version, "must be empty for unpublish")
    end
    errors.add(:owner_user, "must own the service workspace") unless
      service_offering&.workspace&.owner_user_id == owner_user_id
  end
end
