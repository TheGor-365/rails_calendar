require "test_helper"

class StudioLocalS3LoopbackGateTest < ActiveSupport::TestCase
  setup do
    @keys = %w[RC_STUDIO_SYNTHETIC_STORAGE RC_STUDIO_LOCAL_S3_HTTP
      RC_STUDIO_QUARANTINE_BACKEND RC_STUDIO_S3_PURPOSE RC_STUDIO_S3_ENDPOINT
      RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION RC_STUDIO_S3_ACCESS_KEY_ID
      RC_STUDIO_S3_SECRET_ACCESS_KEY]
    @saved = @keys.to_h { |key| [key, ENV[key]] }
    ENV.update(
      "RC_STUDIO_SYNTHETIC_STORAGE" => "true",
      "RC_STUDIO_QUARANTINE_BACKEND" => "s3",
      "RC_STUDIO_S3_PURPOSE" => "nonproduction-synthetic",
      "RC_STUDIO_S3_ENDPOINT" => "http://127.0.0.1:9000",
      "RC_STUDIO_S3_BUCKET" => "rc036-local-demo-test",
      "RC_STUDIO_S3_REGION" => "us-east-1",
      "RC_STUDIO_S3_ACCESS_KEY_ID" => "synthetic",
      "RC_STUDIO_S3_SECRET_ACCESS_KEY" => "synthetic"
    )
    ENV.delete("RC_STUDIO_LOCAL_S3_HTTP")
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "development loopback HTTP is opt-in and public HTTP remains forbidden" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      assert_raises(Studio::PrivateSourceStorage::Unavailable) do
        Studio::PrivateSourceStorage.new(service: Object.new)
      end
      ENV["RC_STUDIO_LOCAL_S3_HTTP"] = "true"
      assert_instance_of Studio::PrivateSourceStorage,
        Studio::PrivateSourceStorage.new(service: Object.new)
      ENV["RC_STUDIO_S3_ENDPOINT"] = "http://public.example.test:9000"
      assert_raises(Studio::PrivateSourceStorage::Unavailable) do
        Studio::PrivateSourceStorage.new(service: Object.new)
      end
    end
  end

  test "production remains disabled even with all local-demo flags" do
    ENV["RC_STUDIO_LOCAL_S3_HTTP"] = "true"
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(Studio::PrivateSourceStorage::Unavailable) do
        Studio::PrivateSourceStorage.new(service: Object.new)
      end
    end
  end
end
