class ConsultationsController < ApplicationController
  before_action :require_calendar_read_access!, only: %i[index show]
  # Public calendar/list/details; all administrative forms and mutations
  # require a valid server-side authorization check.
  before_action :require_admin!, except: %i[index show]
  before_action :set_consultation, only: %i[show edit update destroy]

  def index
    @consultations = Consultation.order(:start_time, :id)
  end

  def show; end
  def edit; end

  def new
    @consultation = Consultation.new
    prefill_schedule_from_day if params[:start_at].present?
  end

  def create
    @consultation = Consultation.new(consultation_params)

    respond_to do |format|
      if @consultation.save
        format.html { redirect_to consultation_url(@consultation), notice: "Consultation was successfully created" }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    attributes = consultation_params
    # An existing timestamp may contain legacy seconds. The HTML editor is
    # minute-only, so posting the same displayed minute must not silently
    # discard the persisted seconds when editing the title/description.
    preserve_unchanged_minutes!(attributes)

    respond_to do |format|
      if @consultation.update(attributes)
        format.html { redirect_to consultation_url(@consultation), notice: "Consultation was successfully updated" }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @consultation.destroy

    respond_to do |format|
      format.html { redirect_to consultations_url, notice: "Consultation was successfully destroyed" }
    end
  end

  private

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  def prefill_schedule_from_day
    start_at = Time.iso8601(params[:start_at].to_s).in_time_zone
    return unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?(start_at.year)
    return unless (Consultation::MIN_SCHEDULE_YEAR..Consultation::MAX_SCHEDULE_YEAR).cover?((start_at + 1.hour).year)

    @consultation.assign_attributes(start_time: start_at, end_time: start_at + 1.hour)
  rescue ArgumentError, TypeError, RangeError
    # An invalid URL parameter must not crash an admin form or write data.
    nil
  end

  def preserve_unchanged_minutes!(attributes)
    %w[start_time end_time].each do |name|
      submitted = attributes[name]
      persisted = @consultation.public_send(name)
      next unless submitted.is_a?(String) && persisted.present?

      same_minute = persisted.in_time_zone.strftime("%Y-%m-%dT%H:%M")
      attributes.delete(name) if submitted == same_minute
    end
  end

  def consultation_params
    params.require(:consultation).permit(
      :title,
      :description,
      :start_time,
      :end_time
    )
  end
end
