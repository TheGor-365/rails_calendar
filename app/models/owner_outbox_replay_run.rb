# Private, metadata-only ledger for future owner-supervised outbox delivery.
# No raw request token, prompts, client content or provider responses are stored.
# Creating a record does not invoke DomainOutbox::Replayer.
class OwnerOutboxReplayRun < ApplicationRecord
  belongs_to :workspace
  belongs_to :owner_user, class_name: "User"

  STATES = %w[running succeeded failed].freeze
  COUNTERS = %i[attempted_count delivered_count failed_count].freeze

  validates :state, inclusion: { in: STATES }
  validates :request_digest, presence: true,
    format: { with: /\A[0-9a-f]{64}\z/ },
    uniqueness: { scope: :workspace_id }
  validates :requested_limit, inclusion: { in: DomainOutbox::OperatorAccess::REPLAY_LIMITS }
  validates :started_at, presence: true
  validates :error_code, length: { maximum: 80 },
    format: { with: /\A[A-Za-z0-9_:]+\z/ }, allow_nil: true
  validates(*COUNTERS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })
  validate :owner_workspace_matches
  validate :strict_limit_input, if: -> { new_record? || will_save_change_to_requested_limit? }
  validate :run_timing_and_counts

  private

  def owner_workspace_matches
    return if owner_user.is_a?(User) && owner_user.persisted? &&
      owner_user.role == "owner" && workspace.is_a?(Workspace) &&
      workspace.persisted? && workspace.owner_user_id == owner_user.id

    errors.add(:owner_user, "must own the replay workspace")
  end

  # PostgreSQL integer casting accepts "10" -> 10. A privileged replay
  # command must still refuse a string input, not silently normalize it.
  def strict_limit_input
    return if requested_limit_before_type_cast.is_a?(Integer)

    errors.add(:requested_limit, "must be an explicit integer")
  end

  def run_timing_and_counts
    if state == "running" ? finished_at.present? : finished_at.nil?
      errors.add(:finished_at, "does not match run state")
    end
    return unless COUNTERS.all? { |name| public_send(name).is_a?(Integer) } &&
      requested_limit.is_a?(Integer)

    if attempted_count > requested_limit ||
        delivered_count + failed_count > attempted_count
      errors.add(:base, "run counts exceed the bounded attempt limit")
    end
  end
end
