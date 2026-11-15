# Persistent, per-owner read cursor for a client-associated intake.
# A read receipt is NOT client scope approval or a workflow transition.
class OwnerIntakeReadState < ApplicationRecord
  belongs_to :owner_user, class_name: "User", inverse_of: :owner_intake_read_states
  belongs_to :project_intake, inverse_of: :owner_intake_read_states
  belongs_to :last_seen_client_message, class_name: "IntakeMessage"

  # The DB unique index is authoritative. A Rails uniqueness validator would
  # make create_or_find_by! fail before handling the concurrent/duplicate row.
  validates :first_seen_at, :last_seen_at, presence: true

  validate :owner_role_and_client_source
  validate :cursor_matches_client_intake

  private

  def owner_role_and_client_source
    errors.add(:owner_user, "must be an owner account") unless owner_user&.role == "owner"
    errors.add(:project_intake, "must originate from a client") if project_intake&.client_user_id.nil?
  end

  def cursor_matches_client_intake
    return unless last_seen_client_message && project_intake

    unless last_seen_client_message.project_intake_id == project_intake.id &&
           last_seen_client_message.role == "client"
      errors.add(:last_seen_client_message, "must be a client message on this intake")
    end
  end
end
