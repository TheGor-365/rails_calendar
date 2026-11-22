require "test_helper"
require_relative "../support/owner_service_catalogue_test_data"

# Test-only controller. It is NOT under app/controllers, and no production
# route invokes it. Its POST intentionally never calls SupervisedReplay.
class TestOnlyOwnerOutboxReplayCsrfPreflightController < ApplicationController
  protect_from_forgery with: :exception

  def form_token
    return head(:not_found) unless owner_signed_in?

    response.headers["Cache-Control"] = "private, no-store"
    render plain: form_authenticity_token
  end

  def validate_intent
    return head(:not_found) unless owner_signed_in?

    DomainOutbox::OperatorConfirmation.validate!(
      owner: current_user,
      limit: params[:limit],
      confirmation: params[:confirmation]
    )
    head :no_content
  rescue ArgumentError
    head :unprocessable_entity
  end
end

# C2.3b6b2.4b PREP. Exercises real Rails CSRF verification with an isolated
# test-only route set, synthetic users and no outbox/journal writes.
# This does NOT enable POST /workspace/outbox/replay or real delivery.
class OwnerOutboxReplayCsrfPreflightTest < ActionController::TestCase
  tests TestOnlyOwnerOutboxReplayCsrfPreflightController
  include OwnerServiceCatalogueTestData

  setup do
    @prior_csrf = TestOnlyOwnerOutboxReplayCsrfPreflightController.allow_forgery_protection
    TestOnlyOwnerOutboxReplayCsrfPreflightController.allow_forgery_protection = true

    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/__test_only__/outbox/intent", to: "test_only_owner_outbox_replay_csrf_preflight#form_token"
      post "/__test_only__/outbox/intent", to: "test_only_owner_outbox_replay_csrf_preflight#validate_intent"
    end

    @owner = make_test_owner("csrf-outbox-owner-#{SecureRandom.hex(6)}@example.test")
    @client = make_test_client("csrf-outbox-client-#{SecureRandom.hex(6)}@example.test")
    @other_owner = make_test_owner("csrf-outbox-other-#{SecureRandom.hex(6)}@example.test")
    @workspace, = approved_profile_for(@owner)
    @other_workspace, = approved_profile_for(@other_owner)
  end

  teardown do
    TestOnlyOwnerOutboxReplayCsrfPreflightController.allow_forgery_protection = @prior_csrf
  end

  def login_as(user)
    session.clear
    raw = SecureRandom.hex(32)
    user.user_sessions.create!(
      token_digest: Digest::SHA256.hexdigest(raw),
      expires_at: 30.minutes.from_now
    )
    session[:owner_session_token] = raw
  end

  def fresh_csrf_token
    get :form_token
    assert_response :success
    assert_match(/\A[A-Za-z0-9+\/=_-]+\z/, response.body)
    response.body
  end

  def intent_post(csrf: nil, limit: "5", confirmation: "REPLAY 5")
    params = { limit: limit, confirmation: confirmation }
    params[:authenticity_token] = csrf unless csrf.nil?
    post :validate_intent, params: params
  end

  test "C2.3b6b2.4b synthetic owner POST requires a valid real CSRF token and makes zero writes" do
    assert TestOnlyOwnerOutboxReplayCsrfPreflightController.allow_forgery_protection
    login_as(@owner)
    token = fresh_csrf_token

    assert_no_difference([
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      intent_post(csrf: token)
      assert_response :no_content

      assert_raises(ActionController::InvalidAuthenticityToken) do
        intent_post
      end
      assert_raises(ActionController::InvalidAuthenticityToken) do
        intent_post(csrf: "not-a-csrf-token")
      end
    end
  end

  test "C2.3b6b2.4b invalid owner confirmation and limit never invoke replay" do
    login_as(@owner)
    token = fresh_csrf_token
    assert_no_difference([
      "OwnerOutboxReplayRun.count", "DomainOutboxEvent.count",
      "ActivityEvent.count", "AiSpendEntry.count"
    ]) do
      [["0", "REPLAY 0"], ["05", "REPLAY 05"], ["100", "REPLAY 100"],
       ["5", "replay 5"], ["5", "REPLAY 25"]].each do |limit, phrase|
        intent_post(csrf: token, limit: limit, confirmation: phrase)
        assert_response :unprocessable_entity
      end
    end
  end

  test "C2.3b6b2.4b client and guest cannot validate owner replay even with correct CSRF" do
    login_as(@client)
    token = get(:form_token)
    assert_response :not_found
    assert_raises(ActionController::InvalidAuthenticityToken) do
      intent_post
    end

    # A client may have a valid CSRF token for its own session, but that
    # token is NOT owner authorization. Explicitly create one for this test.
    csrf = @controller.send(:form_authenticity_token)
    intent_post(csrf: csrf)
    assert_response :not_found

    session.clear
    intent_post(csrf: csrf)
    assert_response :not_found
  end

  test "C2.3b6b2.4b actual application route is still absent" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/workspace/outbox/replay", method: :post)
    end
  end
end
