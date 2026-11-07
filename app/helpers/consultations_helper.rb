module ConsultationsHelper
  # Exact HH:MM precision for current records; historical records may still
  # contain seconds, so flag rounded display instead of silently claiming
  # the rounded time is precise. Never mutate the persisted timestamps.
  def rc_consultation_duration(start_time, end_time)
    return "Not available" if start_time.blank? || end_time.blank?

    seconds = end_time.to_f - start_time.to_f
    return "Not available" unless seconds.positive?

    minutes = (seconds / 60.0).round
    return "less than 1 min" if minutes.zero?

    hours, remainder = minutes.divmod(60)
    parts = []
    parts << "#{hours} h" if hours.positive?
    parts << "#{remainder} min" if remainder.positive?
    text = parts.join(" ")

    seconds == (minutes * 60) ? text : "approximately #{text}"
  end
end
