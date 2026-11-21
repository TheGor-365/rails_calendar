require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerOutboxHealthControllerTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    @owner = make_test_owner("outbox-ui-owner-#{SecureRandom.hex(6)}@example.test")
    @other = make_test_owner("outbox-ui-other-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("outbox-ui-client-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other)
    @secret = "fictional-scope-answer-must-never-appear"
    @own_event = DomainOutboxEvent.create!(
      workspace: @workspace, source_type: "ProjectIntake", source_id: 8_712_347,
      source_version: 1, kind: "intake_created", state: "pending",
      occurred_at: Time.current - 3.minutes, attempts: 0
    )
    @foreign_event = DomainOutboxEvent.create!(
      workspace: @other_workspace, source_type: "ProjectIntake", source_id: 9_997_771,
      source_version: 1, kind: "intake_created", state: "failed",
      occurred_at: Time.current - 1.hour, attempts: 4
    )
  end

  def login(user)
    post account_session_path, params: {
      email: user.email, password: OwnerServiceCatalogueTestData::PASSWORD
    }
    assert_redirected_to(user.role == "owner" ? workspace_path : client_home_path)
  end

  def logout
    delete sign_out_path
    assert_redirected_to root_path
  end

  test "C2.3b6b owner sees only private safe queue metrics with read-only GET" do
    login(@owner)
    assert_no_difference(["DomainOutboxEvent.count", "ActivityEvent.count", "AiSpendEntry.count"]) do
      get owner_outbox_health_path
      assert_response :success
      assert_equal "no-store", response.headers["Cache-Control"].split(",").last.strip
      assert_equal "nosniff", response.headers["X-Content-Type-Options"]
      assert_select "[data-outbox-health]", count: 1
      assert_select "[data-outbox-metric='total']", text: /1/
      assert_select "[data-outbox-metric='pending']", text: /1/
      assert_select "[data-outbox-metric='failed']", text: /0/
      assert_select "table[data-outbox-candidates] tbody tr", count: 1
      assert_select "form[action=?][method='get']", owner_outbox_health_path
      assert_select "form[action*='replay']", count: 0
      assert_select "[data-outbox-health] form[method='post']", count: 0
      assert_no_match(/#{@own_event.source_id}|#{@foreign_event.source_id}|#{@secret}/, response.body)

      get owner_outbox_health_path(limit: "10")
      assert_response :success
      assert_select "table[data-outbox-candidates] tbody tr", count: 1

      get owner_activity_events_path
      assert_response :success
      assert_select "a[href=?]", owner_outbox_health_path, minimum: 1
    end
  end

  test "C2.3b6b malformed limits fail closed and cannot access foreign queue" do
    login(@owner)
    [ "10000", "0", "-1", "oops" ].each do |bad|
      get owner_outbox_health_path(limit: bad)
      assert_response :success
      assert_select "select[name='limit'] option[selected='selected'][value='25']", count: 1
      assert_select "table[data-outbox-candidates] tbody tr", count: 1
    end
    assert_no_match(/#{@foreign_event.source_id}/, response.body)
    logout

    login(@other)
    get owner_outbox_health_path
    assert_response :success
    assert_select "[data-outbox-metric='total']", text: /1/
    assert_select "[data-outbox-metric='failed']", text: /1/
    assert_select "[data-outbox-metric='pending']", text: /0/
    assert_no_match(/#{@own_event.source_id}/, response.body)
  end

  test "C2.3b6b client and anonymous never see owner queue" do
    get owner_outbox_health_path
    assert_response :not_found
    login(@client)
    get owner_outbox_health_path
    assert_response :not_found
    assert_select "[data-outbox-health]", count: 0
  end

  test "C2.3b6b newly registered owner without workspace is denied" do
    empty_owner = make_test_owner("outbox-no-workspace-#{SecureRandom.hex(6)}@example.test")
    assert_nil empty_owner.owner_workspace
    login(empty_owner)
    get owner_outbox_health_path
    assert_response :not_found
  end
end
