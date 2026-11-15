class IntakeMessage < ApplicationRecord
  belongs_to :project_intake

  validates :role, inclusion: { in: %w[client assistant] }
  validates :body, presence: true, length: { maximum: 1200 }
  validates :client_submission_key, format: { with: /\A[0-9a-f]{32}\z/ }, allow_nil: true
  validate :submission_key_belongs_to_client

  private

  def submission_key_belongs_to_client
    errors.add(:client_submission_key, "may only be used for a client turn") if client_submission_key.present? && role != "client"
  end
end
