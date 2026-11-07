# A read-only, bounded search for the consultation index.
# Date filters are UTC calendar days and include events that overlap the range:
# [event_start, event_end) intersects [from_midnight, after_to_midnight).
class ConsultationSearch
  PAGE_SIZE = 20
  MAX_QUERY_LENGTH = 120
  STATUSES = %w[all upcoming ongoing past].freeze

  attr_reader :query, :from_value, :to_value, :status, :page, :total,
              :total_pages, :results, :errors

  def initialize(params, now: Time.current)
    @query = string_param(params[:q]).strip
    @from_value = string_param(params[:from]).strip
    @to_value = string_param(params[:to]).strip
    @status = string_param(params[:status]).presence || "all"
    @page = parse_page(params[:page])
    @now = now
    @errors = []

    validate_filters

    if @errors.any?
      @results = []
      @total = 0
      @total_pages = 1
      @page = 1
      return
    end

    scope = Consultation.all
    scope = scope.where("title ILIKE ?", "%#{Consultation.sanitize_sql_like(@query)}%") if @query.present?

    if @from_date
      scope = scope.where("end_time > ?", utc_midnight(@from_date))
    end
    if @to_date
      scope = scope.where("start_time < ?", utc_midnight(@to_date.next_day))
    end

    scope = case @status
    when "upcoming" then scope.where("start_time > ?", @now)
    when "ongoing" then scope.where("start_time <= ? AND end_time > ?", @now, @now)
    when "past" then scope.where("end_time <= ?", @now)
    else scope
    end

    @total = scope.count
    @total_pages = [(@total + PAGE_SIZE - 1) / PAGE_SIZE, 1].max
    @page = [@page, @total_pages].min
    @results = scope.order(:start_time, :id).limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE).to_a
  end

  def filtered?
    @query.present? || @from_value.present? || @to_value.present? || @status != "all"
  end

  def first_result
    @total.zero? ? 0 : (@page - 1) * PAGE_SIZE + 1
  end

  def last_result
    [@page * PAGE_SIZE, @total].min
  end

  def page_params(page_number)
    { q: @query, from: @from_value, to: @to_value, status: @status, page: page_number }
      .reject { |key, value| value.blank? || (key == :status && value == "all") }
  end

  private

  def string_param(value)
    value.is_a?(String) ? value : ""
  end

  def parse_page(value)
    text = string_param(value)
    text.match?(/\A[1-9]\d{0,5}\z/) ? text.to_i : 1
  end

  def parse_day(value, label)
    return if value.blank?

    unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      @errors << "#{label} must be a valid YYYY-MM-DD date"
      return
    end

    date = Date.iso8601(value)
    unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?(date.year)
      @errors << "#{label} must be between years 2000 and 2100"
      return
    end

    date
  rescue Date::Error
    @errors << "#{label} must be a valid YYYY-MM-DD date"
    nil
  end

  def validate_filters
    @errors << "Search is limited to #{MAX_QUERY_LENGTH} characters" if @query.length > MAX_QUERY_LENGTH
    @errors << "Unknown time filter" unless STATUSES.include?(@status)
    @from_date = parse_day(@from_value, "From")
    @to_date = parse_day(@to_value, "To")
    if @from_date && @to_date && @from_date > @to_date
      @errors << "From date must not be later than To date"
    end
  end

  def utc_midnight(date)
    Time.utc(date.year, date.month, date.day)
  end
end
