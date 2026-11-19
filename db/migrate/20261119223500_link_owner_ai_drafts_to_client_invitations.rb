# E2.3: durable owner-only draft provenance for an invitation.
# The linked AI result is never exposed to the guest without owner review.
class LinkOwnerAiDraftsToClientInvitations < ActiveRecord::Migration[8.1]
  def change
    add_reference :client_request_invitations, :owner_ai_entry,
      null: true, foreign_key: { to_table: :ai_spend_entries }
    add_column :client_request_invitations, :approved_client_preview, :text
    add_check_constraint :client_request_invitations,
      "approved_client_preview IS NULL OR char_length(approved_client_preview) <= 1200",
      name: "chk_e2_invite_approved_preview_length"
  end
end
