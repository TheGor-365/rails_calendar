require "test_helper"
require "open3"
require "rbconfig"
require "json"

class Rc037LocalAcceptanceGuardTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/rc037-local-acceptance").to_s
  LOCAL = "postgresql://postgres:postgres@127.0.0.1:5432/ruby_calendar_test"

  test "safe local disposable test DB can run guard only without DB mutation" do
    stdout, stderr, status = run_guard(
      "RC_LOCAL_TEST_DATABASE_URL" => LOCAL,
      "PGHOST" => "127.0.0.1", "DATABASE_URL" => nil,
      "RAILS_ENV" => "test", "RACK_ENV" => "test"
    )
    assert status.success?, stderr
    assert_equal "READY", JSON.parse(stdout).fetch("status")
    assert_equal false, JSON.parse(stdout).fetch("production_ready")
  end

  test "remote URLs, production flags and missing test DB always refuse" do
    [
      { "RC_LOCAL_TEST_DATABASE_URL" => "postgresql://user:pass@db.remote.example/ruby_calendar_test" },
      { "RC_LOCAL_TEST_DATABASE_URL" => "postgresql://user:pass@127.0.0.1/rails_calendar_production" },
      { "DATABASE_URL" => "postgresql://user:pass@127.0.0.1/rails_calendar_production" },
      { "RAILS_ENV" => "production" },
      { "RACK_ENV" => "production" },
      { "PGHOST" => "db.remote.example" },
      { "RC_LOCAL_TEST_DATABASE_URL" => nil }
    ].each do |changed|
      stdout, _stderr, status = run_guard({
        "RC_LOCAL_TEST_DATABASE_URL" => LOCAL,
        "PGHOST" => "127.0.0.1", "DATABASE_URL" => nil,
        "RAILS_ENV" => "test", "RACK_ENV" => "test"
      }.merge(changed))
      refute status.success?, "Expected refusal for #{changed.keys}"
      assert_equal "REFUSED", JSON.parse(stdout).fetch("status")
    end
  end

  private

  def run_guard(env)
    Open3.capture3(env, RbConfig.ruby, SCRIPT, "--check-only")
  end
end
