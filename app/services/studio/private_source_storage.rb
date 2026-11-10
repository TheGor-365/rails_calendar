require "stringio"

module Studio
  # Synthetic test/dev storage only. Never use the Railway web filesystem
  # or a public ActiveStorage route as real client object storage.
  class PrivateSourceStorage
    class Unavailable < StandardError; end
    class MissingObject < StandardError; end

    def self.enabled?
      Rails.env.test? || (Rails.env.development? && ENV["RC_STUDIO_SYNTHETIC_STORAGE"] == "true")
    end

    def initialize(service: nil)
      raise Unavailable, "Private source storage is not provisioned" unless self.class.enabled?

      @service = service || ActiveStorage::Service.configure(
        :studio_synthetic_quarantine,
        Rails.application.config.active_storage.service_configurations
      )
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

    private

    def validate_key!(key)
      raise Unavailable, "Invalid private object key" unless key.to_s.match?(/\Aq\/[0-9a-f]{64}\z/)
    end
  end
end
