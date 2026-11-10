require "yaml"

module Intake
  module Intelligence
    # Public, reviewable capability taxonomy. No customer/owner identity or secrets.
    class MasterProfile
      PATH = Rails.root.join("config/ai_workspace/master_profile.yml").freeze
      VERSION = "master.v1".freeze

      def self.load
        profile = YAML.safe_load(File.read(PATH), permitted_classes: [], aliases: false)
        raise ArgumentError, "Unexpected master profile version" unless profile.is_a?(Hash) &&
          profile["schema_version"] == VERSION &&
          profile["services"].is_a?(Hash) &&
          profile["technology"].is_a?(Hash)

        profile
      end

      def self.for(project_type)
        profile = load
        service = profile.fetch("services").fetch(project_type.to_s, nil)
        raise ArgumentError, "Unsupported service type" unless service

        {
          "profile_version" => VERSION,
          "reviewed_on" => profile.fetch("last_reviewed_on"),
          "positioning" => profile.fetch("positioning"),
          "work_style" => profile.fetch("work_style"),
          "technology" => profile.fetch("technology"),
          "service" => service,
          "non_negotiable" => profile.fetch("non_negotiable"),
          "provenance" => "owner_curated_git_config_not_independent_qualification"
        }
      end
    end
  end
end
