class Consultation < ApplicationRecord
  MIN_SCHEDULE_YEAR = 2000
  MAX_SCHEDULE_YEAR = 2100

  validates :title, :start_time, :end_time, presence: true
  validates :title, length: { maximum: 120 }
  validates :description, length: { maximum: 5_000 }, allow_nil: true
  validate :dates_within_supported_range
  validate :end_time_after_start_time

  private

  # The database accepts years that make no sense for a service calendar.
  # Browser input limits are only a convenience; server validation is required.
  def dates_within_supported_range
    %i[start_time end_time].each do |attribute|
      value = public_send(attribute)
      next if value.blank?

      unless (MIN_SCHEDULE_YEAR..MAX_SCHEDULE_YEAR).cover?(value.year)
        errors.add(attribute, "must be between years #{MIN_SCHEDULE_YEAR} and #{MAX_SCHEDULE_YEAR}")
      end
    end
  end

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
