# C2.3b6c2.1: private, durable operator command ledger. No replay is invoked
# by creating this table, and no endpoint or background scheduler is enabled.
class CreateOwnerOutboxReplayRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :owner_outbox_replay_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :owner_user, null: false, foreign_key: { to_table: :users }
      t.string :request_digest, null: false, limit: 64
      t.string :state, null: false, default: "running", limit: 16
      t.integer :requested_limit, null: false
      t.integer :attempted_count, null: false, default: 0
      t.integer :delivered_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :error_code, limit: 80
      t.timestamps
    end

    add_index :owner_outbox_replay_runs, %i[workspace_id request_digest],
      unique: true, name: "idx_outbox_replay_workspace_request"
    # Fail closed on crashes: one unfinished invocation per workspace.
    # No automatic stale lease takeover or operator replay is implemented.
    add_index :owner_outbox_replay_runs, :workspace_id, unique: true,
      where: "state = 'running'", name: "idx_outbox_replay_one_running"

    add_check_constraint :owner_outbox_replay_runs,
      "state IN ('running', 'succeeded', 'failed')",
      name: "chk_outbox_replay_run_state"
    add_check_constraint :owner_outbox_replay_runs,
      "requested_limit IN (1, 5, 10, 25)",
      name: "chk_outbox_replay_run_limit"
    add_check_constraint :owner_outbox_replay_runs,
      "attempted_count >= 0 AND delivered_count >= 0 AND failed_count >= 0 " \
      "AND delivered_count + failed_count <= attempted_count " \
      "AND attempted_count <= requested_limit",
      name: "chk_outbox_replay_run_counts"
    add_check_constraint :owner_outbox_replay_runs,
      "request_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_outbox_replay_request_digest"
    add_check_constraint :owner_outbox_replay_runs,
      "(state = 'running' AND finished_at IS NULL) OR " \
      "(state IN ('succeeded', 'failed') AND finished_at IS NOT NULL)",
      name: "chk_outbox_replay_finished_state"
  end
end
