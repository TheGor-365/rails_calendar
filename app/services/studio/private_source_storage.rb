require "stringio"
require "uri"

module Studio
  # Isolated quarantine object adapter. Production is HARD DISABLED.
  # Default is ephemeral synthetic disk, with an explicitly opted-in
  # S3-compatible endpoint for test/local development only.
  class PrivateSourceStorage
    class Unavailable < StandardError; end
    class MissingObject < StandardError; end

    CONFIG_KEYS = %w[
      RC_STUDIO_S3_ENDPOINT RC_STUDIO_S3_BUCKET RC_STUDIO_S3_REGION
      RC_STUDIO_S3_ACCESS_KEY_ID RC_STUDIO_S3_SECRET_ACCESS_KEY
    ].freeze
    PURPOSE = "nonproduction-synthetic"

    def self.enabled?
      # Explicit hard deny protects production even if a test-only flag
      # or environment predicate is accidentally overridden.
      !Rails.env.production? &&
        (Rails.env.test? || (Rails.env.development? &&
          ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true"))
    end

    def self.s3_backend?
      ENV["RC_STUDIO_QUARANTINE_BACKEND"] == "s3"
    end

    def initialize(service: nil)
      raise Unavailable, "Private source storage is not provisioned" unless self.class.enabled?

      if self.class.s3_backend?
        verify_s3_configuration!
        name = :studio_nonproduction_s3_quarantine
      else
        unless ENV["RC_STUDIO_QUARANTINE_BACKEND"].blank? || ENV["RC_STUDIO_QUARANTINE_BACKEND"] == "disk"
          raise Unavailable, "Unknown private source storage backend"
        end
        name = :studio_synthetic_quarantine
      end
      # Active Storage reads storage.yml lazily when Blob is first loaded.
      # Direct Service.configure may receive nil on non-eager test boot.
      # Use the framework-managed registry so the initialization hook runs.
      @service = service || ActiveStorage::Blob.services.fetch(name)
    end

    def upload!(key:, bytes:)
      validate_key!(key)
      @service.upload(key, StringIO.new(bytes.to_s.b))
      true
    end

    def read!(key:)
      validate_key!(key)
      @service.download(key)
    rescue ActiveStorage::FileNotFoundError, Errno::ENOENT
      raise MissingObject, "Private object is unavailable"
    end

    def delete!(key:)
      validate_key!(key)
      @service.delete(key)
    end

    # HEAD/existence check only; never downloads bytes for audit purposes.
    # Transport or credential errors propagate (must not masquerade as absent).
    def exists?(key:)
      validate_key!(key)
      @service.exist?(key)
    end

    private

    def verify_s3_configuration!
      unless ENV["RC_STUDIO_S3_PURPOSE"] == PURPOSE &&
             CONFIG_KEYS.all? { |key| ENV[key].present? }
        raise Unavailable, "Dedicated synthetic nonproduction S3 configuration is required"
      end
      bucket = ENV.fetch("RC_STUDIO_S3_BUCKET")
      unless bucket.match?(/\Arc036-[a-z0-9-]{3,55}\z/)
        raise Unavailable, "Quarantine must use an explicitly named rc036- test bucket"
      end

      endpoint = URI.parse(ENV.fetch("RC_STUDIO_S3_ENDPOINT"))
      loopback = %w[localhost 127.0.0.1 ::1].include?(endpoint.host)
      secure = endpoint.scheme == "https"
      local_demo = loopback && Rails.env.development? &&
        ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true" &&
        ENV["RC_STUDIO_LOCAL_S3_HTTP"] == "true"
      unless endpoint.userinfo.nil? && endpoint.query.nil? && endpoint.fragment.nil? &&
             endpoint.host.present? && (secure || (loopback && Rails.env.test?) || local_demo)
        raise Unavailable, "S3 requires HTTPS, except explicit nonproduction loopback"
      end
    rescue URI::InvalidURIError
      raise Unavailable, "Invalid S3 endpoint"
    end

    def validate_key!(key)
      raise Unavailable, "Invalid private object key" unless key.to_s.match?(/\Aq\/[0-9a-f]{64}\z/)
    end
  end
end
