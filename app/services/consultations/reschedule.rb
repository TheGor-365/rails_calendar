module Consultations
  # Server-side update boundary for the existing single-administrator UI.
  # Only a successful time change writes an immutable audit snapshot; a
  # description/title-only edit does not create a fake reschedule.
  class Reschedule
    ACTOR_LABEL = "administrator".freeze
    MAX_REASON_LENGTH = 500

    def self.call(consultation:, attributes:)
      new(consultation: consultation, attributes: attributes).call
    end

    def initialize(consultation:, attributes:)
      @consultation = consultation
      @attributes = attributes.to_h.stringify_keys
      @reason = @attributes.delete("reschedule_reason").to_s.strip
    end

    def call
      # Acquire the row lock before reading the previous values. Consultation
      # save and history INSERT commit together or not at all. We do not move
      # or reject other overlapping records.
      @consultation.with_lock do
        previous_start = @consultation.start_time
        previous_end = @consultation.end_time

        @consultation.assign_attributes(@attributes)
        @consultation.reschedule_reason = @reason

        schedule_changed =
          @consultation.will_save_change_to_start_time? ||
          @consultation.will_save_change_to_end_time?

        # Surface *all* actual model validation errors even when a time-change
        # reason is missing. Otherwise year/time errors are obscured by a
        # single reason error and the edit form gives misleading feedback.
        @consultation.valid?

        if schedule_changed && @reason.blank?
          @consultation.errors.add(:reschedule_reason, "is required when changing the schedule")
        elsif schedule_changed && @reason.length > MAX_REASON_LENGTH
          @consultation.errors.add(:reschedule_reason, "is too long (maximum #{MAX_REASON_LENGTH} characters)")
        end

        next false if @consultation.errors.any?
        next false unless @consultation.save

        if schedule_changed
          ConsultationRescheduleEvent.create!(
            consultation_id: @consultation.id,
            old_start_time: previous_start,
            old_end_time: previous_end,
            new_start_time: @consultation.start_time,
            new_end_time: @consultation.end_time,
            actor_label: ACTOR_LABEL,
            reason: @reason,
            created_at: Time.current
          )
        end

        true
      end
    end
  end
end
