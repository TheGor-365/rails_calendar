# Private, read-only projection of persisted owner actions into calendar dates.
# Existing authoritative records are NOT copied or mutated here. Durable event
# outbox, notifications and cross-surface subscriptions are a separate phase.
module Calendar
  class OwnerActivity
    def self.between(workspace:, from:, through:)
      items = []
      workspace.client_request_invitations.where(created_at: from...through).each do |record|
        items << {
          kind: :invitation, icon: "send-check", title: record.seed_title,
          created_at: record.created_at, path: Rails.application.routes.url_helpers.owner_invitation_path(record),
          status: record.state.to_s
        }
      end

      project_ids = ProjectIntake.where(workspace_id: workspace.id).select(:id)
      ProjectIntake.where(workspace_id: workspace.id, created_at: from...through).each do |record|
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
        next unless entry.status == "settled"
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
