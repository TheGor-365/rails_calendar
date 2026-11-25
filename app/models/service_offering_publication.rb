class ServiceOfferingPublication < ApplicationRecord
  belongs_to :service_offering
  belongs_to :service_offering_version, optional: true
  belongs_to :owner_user, class_name: "User"

  validates :event, inclusion: { in: %w[publish unpublish] }
  validate :consistent_event

  # Both the immutable audit and the private outbox envelope share this
  # transaction. Only a confirmed, owner-driven publication reaches here.
  after_create :enqueue_publication_event
  after_create_commit :record_publication_event

  before_validation :protect_immutable_event, on: :update
  before_update :protect_immutable_event
  before_destroy :protect_immutable_event

  def protect_immutable_event
    raise ActiveRecord::ReadOnlyError, "Publication audit is immutable"
  end

  private

  def event_kind
    event == "publish" ? "service_published" : "service_unpublished"
  end

  def enqueue_publication_event
    DomainOutboxEvent.enqueue_service_publication!(self)
  end

  def record_publication_event
    title = event == "publish" ? service_offering_version.title :
      "Service #{service_offering.key} unpublished"
    Activity::Recorder.record!(
      workspace: service_offering.workspace, subject: self,
      kind: event_kind, title: title, occurred_at: created_at
    )
  end

  def consistent_event
    if event == "publish"
      if service_offering_version.nil? ||
          service_offering_version.service_offering_id != service_offering_id ||
          !service_offering_version.approved?
        errors.add(:service_offering_version, "must be an approved version of this service")
      end
    elsif service_offering_version.present?
      errors.add(:service_offering_version, "must be empty for unpublish")
    end
    errors.add(:owner_user, "must own the service workspace") unless
      service_offering&.workspace&.owner_user_id == owner_user_id
  end
end
