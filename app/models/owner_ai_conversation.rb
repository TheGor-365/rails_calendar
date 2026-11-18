# Owner-only AI dialogue envelope. No client/public finder or provider invocation.
# Every query must start from the authenticated owner's Workspace association.
class OwnerAiConversation < ApplicationRecord
  belongs_to :workspace
  has_many :owner_ai_messages, dependent: :restrict_with_exception

  STATES = %w[active archived removed].freeze
  SCOPES = %w[owner_general].freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :state, inclusion: { in: STATES }
  validates :scope, inclusion: { in: SCOPES }
  validates :archived_at, presence: true, unless: :active?
  validates :archived_at, absence: true, if: :active?

  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  def active?
    state == "active"
  end

  def removed?
    state == "removed"
  end

  def archived?
    state == "archived"
  end

  def archive!
    with_lock do
      return if archived? || removed?
      update!(state: "archived", archived_at: Time.current)
    end
  end

  def restore!
    with_lock { update!(state: "active", archived_at: nil) unless active? }
  end

  def remove!
    with_lock { update!(state: "removed", archived_at: Time.current) unless removed? }
  end
end
