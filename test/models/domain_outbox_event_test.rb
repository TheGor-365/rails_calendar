require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class DomainOutboxEventTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-other-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @intake = ProjectIntake.create!(
      workspace: @workspace, title: "Fictional transactional event replay",
      project_type: "rails_bugfix",
      goal: "Verify a synthetic requirement revision and recover its activity.",
      demo_consent_at: Time.current
    )
    @scope = @intake.intake_scope_revisions.create!(
      version: 1, author_role: "owner",
      answers: {
        "business_goal" => {
          "text" => "A fictional form should submit.", "status" => "suggested",
          "responsibility" => "owner"
        }
      }
    )
    # C2.3b5: model setup itself now commits an intake + scope envelope.
    # Drain those synthetic baseline events so subsequent isolated replay
    # expectations concern only the exact source created in each test.
    DomainOutbox::Replayer.run!(workspace: @workspace)
  end

  def new_revision(version: 1)
    @intake.intake_requirement_sets.create!(
      version: version, intake_scope_revision: @scope,
      requirements: [{
        "id" => "R-001",
        "source" => { "type" => "intake_scope_revision",
                      "revision_id" => @scope.id, "section" => "business_goal" },
        "statement" => "A fictional form should submit.",
        "status" => "suggested",
        "acceptance_criteria" => ["Synthetic success can be observed."]
      }]
    )
  end

  test "enqueue commits in the same transaction and preserves legacy activity" do
    assert_difference(["DomainOutboxEvent.count", "IntakeRequirementSet.count", "ActivityEvent.count"], 1) do
      @revision = new_revision
    end

    queued = DomainOutboxEvent.find_by!(
      workspace_id: @workspace.id, source_type: "IntakeRequirementSet",
      source_id: @revision.id, source_version: 1, kind: "requirements_saved"
    )
    assert_equal "pending", queued.state
    assert_equal 0, queued.attempts
    assert_nil queued.delivered_at
    legacy = @workspace.activity_events.find_by!(
      event_key: "IntakeRequirementSet:#{@revision.id}:requirements_saved"
    )
    assert_equal({ "version" => 1 }, legacy.metadata)
    assert_equal @revision.created_at.to_i, queued.occurred_at.to_i
    assert_not_includes queued.attributes.keys, "client_answer_body"
  end

  test "rolled-back source never leaves an orphan outbox row" do
    assert_no_difference(["DomainOutboxEvent.count", "IntakeRequirementSet.count"]) do
      IntakeRequirementSet.transaction do
        new_revision
        raise ActiveRecord::Rollback
      end
    end
  end

  test "replay restores missing event once without a provider attempt or new revision" do
    original = new_revision
    outbox = DomainOutboxEvent.find_by!(source_id: original.id, source_type: "IntakeRequirementSet")
    key = "IntakeRequirementSet:#{original.id}:requirements_saved"
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all # test-only loss simulation
    assert_equal 0, ActivityEvent.where(workspace_id: @workspace.id, event_key: key).count

    assert_no_difference(["AiSpendEntry.count", "IntakeRequirementSet.count"]) do
      result = DomainOutbox::Replayer.run!(workspace: @workspace, limit: 10)
      assert_equal({ attempted: 1, delivered: 1, failed: 0 }, result)
    end
    assert_equal 1, ActivityEvent.where(workspace_id: @workspace.id, event_key: key).count
    outbox.reload
    assert_equal "delivered", outbox.state
    assert_equal 1, outbox.attempts
    assert outbox.delivered_at.present?

    assert_no_difference(["ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal({ attempted: 0, delivered: 0, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
  end

  test "replay existing immediate projection marks only outbox delivered" do
    original = new_revision
    key = "IntakeRequirementSet:#{original.id}:requirements_saved"
    existing = @workspace.activity_events.find_by!(event_key: key)
    assert_no_difference(["ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal 1, DomainOutbox::Replayer.run!(workspace: @workspace)[:delivered]
    end
    assert_equal existing.id, @workspace.activity_events.find_by!(event_key: key).id
  end

  def settled_ai_reply_fixture
    conversation = @workspace.owner_ai_conversations.create!(
      title: "Synthetic source-linked AI reply", scope: "owner_general", state: "active"
    )
    ledger = AiSpendEntry.create!(
      professional_profile: @workspace.professional_profile,
      operation: OwnerAi::ConversationResponder::VERSION,
      model: "local-synthetic", request_digest: Digest::SHA256.hexdigest(SecureRandom.hex(16)),
      status: "settled", reserved_ticks: 0, charged_ticks: 0,
      result: { "conversation_id" => conversation.id }
    )
    prompt = conversation.owner_ai_messages.create!(
      role: "owner", state: "settled", sequence: 1,
      body: "Explain the fictional request"
    )
    pending = conversation.owner_ai_messages.create!(
      role: "assistant", state: "pending", sequence: 2,
      body: "Pending synthetic response", parent_message: prompt
    )
    [conversation, ledger, pending]
  end

  test "settled AI response atomically enqueues a private source-only event" do
    conversation, ledger, reply = settled_ai_reply_fixture
    assert_not DomainOutboxEvent.exists?(source_type: "OwnerAiMessage", source_id: reply.id)

    assert_difference(["DomainOutboxEvent.count", "ActivityEvent.count"], 1) do
      reply.update!(state: "settled", ai_spend_entry: ledger,
                    body: "Fictional test-only provider response.")
    end
    row = DomainOutboxEvent.find_by!(workspace: @workspace, source_type: "OwnerAiMessage",
      source_id: reply.id, source_version: 2, kind: "ai_reply_saved")
    assert_equal "pending", row.state
    assert_not_includes row.attributes.values.map(&:to_s), reply.body
    key = "OwnerAiMessage:#{reply.id}:ai_reply_saved"
    event = @workspace.activity_events.find_by!(event_key: key)
    assert_equal "AI reply saved", event.title
    assert_equal({}, event.metadata)
    assert_equal Rails.application.routes.url_helpers.owner_ai_conversation_path(conversation), Activity::Presenter.display(event)[:path]

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      reply.update!(body: "Fictional revised text, no automatic second delivery")
    end
  end

  test "replaying settled AI source restores missing event without cost or tenant leak" do
    conversation, ledger, reply = settled_ai_reply_fixture
    reply.update!(state: "settled", body: "Synthetic saved answer", ai_spend_entry: ledger)
    key = "OwnerAiMessage:#{reply.id}:ai_reply_saved"
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all # isolated synthetic test
    assert_equal({ attempted: 0, delivered: 0, failed: 0 },
      DomainOutbox::Replayer.run!(workspace: @other_workspace))

    assert_no_difference ["AiSpendEntry.count", "OwnerAiMessage.count"] do
      result = DomainOutbox::Replayer.run!(workspace: @workspace)
      assert_equal({ attempted: 1, delivered: 1, failed: 0 }, result)
    end
    assert_equal 1, @workspace.activity_events.where(event_key: key).count
    assert_equal "delivered", DomainOutboxEvent.find_by!(
      source_type: "OwnerAiMessage", source_id: reply.id
    ).state
    assert_no_difference ["AiSpendEntry.count", "ActivityEvent.count"] do
      assert_equal({ attempted: 0, delivered: 0, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end

    assert_no_difference("ActivityEvent.count") do
      Activity::Recorder.record!(workspace: @other_workspace, subject: reply,
        kind: "ai_reply_saved", title: "Unauthorized synthetic foreign event")
    end
    assert_equal Rails.application.routes.url_helpers.owner_ai_conversation_path(conversation),
      Activity::Presenter.display(@workspace.activity_events.find_by!(event_key: key))[:path]
  end

  test "pending and rolled-back AI replies do not leave an outbox envelope" do
    _conversation, ledger, reply = settled_ai_reply_fixture
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count"]) do
      reply.update!(state: "uncertain")
    end
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count"]) do
      OwnerAiMessage.transaction do
        reply.update!(state: "settled", ai_spend_entry: ledger)
        raise ActiveRecord::Rollback
      end
    end
    assert_equal "uncertain", reply.reload.state
    assert_nil reply.reload.ai_spend_entry_id
  end

  def synthetic_invitation
    ClientRequestInvitation.create!(
      workspace: @workspace, token_digest: SecureRandom.hex(32),
      seed_title: "Fictional source replay",
      seed_project_type: "rails_bugfix",
      seed_goal: "Verify an invitation transition without real client information.",
      expires_at: 48.hours.from_now, service_version_ids: []
    )
  end

  test "C2.3b3.2 claimed and submitted transitions are immutable indexed activities" do
    invitation = synthetic_invitation
    client = make_test_client("outbox-claim-#{SecureRandom.hex(6)}@example.test")
    claimed_at = Time.current.change(usec: 0)
    submitted_at = claimed_at + 2.minutes

    assert_difference(["DomainOutboxEvent.count", "ActivityEvent.count"], 2) do
      invitation.update!(claimed_at: claimed_at, claimed_by_user: client,
        project_intake: @intake)
      invitation.update!(submitted_at: submitted_at)
    end
    rows = DomainOutboxEvent.where(workspace_id: @workspace.id, source_type: "ClientRequestInvitation",
      source_id: invitation.id, kind: %w[invitation_claimed invitation_submitted]).order(:source_version)
    assert_equal %w[invitation_claimed invitation_submitted], rows.pluck(:kind)
    assert_equal [2, 3], rows.pluck(:source_version)
    assert_equal [claimed_at.to_i, submitted_at.to_i], rows.pluck(:occurred_at).map(&:to_i)

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      invitation.update!(claimed_at: claimed_at, submitted_at: submitted_at)
      assert_equal({ attempted: 3, delivered: 3, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
      assert_equal({ attempted: 0, delivered: 0, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
  end

  test "C2.3b3.2 rolled back revocation leaves no outbox or activity" do
    invitation = synthetic_invitation
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count"]) do
      ClientRequestInvitation.transaction do
        invitation.update!(revoked_at: Time.current)
        raise ActiveRecord::Rollback
      end
    end
    assert_nil invitation.reload.revoked_at
    assert_not DomainOutboxEvent.where(workspace_id: @workspace.id, source_type: "ClientRequestInvitation",
      source_id: invitation.id, kind: "invitation_revoked").exists?
  end

  test "C2.3b3.2 replay refuses altered transition time and records a safe failure" do
    invitation = synthetic_invitation
    assert_equal 1, DomainOutbox::Replayer.run!(workspace: @workspace)[:delivered]
    client = make_test_client("outbox-drift-#{SecureRandom.hex(6)}@example.test")
    claimed_at = Time.current.change(usec: 0)
    invitation.update!(claimed_at: claimed_at, claimed_by_user: client,
      project_intake: @intake)
    key = "ClientRequestInvitation:#{invitation.id}:invitation_claimed"
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all
    # Synthetic tampering: a replay must never silently reinterpret its
    # immutable historical timestamp as a different real-world event.
    invitation.update_columns(claimed_at: claimed_at + 1.hour)

    assert_no_difference(["ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal({ attempted: 1, delivered: 0, failed: 1 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
    record = DomainOutboxEvent.find_by!(source_type: "ClientRequestInvitation",
      source_id: invitation.id, kind: "invitation_claimed")
    assert_equal "failed", record.state
    assert_equal "DomainOutbox::Replayer::SourceUnavailable", record.last_error_code
  end

  def synthetic_approved_service
    capability = @workspace.professional_profile.professional_capabilities.order(:id).first
    catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    offering = catalogue.create_draft!(
      service_fields(capability, title: "Repair a fictional Rails endpoint")
    )
    version = offering.latest_version
    version.update!(approved_at: Time.current)
    offering.update!(approved_version: version)
    [catalogue, offering, version]
  end

  test "C2.3b4 only owner-published service versions produce immutable source events" do
    catalogue, offering, version = synthetic_approved_service
    assert_not DomainOutboxEvent.where(source_type: "ServiceOfferingPublication").exists?

    assert_difference(["DomainOutboxEvent.count", "ActivityEvent.count"], 1) do
      catalogue.publish!(offering: offering, version_id: version.id,
        digest: version.digest, confirmed: true, owner: @owner)
    end
    published = offering.publications.order(:id).last
    assert_equal "publish", published.event
    assert_equal version.id, published.service_offering_version_id
    event = DomainOutboxEvent.find_by!(
      workspace_id: @workspace.id, source_type: "ServiceOfferingPublication",
      source_id: published.id, source_version: 1, kind: "service_published"
    )
    assert_equal "pending", event.state
    assert_not_includes event.attributes.keys, "included_scope"
    activity = ActivityEvent.find_by!(workspace_id: @workspace.id,
      event_key: "ServiceOfferingPublication:#{published.id}:service_published")
    assert_equal version.title, activity.title
    assert_equal Rails.application.routes.url_helpers.owner_service_path(offering),
      Activity::Presenter.display(activity)[:path]

    assert_difference(["DomainOutboxEvent.count", "ActivityEvent.count"], 1) do
      catalogue.unpublish!(offering: offering, owner: @owner, confirmed: true)
    end
    unpublished = offering.publications.order(:id).last
    assert_equal "unpublish", unpublished.event
    assert_equal "pending", DomainOutboxEvent.find_by!(
      source_type: "ServiceOfferingPublication", source_id: unpublished.id,
      kind: "service_unpublished").state

    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal({ attempted: 2, delivered: 2, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
      assert_equal({ attempted: 0, delivered: 0, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
    assert_equal 2, @workspace.activity_events.where(
      subject_type: "ServiceOfferingPublication",
      subject_id: [published.id, unpublished.id]).count
  end

  test "C2.3b4 service replay restores missing activity without republishing service" do
    catalogue, offering, version = synthetic_approved_service
    catalogue.publish!(offering: offering, version_id: version.id,
      digest: version.digest, confirmed: true, owner: @owner)
    published = offering.publications.order(:id).last
    key = "ServiceOfferingPublication:#{published.id}:service_published"
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all

    assert_equal({ attempted: 0, delivered: 0, failed: 0 },
      DomainOutbox::Replayer.run!(workspace: @other_workspace))
    assert_no_difference(["ServiceOfferingPublication.count", "AiSpendEntry.count"]) do
      assert_equal 1, DomainOutbox::Replayer.run!(workspace: @workspace)[:delivered]
    end
    assert_equal version.id, offering.reload.published_version_id
    assert_equal 1, ActivityEvent.where(workspace_id: @workspace.id, event_key: key).count
    assert_equal 0, @other_workspace.activity_events.where(event_key: key).count
  end

  test "C2.3b4 rolled back publication has no outbox or activity" do
    _catalogue, offering, version = synthetic_approved_service
    assert_no_difference(["ServiceOfferingPublication.count", "DomainOutboxEvent.count",
      "ActivityEvent.count"]) do
      ServiceOfferingPublication.transaction do
        offering.publications.create!(event: "publish",
          service_offering_version: version, owner_user: @owner)
        raise ActiveRecord::Rollback
      end
    end
  end

  test "C2.3b4 unapproved version is not a valid publication audit" do
    capability = @workspace.professional_profile.professional_capabilities.order(:id).first
    catalogue = OwnerServices::Catalogue.new(workspace: @workspace)
    offering = catalogue.create_draft!(service_fields(capability))
    assert_no_difference(["ServiceOfferingPublication.count", "DomainOutboxEvent.count"]) do
      assert_not offering.publications.build(event: "publish",
        service_offering_version: offering.latest_version, owner_user: @owner).valid?
    end
  end

  test "C2.3b5 saved scoped intake is atomic and replayable without private text" do
    intake = nil
    assert_difference(["ProjectIntake.count", "DomainOutboxEvent.count", "ActivityEvent.count"], 1) do
      intake = ProjectIntake.create!(
        workspace: @workspace, title: "Fictional confidential client form",
        project_type: "rails_bugfix", goal: "An entirely synthetic private client request.",
        demo_consent_at: Time.current
      )
    end
    envelope = DomainOutboxEvent.find_by!(
      workspace_id: @workspace.id, source_type: "ProjectIntake",
      source_id: intake.id, source_version: 1, kind: "intake_created"
    )
    assert_equal "pending", envelope.state
    assert_not_includes envelope.attributes.values.map(&:to_s), intake.goal
    key = "ProjectIntake:#{intake.id}:intake_created"

    assert_no_difference(["AiSpendEntry.count", "ProjectIntake.count"]) do
      ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all # synthetic test-only
      assert_equal({ attempted: 1, delivered: 1, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
    assert_equal 1, @workspace.activity_events.where(event_key: key).count
    assert_equal "delivered", envelope.reload.state
    assert_no_difference(["ActivityEvent.count", "AiSpendEntry.count"]) do
      assert_equal 0, DomainOutbox::Replayer.run!(workspace: @workspace)[:attempted]
    end
    assert_equal 0, @other_workspace.activity_events.where(event_key: key).count
  end

  test "C2.3b5 client and owner scope versions are distinct, private and replayable" do
    client_scope = nil
    owner_scope = nil
    answers = {
      "business_goal" => {
        "text" => "Sensitive synthetic client wording; never copied to event metadata",
        "status" => "unknown", "responsibility" => "client"
      }
    }
    assert_difference(["IntakeScopeRevision.count", "DomainOutboxEvent.count", "ActivityEvent.count"], 2) do
      client_scope = @intake.intake_scope_revisions.create!(
        version: 2, author_role: "client", answers: answers
      )
      owner_scope = @intake.intake_scope_revisions.create!(
        version: 3, author_role: "owner", answers: { "business_goal" => {
          "text" => "A fictional owner implementation suggestion",
          "status" => "suggested", "responsibility" => "owner"
        } }
      )
    end
    assert_equal 1, @intake.intake_scope_revisions.where(id: client_scope.id).count
    rows = DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "IntakeScopeRevision", source_id: [client_scope.id, owner_scope.id])
      .order(:source_version)
    assert_equal [2, 3], rows.pluck(:source_version)
    assert_equal %w[scope_revision_saved scope_revision_saved], rows.pluck(:kind)
    assert rows.all? { |row| !row.attributes.values.map(&:to_s).include?(answers.dig("business_goal", "text")) }
    assert_equal "client", client_scope.reload.author_role
    assert_equal "owner", owner_scope.reload.author_role

    # A missing client revision is recovered privately without generating text.
    key = "IntakeScopeRevision:#{client_scope.id}:scope_revision_saved"
    ActivityEvent.where(workspace_id: @workspace.id, event_key: key).delete_all # test only
    assert_equal({ attempted: 0, delivered: 0, failed: 0 },
      DomainOutbox::Replayer.run!(workspace: @other_workspace))
    assert_no_difference(["AiSpendEntry.count", "IntakeScopeRevision.count"]) do
      assert_equal({ attempted: 2, delivered: 2, failed: 0 },
        DomainOutbox::Replayer.run!(workspace: @workspace))
    end
    actual = @workspace.activity_events.find_by!(event_key: key)
    assert_equal({ "version" => 2 }, actual.metadata)
    assert_not_includes actual.title, "Sensitive synthetic"
    assert_equal Rails.application.routes.url_helpers.owner_requirements_path(@intake),
      Activity::Presenter.display(actual)[:path]
    assert_equal 0, @other_workspace.activity_events.where(event_key: key).count
  end

  test "C2.3b5 rollback and unassigned legacy sources never create outbox" do
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count",
                          "ProjectIntake.count", "IntakeScopeRevision.count"]) do
      ProjectIntake.transaction do
        temporary = ProjectIntake.create!(
          workspace: @workspace, title: "Rolled-back private synthetic request",
          project_type: "rails_bugfix", goal: "This synthetic request must not be committed.",
          demo_consent_at: Time.current
        )
        temporary.intake_scope_revisions.create!(
          version: 1, author_role: "client",
          answers: { "business_goal" => {
            "text" => "Private synthetic rollback",
            "status" => "unknown", "responsibility" => "client"
          } }
        )
        raise ActiveRecord::Rollback
      end
    end

    orphan = nil
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count"]) do
      orphan = ProjectIntake.create!(
        title: "Unassigned legacy fictional intake", project_type: "rails_bugfix",
        goal: "Legacy source without an assigned workspace is private and unprojected.",
        demo_consent_at: Time.current
      )
      orphan.intake_scope_revisions.create!(
        version: 1, author_role: "client", answers: {}
      )
    end
    assert_nil orphan.workspace_id
  end

  test "C2.3b5 refuses foreign source event injection" do
    record = @intake.intake_scope_revisions.create!(
      version: 2, author_role: "client", answers: {}
    )
    assert_no_difference(["ActivityEvent.count", "AiSpendEntry.count"]) do
      Activity::Recorder.record!(
        workspace: @other_workspace, subject: record,
        kind: "scope_revision_saved", title: "Foreign source", metadata: { "version" => 2 }
      )
    end
    assert_equal({ attempted: 0, delivered: 0, failed: 0 },
      DomainOutbox::Replayer.run!(workspace: @other_workspace))
    assert_equal 0, DomainOutboxEvent.where(workspace_id: @other_workspace.id,
      source_type: "IntakeScopeRevision", source_id: record.id).count
  end

  test "foreign workspace cannot replay and invalid source does not create an event" do
    original = new_revision
    outbox = DomainOutboxEvent.find_by!(source_id: original.id, source_type: "IntakeRequirementSet")
    assert_equal({ attempted: 0, delivered: 0, failed: 0 },
      DomainOutbox::Replayer.run!(workspace: @other_workspace))

    missing = DomainOutboxEvent.create!(
      workspace: @workspace, source_type: "IntakeRequirementSet", source_id: 99_999_999,
      source_version: 1, kind: "requirements_saved", occurred_at: Time.current
    )
    count = ActivityEvent.count
    result = DomainOutbox::Replayer.run!(workspace: @workspace, limit: 10)
    assert_equal 1, result[:failed]
    assert_equal count, ActivityEvent.count
    assert_equal "failed", missing.reload.state
    assert_equal "DomainOutbox::Replayer::SourceUnavailable", missing.last_error_code
    assert missing.next_attempt_at > Time.current
    assert_equal "delivered", outbox.reload.state
  end
end
