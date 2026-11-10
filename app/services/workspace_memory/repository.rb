module WorkspaceMemory
  # Internal-only client memory. No controller routes, cross-client retrieval,
  # embeddings, provider payload, auto-discovery or personal-data collection.
  class Repository
    def initialize(actor:, workspace:)
      @actor = actor
      @workspace = workspace
      @access = Access.new(actor: actor, workspace: workspace)
      @access.assert_owner!
    end

    def record_fact!(client:, field_key:, payload:, status: "reported",
                     sensitivity: "internal", purpose: "discovery",
                     source_kind: "owner_note", source_ref:, expires_at: nil)
      @access.assert_client!(client)

      # Client row lock serializes revision allocation within a workspace.
      client.with_lock do
        previous = client.client_facts.where(field_key: field_key).maximum(:revision).to_i
        client.client_facts.create!(
          workspace: @workspace, recorded_by: @actor, field_key: field_key,
          revision: previous + 1, payload: payload,
          status: status, sensitivity: sensitivity, purpose: purpose,
          source_kind: source_kind, source_ref: source_ref, expires_at: expires_at
        )
      end
    end

    def record_consent!(client:, purpose:, granted:, source_ref:)
      @access.assert_client!(client)
      client.client_consents.create!(
        workspace: @workspace, recorded_by: @actor, purpose: purpose,
        granted: granted, source_ref: source_ref
      )
    end

    def current_facts(client:, purpose: "discovery", as_of: Time.current)
      @access.assert_client!(client)
      raise ArgumentError, "Unknown purpose" unless ClientFact::PURPOSES.include?(purpose)

      # Always select the latest revision FIRST, then apply expiry/status.
      # Never resurrect a superseded fact when its newest revision is excluded.
      rows = client.client_facts.where(workspace_id: @workspace.id, purpose: purpose)
                   .order(:field_key, revision: :desc).to_a
      current = rows.group_by(&:field_key).values.map(&:first)
      selected = current.reject do |fact|
        fact.status.in?(%w[disputed excluded]) ||
          (fact.expires_at && fact.expires_at <= as_of)
      end
      {
        "classification" => "OWNER_INTERNAL_ONLY_DO_NOT_SEND_TO_PROVIDER",
        "workspace_id" => @workspace.id,
        "client_id" => client.id,
        "purpose" => purpose,
        "facts" => selected.map do |fact|
          {
            "field_key" => fact.field_key, "value" => fact.payload.deep_dup,
            "status" => fact.status, "sensitivity" => fact.sensitivity,
            "source_ref" => fact.source_ref, "revision" => fact.revision,
            "source_id" => "client_fact:#{fact.id}"
          }
        end,
        "provider_ready" => false
      }
    end

    def history(client:, field_key:)
      @access.assert_client!(client)
      client.client_facts.where(workspace_id: @workspace.id, field_key: field_key)
            .order(:revision).map do |fact|
        {
          "revision" => fact.revision,
          "source_id" => "client_fact:#{fact.id}",
          "status" => fact.status,
          "payload" => fact.payload.deep_dup,
          "source_ref" => fact.source_ref,
          "recorded_at" => fact.created_at.iso8601
        }
      end
    end

    def consent_state(client:, purpose:)
      @access.assert_client!(client)
      raise ArgumentError, "Unknown consent purpose" unless ClientConsent::PURPOSES.include?(purpose)
      record = client.client_consents.where(workspace_id: @workspace.id, purpose: purpose)
                     .order(created_at: :desc, id: :desc).first
      record ? record.granted? : false
    end

    def provider_payload
      raise SecurityError, "External AI is disabled until RC-036/RC-037 gates"
    end
  end
end
