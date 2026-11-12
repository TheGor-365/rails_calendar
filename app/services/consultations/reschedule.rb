module Consultations
  # Server-side update boundary for the existing single-administrator UI.
  # Only a successful time change writes an immutable audit snapshot; a
  # description/title-only edit does not create a fake reschedule.
  class Reschedule
    ACTOR_LABEL = "administrator".freeze
    MAX_REASON_LENGTH = 500

    def self.call(consultation:, attributes:, expected_lock_version:)
      new(
        consultation: consultation,
        attributes: attributes,
        expected_lock_version: expected_lock_version
      ).call
    end

    def initialize(consultation:, attributes:, expected_lock_version:)
      @consultation = consultation
      @attributes = attributes.to_h.stringify_keys
      @reason = @attributes.delete("reschedule_reason").to_s.strip
      @expected_lock_version = expected_lock_version.to_s
    end

    def call
      # Reload under row lock before validating the version submitted by
      # the open edit form, so a concurrent tab cannot overwrite newer data.
      # The consultation update and optional audit insertion remain atomic.
      @consultation.with_lock do
        unless current_edit_version?
          @consultation.errors.add(
            :base,
            I18n.t("consultations.validation_stale")
          )
          next :stale
        end

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
          @consultation.errors.add(:reschedule_reason, I18n.t("consultations.validation_reason_required"))
        elsif schedule_changed && @reason.length > MAX_REASON_LENGTH
          @consultation.errors.add(:reschedule_reason, I18n.t("consultations.validation_reason_length", max: MAX_REASON_LENGTH))
        end

        next :invalid if @consultation.errors.any?
        next :invalid unless @consultation.save

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

        :updated
      end
    end

    private

    def current_edit_version?
      # Invalid, absent and noncanonical edit tokens fail closed.
      @expected_lock_version.match?(/\A(?:0|[1-9]\d{0,10})\z/) &&
        @expected_lock_version.to_i == @consultation.lock_version
    end
  end
end
