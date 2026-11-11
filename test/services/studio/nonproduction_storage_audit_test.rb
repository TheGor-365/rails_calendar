require "test_helper"

class StudioNonproductionStorageAuditTest < ActiveSupport::TestCase
  Fake = Struct.new(:behavior, keyword_init: true) do
    def head_bucket(bucket:)
      raise "network broken" if behavior == :network_failure
      true
    end

    def get_public_access_block(bucket:)
      flags = Struct.new(:block_public_acls, :ignore_public_acls,
                         :block_public_policy, :restrict_public_buckets)
        .new(true, true, true, behavior != :public_access)
      Struct.new(:public_access_block_configuration).new(flags)
    end

    def get_bucket_policy_status(bucket:)
      status = Struct.new(:is_public).new(behavior == :public_policy)
      Struct.new(:policy_status).new(status)
    end

    def get_bucket_encryption(bucket:)
      config = Struct.new(:sse_algorithm).new(behavior == :missing_encryption ? nil : "AES256")
      rule = Struct.new(:apply_server_side_encryption_by_default).new(config)
      Struct.new(:server_side_encryption_configuration)
        .new(Struct.new(:rules).new([rule]))
    end

    def get_bucket_lifecycle_configuration(bucket:)
      filter = Struct.new(:prefix).new(behavior == :wrong_lifecycle ? "public/" : "q/")
      expiry = Struct.new(:days).new(8)
      rule = Struct.new(:filter, :prefix, :status, :expiration)
        .new(filter, nil, "Enabled", expiry)
      Struct.new(:rules).new([rule])
    end
  end

  setup do
    @original = %w[
      RC_STUDIO_QUARANTINE_BACKEND RC_STUDIO_S3_PURPOSE RC_STUDIO_S3_ENDPOINT
      RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION RC_STUDIO_S3_ACCESS_KEY_ID
      RC_STUDIO_S3_SECRET_ACCESS_KEY
    ].to_h { |key| [key, ENV[key]] }
    ENV["RC_STUDIO_QUARANTINE_BACKEND"] = "s3"
    ENV["RC_STUDIO_S3_PURPOSE"] = "nonproduction-synthetic"
    ENV["RC_STUDIO_S3_ENDPOINT"] = "http://127.0.0.1:9000"
    ENV["RC_STUDIO_S3_BUCKET"] = "rc036-test-audit"
    ENV["RC_STUDIO_S3_REGION"] = "us-east-1"
    ENV["RC_STUDIO_S3_ACCESS_KEY_ID"] = "synthetic"
    ENV["RC_STUDIO_S3_SECRET_ACCESS_KEY"] = "synthetic-test-only"
  end

  teardown do
    @original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "complete read-only capability check passes only for private encrypted scoped lifecycle" do
    result = Studio::NonproductionStorageAudit.new(client: Fake.new).call
    assert result.storage_checks_passed?
    assert_equal 5, result.checks.length
  end

  test "missing provider capabilities and network failures all fail closed" do
    %i[network_failure public_access public_policy missing_encryption wrong_lifecycle].each do |behavior|
      result = Studio::NonproductionStorageAudit.new(client: Fake.new(behavior: behavior)).call
      assert_not result.storage_checks_passed?, behavior.to_s
      assert_includes result.checks.values, false
    end
  end

  test "no production/synthetic purpose and insecure remote endpoint are denied before network" do
    ENV["RC_STUDIO_S3_PURPOSE"] = "production"
    assert_not Studio::NonproductionStorageAudit.new(client: Fake.new).call.storage_checks_passed?
    ENV["RC_STUDIO_S3_PURPOSE"] = "nonproduction-synthetic"
    ENV["RC_STUDIO_S3_ENDPOINT"] = "http://storage.example.net"
    assert_not Studio::NonproductionStorageAudit.new(client: Fake.new).call.storage_checks_passed?
  end

  test "audit never creates buckets or writes objects" do
    client = Object.new
    client.define_singleton_method(:head_bucket) { |bucket:| true }
    result = Studio::NonproductionStorageAudit.new(client: client).call
    assert_not result.storage_checks_passed?
    assert_equal true, result.checks.fetch("head_bucket")
    assert_equal false, result.checks.fetch("private_access")
  end
end
