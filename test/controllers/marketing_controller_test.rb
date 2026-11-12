require "test_helper"
require "minitest/mock"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  test "services is public and shows exactly four concrete offers" do
    get services_url

    assert_response :success
    assert_select "html[lang='ru']", count: 1
    assert_select "body.marketing-page", count: 1
    assert_select "h1", text: /Ruby on Rails/
    assert_select "section#services article.marketing-service", count: 4
    assert_select "a[href='https://www.facebook.com/gor.webdevelopment/']", minimum: 1
    assert_select "a[href='https://kwork.com/user/thegor-365']", minimum: 1
    assert_select "meta[name='robots'][content='index,follow']", count: 1
    assert_select "link[rel='stylesheet'][href='/marketing.css']", count: 1
    assert_select "form", count: 0
    assert_select "a[href*='project_intakes']", count: 0
  end

  test "anonymous production root renders public offers instead of consultation data" do
    secret_title = consultations(:one).title
    Rails.env.stub(:production?, true) do
      get root_url
    end

    assert_response :success
    assert_select "body.marketing-page", count: 1
    assert_select "section#services article.marketing-service", count: 4
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
