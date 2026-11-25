require "test_helper"
require_relative "../../support/owner_service_catalogue_test_data"

class DomainOutboxCrossFamilyBackfillDryRunTest < ActiveSupport::TestCase
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("six-dry-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("six-dry-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("six-dry-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @source = 3.times.map do |i|
      ProjectIntake.create!(
        workspace: @workspace, title: "Fictional six-family audit #{i}",
        project_type: "rails_bugfix", goal: "Purely synthetic reconciliation evidence.",
        demo_consent_at: Time.current
      )
    end
    ProjectIntake.create!(
      workspace: @other_workspace, title: "Foreign private text",
      project_type: "rails_bugfix", goal: "Foreign synthetic privacy source.",
      demo_consent_at: Time.current
    )
  end

  def preview(owner: @owner, cursor: nil, limit: 2)
    DomainOutbox::CrossFamilyBackfillDryRun.preview(
      owner: owner, limit: limit, cursor: cursor
    )
  end

  test "C2.3b7g one bounded read-only page per call, six families and aggregate report" do
    assert_no_difference([
      "ProjectIntake.count", "DomainOutboxEvent.count", "ActivityEvent.count",
      "OwnerOutboxReplayRun.count", "AiSpendEntry.count"
    ]) do
      step = preview
      assert_equal "ProjectIntake", step[:source_type]
      assert_equal 2, step[:inspected]
      assert_equal false, step[:completed]
      assert_equal 2, step[:min_resume_seconds]
      assert_equal 2, step[:report].first[:already_indexed]
      assert_not_includes step.to_json, @source.first.title
      assert_not step.key?(:source_id)
      assert_kind_of String, step[:next_cursor]

      travel 3.seconds
      step = preview(cursor: step[:next_cursor])
      assert_equal 1, step[:inspected]
      assert_equal 3, step[:report].first[:already_indexed]
      assert_equal "ProjectIntake", step[:source_type]

      5.times do
        travel 3.seconds
        step = preview(cursor: step[:next_cursor])
      end
      assert step[:completed]
      assert_nil step[:next_cursor]
      assert_equal 6, step[:report].length
      assert_equal 3, step[:report].sum { |row| row[:inspected] }
      assert step[:report].all? { |row| row[:budget_exhausted] == false }
    end
  end

  test "C2.3b7g rejects pacing violations, foreign identities, tampering and wrong family cursor" do
    first = preview
    assert_raises(ArgumentError) { preview(cursor: first[:next_cursor]) }
    assert_raises(ArgumentError) do
      travel 3.seconds do
        preview(owner: @other, cursor: first[:next_cursor])
      end
    end
    assert_raises(ArgumentError) { preview(owner: @client) }
    assert_raises(ArgumentError) { preview(owner: nil) }
    [0, 26, "2", nil, 1.5].each do |bad|
      assert_raises(ArgumentError) { preview(limit: bad) }
    end
    ["bad", 12, [], "x" * 16385, first[:next_cursor].reverse].each do |bad|
      assert_raises(ArgumentError) { preview(cursor: bad) }
    end
    other_family = DomainOutbox::BackfillDryRun.preview(owner: @owner, limit: 2)[:next_cursor]
    travel 3.seconds do
      assert_raises(ArgumentError) { preview(cursor: other_family) }
    end
  end

  test "C2.3b7g detects prior scanned source edits between pages and fails closed" do
    first = preview(limit: 1)
    @source.first.update!(status: "interviewing", goal: "Changed private content in synthetic test")
    # status might have the same value, but updated_at changes on save.
    travel 3.seconds do
      error = assert_raises(ArgumentError) { preview(cursor: first[:next_cursor], limit: 1) }
      assert_match(/source or projection changed/, error.message)
    end
  end

  test "C2.3b7g detects changed outbox or projected activity without scanning private text" do
    first = preview(limit: 1)
    DomainOutboxEvent.where(workspace_id: @workspace.id,
      source_type: "ProjectIntake", source_id: @source.first.id).update_all(source_version: 88)
    travel 3.seconds do
      error = assert_raises(ArgumentError) { preview(cursor: first[:next_cursor], limit: 1) }
      assert_match(/source or projection changed/, error.message)
    end
    clean = preview(limit: 1)
    ActivityEvent.where(workspace_id: @workspace.id,
      event_key: "ProjectIntake:#{@source.first.id}:intake_created").update_all(
        occurred_at: 2.hours.ago
      )
    travel 3.seconds do
      error = assert_raises(ArgumentError) { preview(cursor: clean[:next_cursor], limit: 1) }
      assert_match(/source or projection changed/, error.message)
    end
  end

  test "C2.3b7g continuation lifetime is bounded even if cursors are reissued" do
    step = preview(limit: 1)
    travel 16.minutes do
      assert_raises(ArgumentError) { preview(cursor: step[:next_cursor], limit: 1) }
    end
  end
  test "C2.3b7g maps invitation and transition counters without hiding ineligible sources" do
    valid = @workspace.client_request_invitations.create!(
      token_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      seed_title: "Fictional invitation", seed_project_type: "rails_bugfix",
      seed_goal: "A deliberately synthetic invitation for inspection.",
      service_version_ids: [], client_fact_reviews: {},
      brief_selections: {}, brief_decisions: {},
      expires_at: 48.hours.from_now
    )
    invalid = @workspace.client_request_invitations.create!(
      token_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      seed_title: "Fictional invalid invitation", seed_project_type: "rails_bugfix",
      seed_goal: "Synthetic invalid chronology; no real invited client.",
      service_version_ids: [], client_fact_reviews: {},
      brief_selections: {}, brief_decisions: {},
      expires_at: 48.hours.from_now
    )
    # Corrupt ONLY a disposable CI fixture to exercise the ineligible alias.
    invalid.update_columns(revoked_at: 3.days.ago)
    step = preview(limit: 25)
    3.times do
      travel 3.seconds
      step = preview(limit: 25, cursor: step[:next_cursor])
    end
    assert_equal "ClientRequestInvitation", step[:source_type]
    assert_equal 2, step[:inspected]
    assert_equal 1, step[:page_counts][:already_indexed]
    assert_equal 1, step[:page_counts][:ineligible_sources]
    assert_equal 1, step[:page_counts][:expected_transitions]
    assert_equal 2, step[:report][3][:inspected]
    assert_equal 1, step[:report][3][:ineligible_sources]
    assert_not_includes step.to_json, valid.token_digest
    assert_not_includes step.to_json, invalid.seed_goal
  end

end
