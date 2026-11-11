class CreateProjectInvitationEmailProofs < ActiveRecord::Migration[8.1]
  def change
    # Test/local-development only protocol. The proof is NOT a client account
    # or a permission grant, and no raw verification code/email is stored.
    create_table :project_invitation_email_proofs do |t|
      t.references :project_invitation, null: false, foreign_key: true,
                   index: { unique: true, name: "idx_invitation_email_proofs_one_per_invite" }
      t.string :challenge_digest, limit: 64, null: false
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :expires_at, null: false
      t.datetime :verified_at
      t.timestamps
    end
    add_check_constraint :project_invitation_email_proofs,
                         %q(challenge_digest ~ '^[0-9a-f]{64}$'),
                         name: "chk_invitation_email_proof_digest"
    add_check_constraint :project_invitation_email_proofs,
                         "failed_attempts BETWEEN 0 AND 5",
                         name: "chk_invitation_email_proof_attempts"
    add_check_constraint :project_invitation_email_proofs,
                         "expires_at > created_at AND expires_at <= created_at + interval '15 minutes'",
                         name: "chk_invitation_email_proof_expiry"
    add_check_constraint :project_invitation_email_proofs,
                         "verified_at IS NULL OR verified_at <= expires_at",
                         name: "chk_invitation_email_proof_verified_before_expiry"
  end
end
