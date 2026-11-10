# Tests the one-time production bootstrap against an isolated TEST database only.
# No Railway connection, no production credentials, and no real production changes.
require "test_helper"
require "rake"
require "minitest/mock"

class Rc035OwnerBootstrapTest < ActiveSupport::TestCase
  setup do
    raise "RC035_TEST_DB_ONLY" unless Rails.env.test?

    Rails.application.load_tasks unless Rake::Task.task_defined?("rc_owner:bootstrap")
    @task = Rake::Task["rc_owner:bootstrap"]
    @task.reenable

    @previous_email = ENV["RC_OWNER_BOOTSTRAP_EMAIL"]
    @previous_password = ENV["RC_OWNER_BOOTSTRAP_PASSWORD"]
    ENV["RC_OWNER_BOOTSTRAP_EMAIL"] = "OWNER@EXAMPLE.TEST"
    ENV["RC_OWNER_BOOTSTRAP_PASSWORD"] = "fictional-rc035-test-password"

    UserSession.delete_all
    User.delete_all
  end

  teardown do
    restore_env("RC_OWNER_BOOTSTRAP_EMAIL", @previous_email)
    restore_env("RC_OWNER_BOOTSTRAP_PASSWORD", @previous_password)
    @task&.reenable
  end

  test "refuses to execute when Rails environment is not production" do
    stdout, stderr = capture_io do
      error = assert_raises(SystemExit) { @task.invoke }
      assert_not_equal 0, error.status
    end

    assert_empty stdout
    assert_includes stderr, "RC_OWNER_BOOTSTRAP_WRONG_ENV"
    assert_equal 0, User.count
  end

  test "creates exactly one owner only under explicitly simulated production guard" do
    output = nil

    assert_difference "User.count", 1 do
      output, = capture_io do
        # Rails runs in TEST with an isolated test DB throughout. Only the
        # boolean production guard is simulated for this unit test.
        Rails.env.stub(:production?, true) { @task.invoke }
      end
    end

    owner = User.sole
    assert_equal "owner@example.test", owner.email
    assert_equal "owner", owner.role
    assert owner.authenticate("fictional-rc035-test-password")
    assert_equal "RC_OWNER_BOOTSTRAP_CREATED\n", output
    assert_not_includes output, "fictional-rc035-test-password"
  end

  test "rejects a second bootstrap without modifying the owner" do
    Rails.env.stub(:production?, true) { capture_io { @task.invoke } }
    @task.reenable

    assert_no_difference "User.count" do
      stdout, stderr = capture_io do
        Rails.env.stub(:production?, true) do
          error = assert_raises(SystemExit) { @task.invoke }
          assert_not_equal 0, error.status
        end
      end
      assert_empty stdout
      assert_includes stderr, "RC_OWNER_BOOTSTRAP_USERS_ALREADY_EXIST"
    end
  end

  test "invalid email is rejected without writing a user" do
    ENV["RC_OWNER_BOOTSTRAP_EMAIL"] = "not-an-email"

    assert_no_difference "User.count" do
      stdout, stderr = capture_io do
        Rails.env.stub(:production?, true) do
          assert_raises(SystemExit) { @task.invoke }
        end
      end
      assert_empty stdout
      assert_includes stderr, "RC_OWNER_BOOTSTRAP_INVALID_EMAIL"
    end
  end

  test "too-short password is rejected without writing a user" do
    ENV["RC_OWNER_BOOTSTRAP_PASSWORD"] = "short"

    assert_no_difference "User.count" do
      stdout, stderr = capture_io do
        Rails.env.stub(:production?, true) do
          assert_raises(SystemExit) { @task.invoke }
        end
      end
      assert_empty stdout
      assert_includes stderr, "RC_OWNER_BOOTSTRAP_INVALID_PASSWORD_LENGTH"
    end
  end

  private

  def restore_env(key, original)
    original.nil? ? ENV.delete(key) : ENV[key] = original
  end
end
