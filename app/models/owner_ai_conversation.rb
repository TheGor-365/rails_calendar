# Owner-only AI dialogue envelope. No client/public finder or provider invocation.
# Every query must start from the authenticated owner's Workspace association.
class OwnerAiConversation < ApplicationRecord
  belongs_to :workspace
  has_many :owner_ai_messages, dependent: :restrict_with_exception

  STATES = %w[active archived].freeze
  SCOPES = %w[owner_general].freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :state, inclusion: { in: STATES }
  validates :scope, inclusion: { in: SCOPES }
  validates :archived_at, presence: true, if: :archived?
  validates :archived_at, absence: true, unless: :archived?

  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  def archived?
    state == "archived"
  end

  def archive!
    with_lock do
      return if archived?
      update!(state: "archived", archived_at: Time.current)
    end
  end
end
