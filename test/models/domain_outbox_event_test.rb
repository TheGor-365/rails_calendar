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
