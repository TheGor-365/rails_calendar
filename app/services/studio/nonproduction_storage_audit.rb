require "aws-sdk-s3"

module Studio
  # Read-only capability probe for a dedicated synthetic nonproduction bucket.
  # No Put/Delete/ACL/POLICY mutations. A green storage probe is NOT a client
  # launch authorization or a substitute for encryption/key/consent review.
  class NonproductionStorageAudit
    REQUIRED = %w[head_bucket private_access policy_not_public server_encryption quarantine_lifecycle].freeze
    Result = Struct.new(:checks, keyword_init: true) do
      def storage_checks_passed?
        checks.values.all?(true) && checks.keys.sort == NonproductionStorageAudit::REQUIRED.sort
      end
    end

    def initialize(client: nil)
      @client = client
    end

    def call
      checks = REQUIRED.index_with { false }
      return Result.new(checks: checks) unless PrivateSourceStorage.enabled? &&
                                                  PrivateSourceStorage.s3_backend?

      # Validate strict synthetic environment/purpose, bucket name and HTTPS
      # before any network; service injection avoids loading stale config.
      PrivateSourceStorage.new(service: Object.new)
      bucket = ENV.fetch("RC_STUDIO_S3_BUCKET")
      client = @client || build_client

      checks["head_bucket"] = check { !!client.head_bucket(bucket: bucket) }
      checks["private_access"] = check do
        config = client.get_public_access_block(bucket: bucket).public_access_block_configuration
        config.block_public_acls == true && config.ignore_public_acls == true &&
          config.block_public_policy == true && config.restrict_public_buckets == true
      end
      checks["policy_not_public"] = check do
        client.get_bucket_policy_status(bucket: bucket).policy_status.is_public == false
      end
      checks["server_encryption"] = check do
        rules = client.get_bucket_encryption(bucket: bucket)
                      .server_side_encryption_configuration.rules
        rules.any? do |rule|
          %w[AES256 aws:kms].include?(rule.apply_server_side_encryption_by_default&.sse_algorithm)
        end
      end
      checks["quarantine_lifecycle"] = check do
        client.get_bucket_lifecycle_configuration(bucket: bucket).rules.any? do |rule|
          prefix = rule.filter&.prefix || rule.prefix
          rule.status == "Enabled" && prefix == "q/" &&
            rule.expiration&.days.to_i.between?(1, 8)
        end
      end
      Result.new(checks: checks)
    rescue PrivateSourceStorage::Unavailable, ArgumentError, KeyError, URI::InvalidURIError
      Result.new(checks: checks)
    end

    private

    def build_client
      Aws::S3::Client.new(
        endpoint: ENV.fetch("RC_STUDIO_S3_ENDPOINT"),
        region: ENV.fetch("RC_STUDIO_S3_REGION"),
        access_key_id: ENV.fetch("RC_STUDIO_S3_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("RC_STUDIO_S3_SECRET_ACCESS_KEY"),
        force_path_style: true, retry_limit: 0,
        http_open_timeout: 5, http_read_timeout: 8
      )
    end

    def check
      yield == true
    rescue StandardError
      false
    end
  end
end
