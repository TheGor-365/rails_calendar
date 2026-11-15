require "test_helper"

class RcLocalSessionPolicyTest < ActiveSupport::TestCase
  test "opt-in is allowed only in development and uses a fixed 14-day lifetime" do
    assert RcLocalSessionPolicy.enabled?(environment: "development", flag: "true")
    assert_equal 14.days, RcLocalSessionPolicy.session_lifetime(environment: "development", flag: "true")

    %w[test production staging].each do |environment|
      refute RcLocalSessionPolicy.enabled?(environment: environment, flag: "true")
      assert_equal 8.hours, RcLocalSessionPolicy.session_lifetime(environment: environment, flag: "true")
    end
  end

  test "missing, false, or malformed flags never extend sessions" do
    [nil, "", "false", "1", "TRUE", "yes", " true"].each do |flag|
      refute RcLocalSessionPolicy.enabled?(environment: "development", flag: flag)
      assert_equal 8.hours, RcLocalSessionPolicy.session_lifetime(environment: "development", flag: flag)
    end
  end

  test "real Rails test environment cannot accidentally extend session lifetime" do
    assert_equal "test", Rails.env
    assert_equal 8.hours, RcLocalSessionPolicy.session_lifetime
  end
end
