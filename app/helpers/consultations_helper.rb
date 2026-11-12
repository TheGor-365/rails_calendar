module ConsultationsHelper
  # Exact HH:MM precision for current records; historical records may still
  # contain seconds, so flag rounded display instead of silently claiming
  # the rounded time is precise. Never mutate the persisted timestamps.
  def rc_consultation_duration(start_time, end_time)
    return I18n.t("consultations.unavailable") if start_time.blank? || end_time.blank?

    seconds = end_time.to_f - start_time.to_f
    return I18n.t("consultations.unavailable") unless seconds.positive?

    minutes = (seconds / 60.0).round
    return I18n.t("consultations.less_than_min") if minutes.zero?

    hours, remainder = minutes.divmod(60)
    parts = []
    parts << "#{hours} #{I18n.t("consultations.duration_hour")}" if hours.positive?
    parts << "#{remainder} #{I18n.t("consultations.duration_minute")}" if remainder.positive?
    text = parts.join(" ")

    seconds == (minutes * 60) ? text : I18n.t("consultations.duration_approx", duration: text)
  end
end
