module DomainOutbox
  # Explicit, bounded replay. Never contacts a provider, sends client emails,
  # changes canonical records, or executes arbitrary source_type constants.
  # A scheduling/operational interface requires a separate review.
  class Replayer
    class SourceUnavailable < StandardError; end

    def self.run!(workspace:, limit: 25, now: Time.current)
      raise ArgumentError, "persisted workspace required" unless workspace.is_a?(Workspace) && workspace.persisted?
      raise ArgumentError, "limit must be 1..100" unless limit.is_a?(Integer) && limit.between?(1, 100)

      summary = { attempted: 0, delivered: 0, failed: 0 }
      ids = DomainOutboxEvent.where(workspace_id: workspace.id).due(now).limit(limit).pluck(:id)

      ids.each do |id|
        event = DomainOutboxEvent.where(workspace_id: workspace.id).find_by(id: id)
        next unless event

        begin
          event.with_lock do
            next unless event.state.in?(%w[pending failed]) &&
              event.attempts < DomainOutboxEvent::MAX_ATTEMPTS &&
              (event.next_attempt_at.nil? || event.next_attempt_at <= now)

            summary[:attempted] += 1
            deliver!(event, workspace: workspace)
            event.update!(
              state: "delivered", attempts: event.attempts + 1,
              next_attempt_at: nil, last_error_code: nil, delivered_at: now
            )
            summary[:delivered] += 1
          end
        rescue StandardError => error
          # Failure metadata intentionally contains class names only, never
          # source text or provider responses. Retrying does not spend tokens.
          event.with_lock do
            unless event.state == "delivered"
              attempts = event.attempts + 1
              event.update!(
                state: "failed", attempts: attempts,
                last_error_code: error.class.name.truncate(80),
                next_attempt_at: now + [2**attempts, 3600].min.seconds
              )
              summary[:failed] += 1
            end
          end
        end
      end

      summary
    end

    def self.deliver!(event, workspace:)
      case [event.source_type, event.kind]
      when ["IntakeRequirementSet", "requirements_saved"]
        source = IntakeRequirementSet.joins(:project_intake)
          .where(project_intakes: { workspace_id: workspace.id })
          .find_by(id: event.source_id, version: event.source_version)
        raise SourceUnavailable, "source not in workspace" unless source

        Activity::Recorder.record!(
          workspace: workspace, subject: source, kind: "requirements_saved",
          title: "#{source.project_intake.title} · v#{source.version}",
          metadata: { "version" => source.version }, occurred_at: event.occurred_at
        )
      when ["ClientRequestInvitation", "invitation_issued"],
           ["ClientRequestInvitation", "invitation_claimed"],
           ["ClientRequestInvitation", "invitation_submitted"],
           ["ClientRequestInvitation", "invitation_revoked"]
        source = ClientRequestInvitation.where(workspace_id: workspace.id)
          .find_by(id: event.source_id)
        version_field = DomainOutboxEvent::INVITATION_EVENT_FIELDS[event.kind]
        raise SourceUnavailable, "source not in workspace" unless source && version_field &&
          version_field.first == event.source_version &&
          source.public_send(version_field.last).present? &&
          source.public_send(version_field.last).to_i == event.occurred_at.to_i

        Activity::Recorder.record!(
          workspace: workspace, subject: source, kind: event.kind,
          title: source.seed_title, occurred_at: event.occurred_at
        )
      when ["OwnerAiMessage", "ai_reply_saved"]
        source = OwnerAiMessage.joins(:owner_ai_conversation)
          .where(owner_ai_conversations: { workspace_id: workspace.id })
          .find_by(id: event.source_id, sequence: event.source_version,
                   role: "assistant", state: "settled")
        raise SourceUnavailable, "source not in workspace" unless source &&
          source.ai_spend_entry&.status == "settled" &&
          source.ai_spend_entry.professional_profile&.workspace_id == workspace.id

        Activity::Recorder.record!(
          workspace: workspace, subject: source, kind: "ai_reply_saved",
          title: "AI reply saved", occurred_at: event.occurred_at
        )
      else
        raise SourceUnavailable, "unsupported source"
      end

      # Recorder deliberately returns nil for invalid/foreign subjects; verify
      # that the expected immutable event actually exists before acking.
      key = "#{event.source_type}:#{event.source_id}:#{event.kind}"
      raise SourceUnavailable, "event not projected" unless ActivityEvent.exists?(
        workspace_id: workspace.id, event_key: key
      )
    end
    private_class_method :deliver!
  end
end
