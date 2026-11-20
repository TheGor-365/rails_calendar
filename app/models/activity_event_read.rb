# A user-scoped acknowledgement. Reading does not approve a client brief or change scope.
class ActivityEventRead < ApplicationRecord
  belongs_to :activity_event
  belongs_to :owner_user, class_name: "User"

  validates :read_at, presence: true
  validate :owner_matches_event_workspace

  private

  def owner_matches_event_workspace
    return unless owner_user && activity_event
    unless owner_user.role == "owner" &&
           activity_event.workspace.owner_user_id == owner_user.id
      errors.add(:activity_event, "must belong to the owner")
    end
  end
end
