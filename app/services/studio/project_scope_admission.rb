module Studio
  # RC-039 I1: internal domain admission, not public/client UI.
  #
  # The caller must supply the *server-authenticated* client account from a
  # client session in a future HTTP slice. Passing an ID/actor object is NOT
  # itself proof that a real client agreed; no HTTP route exists here.
  class ProjectScopeAdmission
    class Denied < StandardError; end
    class Conflict < StandardError; end

    def initialize(workspace:)
      @workspace = workspace
    end

    def accept_spec!(actor:, grant:, client:, intake:, spec_id:,
                     presented_digest:, explicit_confirmation: false,
                     explicit_synthetic: false)
      guard!(explicit_synthetic)
      unless actor.is_a?(ClientAccount) && actor.persisted? && actor.active? &&
             grant.is_a?(ClientProjectGrant) && grant.persisted? &&
             grant.studio_client_account_id == actor.id
        raise Denied, "Authenticated fictional client grant required"
      end

      scoped = client_scoped_intake!(client, intake)
      scoped.with_lock do
        guard!(explicit_synthetic)
        require_accessible_grant!(grant, actor, scoped)
        spec = current_approved_spec!(scoped, spec_id)
        digest = ProjectScopeFingerprint.call(spec.document)
        unless presented_digest.is_a?(String) &&
               presented_digest.match?(/\A[0-9a-f]{64}\z/) &&
               ActiveSupport::SecurityUtils.secure_compare(presented_digest, digest) &&
               explicit_confirmation == true
          raise Denied, "Exact specification revision must be confirmed explicitly"
        end

        receipt = ProjectScopeAcceptance.find_by(project_intake_id: scoped.id)
        if receipt
          raise Conflict, "Another scope version has already been accepted" unless
            receipt.studio_client_project_grant_id == grant.id &&
            receipt.studio_client_account_id == actor.id &&
            receipt.intake_spec_version_id == spec.id &&
            receipt.document_sha256 == digest
          return acceptance_receipt(receipt)
        end

        receipt = ProjectScopeAcceptance.new(
          workspace: @workspace, client: client, project_intake: scoped,
          intake_spec_version: spec, client_project_grant: grant,
          client_account: actor, document_sha256: digest,
          accepted_at: Time.current
        )
        receipt.accepting_actor = actor
        receipt.save!
        acceptance_receipt(receipt)
      end
    end

    def activate_project!(actor:, client:, intake:, acceptance_id:,
                          explicit_synthetic: false)
      guard!(explicit_synthetic)
      access = WorkspaceMemory::Access.new(actor: actor, workspace: @workspace)
      access.assert_client!(client)
      scoped = @workspace.project_intakes.where(client_id: client.id).find(intake.id)
      scoped.with_lock do
        guard!(explicit_synthetic)
        access.assert_client!(client)
        acceptance = ProjectScopeAcceptance.where(
          workspace_id: @workspace.id, client_id: client.id,
          project_intake_id: scoped.id
        ).find(acceptance_id)
        grant = acceptance.client_project_grant
        require_accessible_grant!(grant, acceptance.client_account, scoped)
        current_approved_spec!(scoped, acceptance.intake_spec_version_id)
        digest = ProjectScopeFingerprint.call(acceptance.intake_spec_version.document)
        raise Conflict, "Accepted scope was edited or replaced" unless
          ActiveSupport::SecurityUtils.secure_compare(acceptance.document_sha256, digest)

        existing = Project.find_by(project_intake_id: scoped.id)
        if existing
          raise Conflict, "Project is bound to another specification" unless
            existing.studio_project_scope_acceptance_id == acceptance.id &&
            existing.document_sha256 == digest &&
            existing.created_by_id == actor.id
          return project_receipt(existing)
        end

        project = Project.create!(
          workspace: @workspace, client: client, project_intake: scoped,
          intake_spec_version: acceptance.intake_spec_version,
          project_scope_acceptance: acceptance,
          document_sha256: digest, created_by: actor,
          status: "internal_scope_locked"
        )
        project_receipt(project)
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Owner project scope does not match acceptance"
    end

    def owner_summary!(actor:, project_id:, explicit_synthetic: false)
      guard!(explicit_synthetic)
      WorkspaceMemory::Access.new(actor: actor, workspace: @workspace).assert_owner!
      project = Project.where(workspace_id: @workspace.id).find(project_id)
      project_receipt(project)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Project unavailable to owner"
    end

    def client_summary!(actor:, grant:, project_id:, explicit_synthetic: false)
      guard!(explicit_synthetic)
      unless actor.is_a?(ClientAccount) && actor.persisted? &&
             grant.is_a?(ClientProjectGrant) && grant.studio_client_account_id == actor.id
        raise Denied, "Client identity or grant is missing"
      end
      project = Project.where(
        workspace_id: @workspace.id, client_id: grant.client_id,
        project_intake_id: grant.project_intake_id
      ).find(project_id)
      require_accessible_grant!(grant, actor, project.project_intake)
      unless project.project_scope_acceptance.studio_client_project_grant_id == grant.id &&
             project.project_scope_acceptance.studio_client_account_id == actor.id
        raise Denied, "Exact accepting client account required"
      end
      project_receipt(project)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Project unavailable to client"
    end

    private

    def guard!(explicit_synthetic)
      unless Rails.env.test? && !Rails.env.production? &&
             explicit_synthetic == true &&
             @workspace.is_a?(Workspace) && @workspace.persisted? &&
             @workspace.state == "internal"
        raise Denied, "Test-only internal scope admission required"
      end
    end

    def client_scoped_intake!(client, intake)
      unless client.is_a?(Client) && client.persisted? &&
             client.workspace_id == @workspace.id &&
             intake.is_a?(ProjectIntake) && intake.persisted?
        raise Denied, "Exact tenant-scoped client and intake required"
      end
      @workspace.project_intakes.where(client_id: client.id).find(intake.id)
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Scoped intake missing"
    end

    def require_accessible_grant!(grant, actor, scoped)
      unless actor.active? && grant.accessible_for?(actor) &&
             grant.workspace_id == @workspace.id &&
             grant.client_id == scoped.client_id &&
             grant.project_intake_id == scoped.id &&
             grant.studio_client_account_id == actor.id &&
             grant.role == "reviewer" &&
             grant.consented_at.present? &&
             grant.accepted_at.present?
        raise Denied, "Active exact client grant and consent required"
      end

      # A mailbox-only proof cannot approve scope. This check confirms only
      # the pre-existing invite verification chain; session binding is a
      # separate requirement for a future HTTP controller.
      proof = grant.project_invitation.project_invitation_email_proof
      unless proof&.verified? && proof.verified_at <= proof.expires_at
        raise Denied, "Previously verified invitation evidence required"
      end
    end

    def current_approved_spec!(scoped, spec_id)
      spec = scoped.intake_spec_versions.order(version: :desc).first
      unless spec && spec.id == spec_id && spec.owner_approved_at.present? &&
             spec.document.is_a?(Hash) &&
             spec.document["acceptance_criteria"].is_a?(Array) &&
             spec.document["acceptance_criteria"].any?
        raise Denied, "Latest exact owner-approved specification required"
      end
      spec
    end

    def acceptance_receipt(receipt)
      {
        "acceptance_id" => receipt.id,
        "project_intake_id" => receipt.project_intake_id,
        "spec_version_id" => receipt.intake_spec_version_id,
        "document_sha256" => receipt.document_sha256,
        "classification" => "INTERNAL_TEST_ONLY_SPEC_ACCEPTANCE",
        "production_scope_approved" => false
      }
    end

    def project_receipt(project)
      {
        "project_id" => project.id,
        "project_intake_id" => project.project_intake_id,
        "spec_version_id" => project.intake_spec_version_id,
        "document_sha256" => project.document_sha256,
        "status" => project.status,
        "classification" => "INTERNAL_TEST_ONLY_PROJECT",
        "client_portal_enabled" => false,
        "tasks_executable" => false,
        "project_calendar_enabled" => false,
        "client_delivery_approved" => false,
        "source_files_included" => false
      }
    end
  end
end
