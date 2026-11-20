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
        scope_revision: scope_revision, previous_set: previous
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

  private

  def require_owner!
    head :not_found unless owner_signed_in?
  end

  def require_local_pilot!
    head :not_found unless Rails.env.development? &&
      ENV["RC_LOCAL_CLIENT_REQUESTS_ENABLED"] == "true"
  end

  def load_intake!
    workspace = current_user.owner_workspace
    @intake = workspace&.project_intakes&.find_by(id: params[:id])
    head :not_found unless @intake
  end
end
