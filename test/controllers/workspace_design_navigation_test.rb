require "test_helper"

class WorkspaceDesignNavigationTest < ActionDispatch::IntegrationTest
  test "local calendar overview displays real record metrics and links to public services" do
    get root_url
    assert_response :success

    assert_select "section.ws-overview article.ws-metric", count: 3
    assert_select "a.ws-header-services[href='/services']", count: 1
    assert_select "span.ws-brand-name", text: /Rails Calendar/
  end

  test "public workspace overview has a real contact link without in-app intake" do
    get services_url
    assert_response :success
    assert_select "header.mk-header"
    assert_select "nav.mk-sidebar-nav a[href='#services']", count: 1
    assert_select "section#contact a[href='https://www.facebook.com/gor.webdevelopment/']", count: 1
    assert_select "section#contact a[href='https://kwork.com/user/thegor-365']", count: 1
    assert_select "form:not([action='/language'])", count: 0
  end
end
