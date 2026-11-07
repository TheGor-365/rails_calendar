# Durable snapshot of an administrator-approved change to consultation time.
# Intentionally independent from Consultation's current physical-delete lifecycle.
# This is an application-level append-only policy; privileged SQL can bypass it.
class ConsultationRescheduleEvent < ApplicationRecord
  validates :consultation_id, :old_start_time, :old_end_time,
            :new_start_time, :new_end_time, :actor_label, :reason,
            :created_at, presence: true
  validates :actor_label, length: { maximum: 80 }
  validates :reason, length: { maximum: 500 }
  validate :schedule_changed

  # An audit event may be inserted but must not be edited or removed through
  # the application model. The backing table is intentionally not cascaded.
  def readonly?
    persisted? || super
  end

  private

  def schedule_changed
    return if old_start_time.blank? || old_end_time.blank? ||
              new_start_time.blank? || new_end_time.blank?

    if old_start_time == new_start_time && old_end_time == new_end_time
      errors.add(:base, "reschedule history requires a changed time")
    end
  end
end
