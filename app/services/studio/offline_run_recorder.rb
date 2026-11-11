require "digest"
require "json"

module Studio
  class OfflineRunRecorder
    class Denied < StandardError; end

    def initialize(actor:, workspace:, intake:)
      @actor, @workspace, @intake = actor, workspace, intake
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             workspace.project_intakes.where(id: intake.id, client_id: intake.client_id).exists?
        raise Denied, "Invalid scoped intake"
      end
    end

    def record!(purpose:, source_ids: [])
      @access.assert_owner!
      output = OfflineAiDispatcher.new(
        actor: @actor, workspace: @workspace, intake: @intake
      ).call(purpose: purpose, source_ids: source_ids)
      sources = OfflineSourceSelector.new(
        actor: @actor, workspace: @workspace, intake: @intake
      ).select!(source_ids: source_ids)
      raise Denied, "Metadata count mismatch" unless output.fetch(:source_metadata_count) == sources.length
      OfflineOutputContract.validate!(output)

      @intake.with_lock do
        @access.assert_owner!
        AiBudgetAdmission.new(actor: @actor, workspace: @workspace, intake: @intake).admit!(
          purpose: purpose, data_class: "synthetic", provider: "offline_template",
          estimated_tokens: 0, estimated_usd: 0
        )
        current = @workspace.studio_offline_runs.where(
          client_id: @intake.client_id, project_intake_id: @intake.id
        ).maximum(:version).to_i
        raise Denied, "Synthetic run limit reached" if current >= OfflineRun::MAX_PER_INTAKE

        fingerprint = Digest::SHA256.hexdigest(JSON.generate([
          "rc037-offline-metadata-v1", @workspace.id, @intake.client_id,
          @intake.id, purpose, sources
        ]))
        recorded_at = Time.current.utc
        payload = output.stringify_keys
        version = current + 1
        digest = OfflineRun.compute_digest(
          workspace_id: @workspace.id, client_id: @intake.client_id,
          project_intake_id: @intake.id, actor_user_id: @actor.id,
          version: version, purpose: purpose, input_fingerprint: fingerprint,
          output_payload: payload, recorded_at: recorded_at
        )
        @workspace.studio_offline_runs.create!(
          client_id: @intake.client_id, project_intake_id: @intake.id,
          actor_user_id: @actor.id, version: version, purpose: purpose,
          input_fingerprint: fingerprint, output_payload: payload,
          event_digest: digest, recorded_at: recorded_at
        )
      end
    end
  end

  class OfflineRunReviewer
    class Denied < StandardError; end

    def initialize(actor:, workspace:, intake:)
      @actor, @workspace, @intake = actor, workspace, intake
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             workspace.project_intakes.where(id: intake.id, client_id: intake.client_id).exists?
        raise Denied, "Invalid scoped intake"
      end
    end

    def review!(run_id:, decision:)
      @access.assert_owner!
      raise Denied, "Unsupported synthetic decision" unless OfflineRunReview::DECISIONS.include?(decision)
      raise Denied, "Synthetic review unavailable" unless !Rails.env.production? &&
        (Rails.env.test? || (Rails.env.development? && ENV["RC_STUDIO_AI_OFFLINE"] == "true"))

      @intake.with_lock do
        @access.assert_owner!
        run = @workspace.studio_offline_runs.find_by!(
          id: run_id, client_id: @intake.client_id, project_intake_id: @intake.id
        )
        run.verified_payload!
        raise Denied, "Already reviewed" if run.review.present?
        recorded_at = Time.current.utc
        digest = OfflineRunReview.compute_digest(
          studio_offline_run_id: run.id, workspace_id: @workspace.id,
          client_id: @intake.client_id, project_intake_id: @intake.id,
          reviewer_user_id: @actor.id, decision: decision,
          run_digest: run.event_digest, recorded_at: recorded_at
        )
        run.create_review!(workspace_id: @workspace.id, client_id: @intake.client_id,
          project_intake_id: @intake.id, reviewer_user_id: @actor.id,
          decision: decision, run_digest: run.event_digest,
          event_digest: digest, recorded_at: recorded_at)
      end
    end
  end
end
