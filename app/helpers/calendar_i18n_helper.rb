module CalendarI18nHelper
  # Date-only display uses the current UI locale without affecting stored instants,
  # calendar URLs (ISO 8601), or the UTC scheduling contract.
  def rc_local_date(value, format: :rc_full)
    I18n.l(value, format: format)
  end

  def rc_local_datetime(value, format: :rc_date_time)
    I18n.l(value.in_time_zone, format: format)
  end

  # Explicit count inflections: no change to persisted data or ActiveRecord.
  # Russian uses one/few/many, while other UI languages use one/other.
  def rc_count(value, group, noun)
    count = Integer(value)
    form = if I18n.locale == :ru
      mod10 = count % 10
      mod100 = count % 100
      if mod10 == 1 && mod100 != 11
        :one
      elsif (2..4).cover?(mod10) && !(12..14).cover?(mod100)
        :few
      else
        :many
      end
    else
      count == 1 ? :one : :other
    end
    "#{count} #{I18n.t("#{group}.#{noun}_#{form}")}"
  end
end
