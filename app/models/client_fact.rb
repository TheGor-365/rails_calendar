class ClientFact < ApplicationRecord
  belongs_to :workspace
  belongs_to :client
  belongs_to :recorded_by, class_name: "User"

  STATUSES = %w[reported verified suggested disputed unknown excluded].freeze
  SENSITIVITIES = %w[public internal confidential restricted].freeze
  PURPOSES = %w[discovery delivery support].freeze
  SOURCES = %w[quiz message owner_note client_statement document].freeze

  validates :field_key, presence: true, length: { maximum: 80 },
                        format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :revision, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: [:client_id, :field_key] }
  validates :payload, presence: true
  validate :bounded_payload
  validates :status, inclusion: { in: STATUSES }
  validates :sensitivity, inclusion: { in: SENSITIVITIES }
  validates :purpose, inclusion: { in: PURPOSES }
  validates :source_kind, inclusion: { in: SOURCES }
  validates :source_ref, presence: true, length: { maximum: 160 }
  validate :matching_tenant

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def bounded_payload
    unless payload.is_a?(Hash) && payload.to_json.bytesize <= 2048
      errors.add(:payload, "must be a bounded JSON object")
    end
  end

  def matching_tenant
    errors.add(:workspace_id, "does not match client") if client && workspace_id != client.workspace_id
  end

  def reject_mutation
    errors.add(:base, "Fact revisions are append-only")
    throw :abort
  end
end
