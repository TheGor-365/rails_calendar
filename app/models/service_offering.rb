class ServiceOffering < ApplicationRecord
  belongs_to :workspace
  has_many :versions, class_name: "ServiceOfferingVersion", dependent: :restrict_with_exception
  has_many :publications, class_name: "ServiceOfferingPublication", dependent: :restrict_with_exception
  belongs_to :approved_version, class_name: "ServiceOfferingVersion", optional: true
  belongs_to :published_version, class_name: "ServiceOfferingVersion", optional: true

  validates :key, presence: true, length: { maximum: 32 },
                  format: { with: /\A[a-z0-9-]+\z/ },
                  uniqueness: { scope: :workspace_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :pointers_belong_to_offering

  def draft_version
    versions.where(approved_at: nil).order(version: :desc).first
  end

  def latest_version
    versions.order(version: :desc).first
  end

  private

  def pointers_belong_to_offering
    %i[approved_version published_version].each do |association|
      record = public_send(association)
      errors.add(association, "must belong to the same service") if record && record.service_offering_id != id
    end
  end
end
