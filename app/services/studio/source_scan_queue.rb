module Studio
  # Owner-only NONPRODUCTION synthetic queue. PostgreSQL SKIP LOCKED protects
  # against competing workers; a transaction holds the task lock until the
  # bounded (<=8s clamd) scan finishes. No external queue/Redis required.
  # Never process customer files, and never run this in Rails production.
  class SourceScanQueue
    class Denied < StandardError; end

    MAX_BATCH = 10
    RETRY_DELAYS = [5.minutes, 30.minutes].freeze

    def initialize(actor:, workspace:, storage: nil, scanner: nil)
      @workspace = workspace
      @access = WorkspaceMemory::Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
      raise Denied, "Synthetic scan storage is unavailable" unless PrivateSourceStorage.enabled?

      @pipeline = ProjectSourcePipeline.new(actor: actor, workspace: workspace,
                                             storage: storage, scanner: scanner)
    end

    def enqueue!(client:, intake:, source_id:)
      @access.assert_client!(client)
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             intake.workspace_id == @workspace.id && intake.client_id == client.id
        raise Denied, "Invalid scoped project intake"
      end

      source = @workspace.project_sources
                         .where(client_id: client.id, project_intake_id: intake.id)
                         .find(source_id)
      blob = @workspace.project_source_blobs.find_by!(project_source_id: source.id)
      unless %w[quarantined failed].include?(blob.scan_state) && blob.expires_at.future?
        raise Denied, "Source is not eligible for a queued synthetic scan"
      end

      @workspace.studio_source_scan_tasks.create_or_find_by!(project_source_blob_id: blob.id) do |task|
        task.state = "queued"
        task.next_attempt_at = Time.current
      end
    end

    def process_due!(limit: MAX_BATCH)
      raise ArgumentError, "Invalid batch size" unless limit.is_a?(Integer) && limit.between?(1, MAX_BATCH)
      @access.assert_owner!
      count = 0
      limit.times do
        @access.assert_owner!
        processed = SourceScanTask.transaction do
          task = @workspace.studio_source_scan_tasks.due
                           .order(:next_attempt_at, :id)
                           .lock("FOR UPDATE SKIP LOCKED").first
          if task
            handle!(task)
            true
          else
            false
          end
        end
        break unless processed

        count += 1
      end
      count
    end

    def summary
      @access.assert_owner!
      raise Denied, "Nonproduction only" unless PrivateSourceStorage.enabled?

      @workspace.studio_source_scan_tasks.group(:state).count
    end

    private

    def handle!(task)
      @access.assert_owner!
      blob = @workspace.project_source_blobs.find(task.project_source_blob_id)
      if blob.expires_at <= Time.current
        finish!(task, "expired")
      elsif blob.scan_state == "revoked"
        finish!(task, "cancelled")
      elsif blob.scan_state == "clean"
        finish!(task, "complete_clean")
      elsif blob.scan_state == "infected"
        finish!(task, "complete_infected")
      elsif %w[quarantined failed].include?(blob.scan_state)
        attempt_scan!(task, blob)
      else
        finish!(task, "cancelled")
      end
    end

    def attempt_scan!(task, blob)
      attempt = task.attempts + 1
      begin
        result = @pipeline.scan!(client: blob.client, intake: blob.project_intake,
                                  source_id: blob.project_source_id)
        case result.scan_state
        when "clean" then finish!(task, "complete_clean", attempts: attempt)
        when "infected" then finish!(task, "complete_infected", attempts: attempt)
        else raise Denied, "Unsupported scan state"
        end
      rescue ProjectSourcePipeline::Denied, Denied, PrivateSourceStorage::Unavailable,
             ActiveRecord::RecordNotFound
        if blob.reload.expires_at <= Time.current
          finish!(task, "expired", attempts: attempt, error: "scan_denied")
        elsif attempt >= SourceScanTask::MAX_ATTEMPTS
          finish!(task, "exhausted", attempts: attempt, error: "scan_denied")
        else
          task.update!(
            state: "retry_wait", attempts: attempt,
            next_attempt_at: RETRY_DELAYS.fetch(attempt - 1).from_now,
            last_error_code: "scan_denied"
          )
        end
      end
    end

    def finish!(task, state, attempts: task.attempts, error: nil)
      task.update!(
        state: state, attempts: attempts, last_error_code: error,
        finished_at: Time.current
      )
    end
  end
end
