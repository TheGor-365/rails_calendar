# Durable, append-only accounting for a paid provider attempt. Never store API keys or raw prompts.
# 'uncertain' holds its reservation indefinitely when billing is ambiguous; no automatic retry.
class AiSpendEntry < ApplicationRecord
  belongs_to :project_intake
  validates :operation, presence: true, length: { maximum: 40 }
  validates :model, presence: true, length: { maximum: 64 }
  validates :request_digest, presence: true, length: { is: 64 }, uniqueness: true
  validates :status, inclusion: { in: %w[reserved settled uncertain cancelled] }
  validates :reserved_ticks, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :charged_ticks, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
