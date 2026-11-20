# Private artifact catalogue, backed by existing persisted source records.
# No duplicated documents, no speculative AI enrichment, no public files.
class OwnerArtifactsController < ApplicationController
  before_action :require_owner!

  def index
    @kind = %w[all invitation ai requirements].include?(params[:kind]) ? params[:kind] : "all"
    @query = params[:q].to_s.strip.slice(0, 120)
    @artifacts = collection
    @artifacts = @artifacts.select { |item| item[:kind] == @kind } unless @kind == "all"
    if @query.present?
      term = @query.downcase
      @artifacts = @artifacts.select do |item|
        [item[:title], item[:summary], item[:kind], item[:source], item[:preview]].any? { |part| part.to_s.downcase.include?(term) }
      end
    end
    @artifacts = @artifacts.sort_by { |item| [item[:created_at], item[:id]] }.reverse.first(100)
    @kind_counts = @artifacts.group_by { |item| item[:kind] }.transform_values(&:size)
    @latest_at = @artifacts.first&.dig(:created_at)
    response.headers["Cache-Control"] = "private, no-store"
  end

  def export
    kind = params[:kind].to_s
    id = params[:id].to_s
    return head :not_found unless id.match?(/\A[1-9]\d*\z/)

    payload = case kind
    when "invitation"
      invitation = workspace.client_request_invitations.find_by(id: id)
      return head :not_found unless invitation
      { type: "invitation", id: invitation.id, created_at: invitation.created_at.iso8601,
        title: invitation.seed_title, status: invitation.state.to_s, author: current_user.email,
        source: "owner invitation", content: {
          project_type: invitation.seed_project_type, goal: invitation.seed_goal,
          approved_client_preview: invitation.approved_client_preview,
          brief_selections: invitation.brief_selections, brief_decisions: invitation.brief_decisions,
          brief_notes: invitation.brief_notes, linked_intake_id: invitation.project_intake_id,
          ai_entry_id: invitation.owner_ai_entry_id } }
    when "ai"
      entry = owner_ai_entries.find_by(id: id)
      return head :not_found unless entry
      { type: "ai", id: entry.id, created_at: entry.created_at.iso8601,
        title: entry.result.is_a?(Hash) ? entry.result["heading"].presence || entry.operation : entry.operation,
        status: entry.status, author: current_user.email, source: entry.model,
        operation: entry.operation, charged_usd: entry.charged_ticks && format("%.8f", entry.charged_ticks.to_f / AiSpendLedger::USD_TICKS),
        content: entry.result }
    when "requirements"
      set = IntakeRequirementSet.joins(:project_intake)
        .where(project_intakes: { workspace_id: workspace.id }).find_by(id: id)
      return head :not_found unless set
      { type: "requirements", id: set.id, created_at: set.created_at.iso8601,
        title: set.project_intake.title, status: "draft_revision", author: current_user.email,
        source: "client scope revision #{set.intake_scope_revision_id}",
        version: set.version, project_intake_id: set.project_intake_id, content: set.requirements }
    else
      return head :not_found
    end

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data JSON.pretty_generate(payload), type: "text/plain; charset=utf-8",
      disposition: "attachment", filename: "rails-calendar-#{kind}-#{id}.txt"
  end

  private

  def require_owner!
    return if owner_signed_in? && current_user.owner_workspace
    head :not_found
  end

  def workspace
    current_user.owner_workspace
  end

  def owner_ai_entries
    profile_id = workspace.professional_profile&.id
    own_intakes = ProjectIntake.where(workspace_id: workspace.id).select(:id)
    owner_profile_entries = profile_id ? AiSpendEntry.where(professional_profile_id: profile_id, project_intake_id: nil) : AiSpendEntry.none
    owner_profile_entries.or(AiSpendEntry.where(project_intake_id: own_intakes, professional_profile_id: nil))
  end

  def collection
    records = []
    workspace.client_request_invitations.includes(:project_intake).order(id: :desc).limit(100).each do |item|
      records << { kind: "invitation", id: item.id, title: item.seed_title,
        summary: item.seed_goal, source: "owner invitation", status: item.state.to_s,
        created_at: item.created_at, path: owner_invitation_path(item), preview: item.seed_goal }
    end
    owner_ai_entries.order(id: :desc).limit(100).each do |entry|
        result = entry.result.is_a?(Hash) ? entry.result : {}
        records << { kind: "ai", id: entry.id, title: result["heading"].presence || entry.operation,
          summary: result["draft"].to_s.truncate(260), source: entry.model, status: entry.status,
          created_at: entry.created_at,
          path: entry.operation == OwnerAi::Composer::VERSION && entry.status == "settled" ? owner_ai_assistant_path(entry_id: entry.id) : owner_ai_activity_path,
          preview: JSON.pretty_generate(result) }
    end
    IntakeRequirementSet.joins(:project_intake)
      .where(project_intakes: { workspace_id: workspace.id })
      .includes(:project_intake).order(id: :desc).limit(100).each do |set|
      records << { kind: "requirements", id: set.id,
        title: "#{set.project_intake.title} · v#{set.version}",
        summary: "#{set.requirements.size} requirements", source: "intake #{set.project_intake_id}",
        status: "revision", created_at: set.created_at,
        path: owner_requirements_path(set.project_intake_id),
        preview: JSON.pretty_generate(set.requirements) }
    end
    records
  end
end
