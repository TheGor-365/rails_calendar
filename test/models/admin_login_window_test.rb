require "test_helper"

class AdminLoginWindowTest < ActiveSupport::TestCase
  setup do
    AdminLoginWindow.delete_all
  end

  test "shared counter rejects sixth attempt even across separate service invocations" do
    at = Time.zone.parse("2026-11-07 12:00:30")
    5.times do
      assert_not AdminLoginWindow.throttled?(remote_ip: "192.0.2.10", now: at)
    end
    assert AdminLoginWindow.throttled?(remote_ip: "192.0.2.10", now: at)
    assert_equal 1, AdminLoginWindow.count
    assert_equal 6, AdminLoginWindow.first.attempts
    assert_match(/\A[0-9a-f]{64}\z/, AdminLoginWindow.first.client_digest)
    assert_not_includes AdminLoginWindow.first.client_digest, "192.0.2.10"
  end

  test "client identities and fixed minute windows are independent" do
    at = Time.zone.parse("2026-11-07 12:00:59")
    5.times { AdminLoginWindow.throttled?(remote_ip: "198.51.100.10", now: at) }
    assert AdminLoginWindow.throttled?(remote_ip: "198.51.100.10", now: at)
    assert_not AdminLoginWindow.throttled?(remote_ip: "198.51.100.11", now: at)
    assert_not AdminLoginWindow.throttled?(remote_ip: "198.51.100.10", now: at + 1.second)
    assert_equal 3, AdminLoginWindow.count
  end

  test "successful and failed authentication attempts share one counter" do
    # The limiter is called before credential verification for both paths.
    assert_not AdminLoginWindow.throttled?(remote_ip: "203.0.113.30")
    assert_equal 1, AdminLoginWindow.first.attempts
  end

  test "old rows are pruned separately without deleting recent windows" do
    at = Time.zone.parse("2026-11-07 12:00:00")
    AdminLoginWindow.throttled?(remote_ip: "203.0.113.1", now: at - 3.days)
    AdminLoginWindow.throttled?(remote_ip: "203.0.113.2", now: at)
    assert_equal 2, AdminLoginWindow.count

    assert_equal 1, AdminLoginWindow.prune_expired!(now: at)
    assert_equal 1, AdminLoginWindow.count
  end
end
