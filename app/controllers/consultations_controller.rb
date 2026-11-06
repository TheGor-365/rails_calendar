class ConsultationsController < ApplicationController
  # Public calendar/list/details; all administrative forms and mutations
  # require a valid server-side authorization check.
  before_action :require_admin!, except: %i[index show]
  before_action :set_consultation, only: %i[show edit update destroy]

  def index
    @consultations = Consultation.all
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
    respond_to do |format|
      if @consultation.update(consultation_params)
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

  def consultation_params
    params.require(:consultation).permit(
      :title,
      :description,
      :start_time,
      :end_time
    )
  end
end
