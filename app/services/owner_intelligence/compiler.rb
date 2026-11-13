require "json"
require "digest"

module OwnerIntelligence
  # Owner-confirmed declarations only. The AI summary cannot inject skills or
  # override the explicit no-go policy. No capability is marked independently verified.
  class Compiler
    def self.build(profile:, headline:, private_summary:, public_summary:)
      answers = profile.owner_interview_answers.index_by(&:section_key)
      raise ArgumentError, "Incomplete owner interview" unless
        (Catalog::KEYS - answers.keys).empty?

      options = ->(key) { answers.fetch(key).selected_options - ["other"] }
      direct = options.call("B")
      assisted = options.call("C") - direct
      capabilities = direct.map do |domain|
        { "domain" => domain, "delivery_mode" => "direct",
          "experience_claim" => "practiced", "evidence_status" => "self_reported",
          "willingness" => "actively_offer", "privacy_scope" => "private",
          "review_required" => true, "conditions" => "Owner self-report; verify relevance before quoting" }
      end
      capabilities.concat(assisted.map do |domain|
        { "domain" => domain, "delivery_mode" => "ai_assisted",
          "experience_claim" => "new_to_me", "evidence_status" => "unverified",
          "willingness" => "consider", "privacy_scope" => "private",
          "review_required" => true, "conditions" => "Assess complexity, available AI tools and QA before agreeing" }
      end)

      {
        "schema_version" => Catalog::VERSION,
        "headline" => headline, "private_summary" => private_summary,
        "public_summary_draft" => public_summary,
        "desired_services" => options.call("A"),
        "capabilities" => capabilities,
        "hard_no_go" => options.call("D"),
        "work_preferences" => options.call("E"),
        "evidence_claims_unverified" => options.call("F"),
        "interview_answers" => Catalog::KEYS.to_h { |key| [key, answers.fetch(key).snapshot] },
        "source" => "owner_confirmed"
      }
    end
  end
end
