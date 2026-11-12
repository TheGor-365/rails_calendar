require "digest"
require "json"

module Studio
  # Stable content identity, never a substitute for human approval.
  class ProjectScopeFingerprint
    def self.call(document)
      raise ArgumentError, "Structured specification required" unless document.is_a?(Hash)

      Digest::SHA256.hexdigest(JSON.generate(canonical(document)))
    end

    def self.canonical(value)
      case value
      when Hash
        value.keys.sort_by(&:to_s).to_h { |key| [key.to_s, canonical(value.fetch(key))] }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end

    private_class_method :canonical
  end
end
