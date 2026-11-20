# Owner-only local pilot: immutable, source-traced candidates from saved client answers.
# This is a deterministic draft stage, not AI approval and not a contract.
class OwnerRequirementsController < ApplicationController
  before_action :require_owner!
  before_action :require_local_pilot!
  before_action :load_intake!

  def show
    @scope_revision = @intake.latest_scope_revision
    @set = @intake.latest_requirement_set
    response.headers["Cache-Control"] = "private, no-store"
  end

  def create
    result = @intake.with_lock do
      scope_revision = @intake.latest_scope_revision
      next :no_answers unless scope_revision

      previous = @intake.latest_requirement_set
      next :unchanged if previous&.intake_scope_revision_id == scope_revision.id

      rows = Intake::RequirementCandidates.new(
        scope_revision: scope_revision, previous_sets: @intake.intake_requirement_sets.order(:version).to_a
      ).build
      next :no_answers if rows.empty?

      @intake.intake_requirement_sets.create!(
        version: (previous&.version || 0) + 1,
        intake_scope_revision: scope_revision,
        requirements: rows
      )
      :saved
    end

    case result
    when :no_answers
      redirect_to owner_requirements_path(@intake), alert: I18n.t("e23_requirements.no_answers"), status: :see_other
    when :unchanged
      redirect_to owner_requirements_path(@intake), notice: I18n.t("e23_requirements.unchanged"), status: :see_other
    else
      redirect_to owner_requirements_path(@intake), notice: I18n.t("e23_requirements.saved"), status: :see_other
    end
  end

  # Only review already extracted source-traced rows. IDs and sources
  # are inherited from the stored revision, never from browser parameters.
  def update
    result = @intake.with_lock do
      current = @intake.latest_requirement_set
      next :missing unless current
      next :stale unless params[:base_version].to_s == current.version.to_s

      incoming = params[:edits]
      next :invalid unless incoming.is_a?(ActionController::Parameters)
      submitted = incoming.to_unsafe_h
      next :invalid unless submitted.keys.sort == (0...current.requirements.size).map(&:to_s).sort

      rows = current.requirements.each_with_index.map do |row, i|
        entry = submitted.fetch(i.to_s)
        next nil unless entry.is_a?(Hash) && entry.keys.sort == %w[acceptance_criteria statement status]
        statement = entry["statement"].to_s.strip
        status = entry["status"].to_s
        criteria = entry["acceptance_criteria"].to_s.lines.map(&:strip).reject(&:empty?)
        next nil if statement.blank? || statement.length > 1600 ||
          !%w[suggested unknown excluded].include?(status) ||
          criteria.length > 8 || criteria.any? { |text| text.length > 500 }
        row.merge("statement" => statement, "status" => status, "acceptance_criteria" => criteria)
      end
      next :invalid if rows.any?(&:nil?)
      next :unchanged if rows == current.requirements

      @intake.intake_requirement_sets.create!(
        version: current.version + 1,
        intake_scope_revision: current.intake_scope_revision,
        requirements: rows
      )
      :saved
    end

    case result
    when :saved
      redirect_to owner_requirements_path(@intake), notice: t("e23_requirements.review_saved"), status: :see_other
    when :unchanged
      redirect_to owner_requirements_path(@intake), notice: t("e23_requirements.unchanged"), status: :see_other
    when :stale
      redirect_to owner_requirements_path(@intake), alert: t("e23_requirements.stale"), status: :see_other
    when :missing
      redirect_to owner_requirements_path(@intake), alert: t("e23_requirements.no_answers"), status: :see_other
    else
      redirect_to owner_requirements_path(@intake), alert: t("e23_requirements.invalid_review"), status: :see_other
    end
  end

  private

  def require_owner!
    head :not_found unless owner_signed_in?
  end

  def require_local_pilot!
    head :not_found unless (Rails.env.development? || Rails.env.test?) &&
      ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] == "true"
  end

  def load_intake!
    workspace = current_user.owner_workspace
    @intake = ProjectIntake.where(workspace_id: workspace&.id).find_by(id: params[:id])
    head :not_found unless @intake
  end
end
