# Private, read-only projection of persisted owner actions into calendar dates.
# Existing authoritative records are NOT copied or mutated here. Durable event
# outbox, notifications and cross-surface subscriptions are a separate phase.
module Calendar
  class OwnerActivity
    def self.between(workspace:, from:, through:)
      events = ActivityEvent.where(workspace_id: workspace.id, occurred_at: from...through)
        .order(occurred_at: :desc, id: :desc).limit(250).to_a
      items = events.map { |entry| Activity::Presenter.display(entry) }
      # Existing historical sources predate the event ledger. Show them only
      # if no event for that exact source has been captured.
      captured = events.map { |entry| [entry.subject_type, entry.subject_id] }.to_set
      workspace.client_request_invitations.where(created_at: from...through).each do |record|
        next if captured.include?(["ClientRequestInvitation", record.id])
        items << {
          kind: :invitation, icon: "send-check", title: record.seed_title,
          created_at: record.created_at, path: Rails.application.routes.url_helpers.owner_invitation_path(record),
          status: record.state.to_s
        }
      end

      project_ids = ProjectIntake.where(workspace_id: workspace.id).select(:id)
      ProjectIntake.where(workspace_id: workspace.id, created_at: from...through).each do |record|
        next if captured.include?(["ProjectIntake", record.id])
        items << {
          kind: :request, icon: "clipboard2-check", title: record.title,
          created_at: record.created_at, path: Rails.application.routes.url_helpers.project_intake_path(record),
          status: record.status.to_s
        }
      end

      profile_id = workspace.professional_profile&.id
      profile_entries = profile_id ? AiSpendEntry.where(professional_profile_id: profile_id, project_intake_id: nil) : AiSpendEntry.none
      intake_entries = AiSpendEntry.where(project_intake_id: project_ids, professional_profile_id: nil)
      profile_entries.or(intake_entries).where(created_at: from...through).each do |entry|
        next if captured.include?(["AiSpendEntry", entry.id])
        result = entry.result.is_a?(Hash) ? entry.result : {}
        items << {
          kind: :ai, icon: "stars", title: result["heading"].presence || entry.operation,
          created_at: entry.created_at,
          path: Rails.application.routes.url_helpers.owner_ai_activity_path,
          status: entry.status
        }
      end

      IntakeRequirementSet.joins(:project_intake)
        .where(project_intakes: { workspace_id: workspace.id })
        .where(created_at: from...through)
        .includes(:project_intake).each do |record|
        next if captured.include?(["IntakeRequirementSet", record.id])
        items << {
          kind: :requirements, icon: "list-check",
          title: "#{record.project_intake.title} · v#{record.version}",
          created_at: record.created_at,
          path: Rails.application.routes.url_helpers.owner_requirements_path(record.project_intake_id),
          status: "revision"
        }
      end
      items.sort_by { |item| [item[:created_at], item[:title]] }.reverse
    end
  end
end
