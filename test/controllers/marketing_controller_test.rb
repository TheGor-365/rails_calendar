require "test_helper"
require "minitest/mock"
require_relative "../support/owner_service_catalogue_test_data"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  include OwnerServiceCatalogueTestData

  setup do
    owner = make_test_owner("marketing-catalogue@example.test")
    workspace, _, _, caps = approved_profile_for(owner)
    catalogue = OwnerServices::Catalogue.new(workspace: workspace)
    @offer = catalogue.create_draft!(service_fields(caps.first, title: "Published fictional service"))
    draft = @offer.draft_version
    catalogue.approve!(offering: @offer, version: draft.version, digest: draft.digest, confirmed: true)
    approved = @offer.reload.approved_version
    catalogue.publish!(offering: @offer, version_id: approved.id, digest: approved.digest, confirmed: true, owner: owner)
    catalogue.create_draft!(service_fields(caps.first, title: "PRIVATE DRAFT NEVER PUBLIC"))
  end
  test "services is public and shows only published offers" do
    get services_url

    assert_response :success
    assert_select "html[lang='en']", count: 1
    assert_select "body.marketing-page", count: 1
    assert_select "h1", text: /Web tasks/
    assert_select "section#services article.marketing-service", count: 1
    assert_includes response.body, "Published fictional service"
    refute_includes response.body, "PRIVATE DRAFT NEVER PUBLIC"
    assert_select ".mk-board-lane", count: 3
    assert_select ".mk-workflow-disclaimer", count: 0
    assert_select "dialog#process", count: 1
    assert_select "[data-mk-open=process]", minimum: 1
    assert_select ".mk-service-tech", count: 1
    assert_select ".mk-tech-list li", text: "Rails", count: 1
    assert_select ".mk-tech-list li", text: "React", count: 0
    refute_includes response.body, "Fictional self-report"
    refute_includes response.body, "Synthetic policy"
    assert_select "a.mk-service-card", count: 0
    assert_select "article.marketing-service > a[href='#contact']", count: 1
    assert_select "a[href='/sign_in']", minimum: 1
    assert_select "a[href='https://www.facebook.com/gor.webdevelopment/']", minimum: 1
    assert_select "a[href='https://kwork.com/user/thegor-365']", minimum: 1
    assert_select "meta[name='robots'][content='index,follow']", count: 1
    assert_select "link[rel='stylesheet'][href='/marketing.css']", count: 1
    assert_select "form:not([action='/language'])", count: 0
    assert_select "a[href*='project_intakes']", count: 0
  end

  test "anonymous production root renders public offers instead of consultation data" do
    secret_title = consultations(:one).title
    Rails.env.stub(:production?, true) do
      get root_url
    end

    assert_response :success
    assert_select "body.marketing-page", count: 1
    assert_select "section#services article.marketing-service", count: 1
    assert_no_match Regexp.new(Regexp.escape(secret_title)), response.body
    assert_select "a[href*='/consultations/']", count: 0
    assert_select "a[href*='/calendar/day']", count: 0
  end

  test "private calendar day still redirects anonymous production visitors to admin login" do
    Rails.env.stub(:production?, true) do
      get calendar_day_url(date: "2026-11-12")
    end

    assert_redirected_to admin_login_url
  end

  test "public services never write intake records" do
    assert_no_difference "ProjectIntake.count" do
      get services_url
    end
    assert_response :success
  end
end
