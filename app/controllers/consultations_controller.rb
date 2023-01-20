class ConsultationsController < ApplicationController
  before_action :set_consultation, only: %i[ show edit update destroy ]

  def index
    @consultations = Consultation.all
  end

  def show; end
  def edit; end

  def new
    @consultation = Consultation.new
  end

  def create
    @consultation = Consultation.new(consultation_params)

    respond_to do |format|
      if @consultation.save
        format.html { redirect_to consultation_url(@consultation) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @consultation.update(consultation_params)
        format.html { redirect_to consultation_url(@consultation) }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @consultation.destroy

    respond_to do |format|
      format.html { redirect_to consultations_url }
    end
  end

  private
  
  def set_consultation
    @consultation = Consultation.find(params[:id])
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
