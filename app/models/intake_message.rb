class IntakeMessage < ApplicationRecord
  belongs_to :project_intake

  validates :role, inclusion: { in: %w[client assistant] }
  validates :body, presence: true, length: { maximum: 1200 }
end
