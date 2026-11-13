require "digest"
require "json"

module OwnerIntelligence
  class Catalog
    VERSION = "owner_v1".freeze
    KEYS = %w[A B C D E F].freeze

    QUESTIONS = {
      "A" => {
        title: "What work do you want to take?",
        hint: "These are interests, not promises or automatically published services.",
        options: {
          "rails_bugfix" => "Fix Ruby on Rails bugs",
          "rails_crud" => "Rails features / CRUD / admin panels",
          "rails_api" => "Rails API and integrations",
          "rails_tests" => "Tests and reliability",
          "websites" => "Websites and landing pages",
          "automation" => "Business automation",
          "ai_integrations" => "AI-powered features",
          "data_tasks" => "CSV / Excel / data tasks",
          "adjacent_web" => "Adjacent web stacks with AI support",
          "other" => "Other (describe below)"
        }
      },
      "B" => {
        title: "Which technologies have you personally worked with?",
        hint: "Self-report only. We do not label claims independently verified without evidence.",
        options: {
          "ruby" => "Ruby", "rails" => "Ruby on Rails", "postgresql" => "PostgreSQL",
          "html_css" => "HTML / CSS", "bootstrap" => "Bootstrap", "javascript" => "JavaScript",
          "hotwire" => "Turbo / Stimulus", "testing" => "RSpec / Minitest",
          "api" => "REST APIs", "tilda" => "Tilda", "react" => "React",
          "vue" => "Vue", "python" => "Python", "other" => "Other (describe below)"
        }
      },
      "C" => {
        title: "What adjacent work would you consider with AI tools?",
        hint: "AI-assisted does not mean proven expertise. Owner review is required before accepting.",
        options: {
          "react" => "Simple React site", "vue" => "Simple Vue site",
          "nextjs" => "Next.js / modern frontend", "cms" => "CMS-based websites",
          "shopify" => "E-commerce frontends", "ai_agents" => "AI agents / assistants",
          "automation" => "Workflow automation", "mobile" => "Simple mobile prototype",
          "other" => "Other (describe below)"
        }
      },
      "D" => {
        title: "What should the assistant never accept automatically?",
        hint: "Selected items become private hard limits. Any borderline request needs your review.",
        options: {
          "regulated" => "Regulated or safety-critical functionality without a specialist",
          "security" => "High-security work without security review",
          "enterprise" => "Large enterprise systems without assessment",
          "emergency" => "24/7 emergency support",
          "unpaid" => "Full unpaid sample projects",
          "gambling" => "Gambling-related projects",
          "other" => "Another firm exclusion (describe below)"
        }
      },
      "E" => {
        title: "How do you prefer to deliver work?",
        hint: "Preferences are not confirmed prices, timelines or legal/payment availability.",
        options: {
          "micro" => "Small fixed-scope tasks",
          "project" => "Scoped projects after discovery",
          "consulting" => "Paid consultation",
          "remote" => "Remote work",
          "async" => "Asynchronous communication",
          "english_ai" => "English communication with AI assistance",
          "urgent_review" => "Urgent tasks only after review",
          "learn_before_quote" => "Evaluate unfamiliar technology before quoting",
          "other" => "Other (describe below)"
        }
      },
      "F" => {
        title: "What evidence and presentation materials can you provide?",
        hint: "A selected source is NOT verified proof. Add URLs and proof only after review.",
        options: {
          "github" => "GitHub projects",
          "portfolio" => "Personal portfolio",
          "certificates" => "Certificates",
          "commercial" => "Commercial case studies with permission",
          "demo" => "Technical demos and screenshots",
          "references" => "Client references with permission",
          "other" => "Other (describe below)"
        }
      }
    }.freeze

    def self.question(key)
      QUESTIONS[key]
    end

    def self.options_for(key)
      QUESTIONS.dig(key, :options) || {}
    end

    def self.answer_digest(profile)
      answers = profile.owner_interview_answers.order(:section_key).map do |answer|
        [answer.section_key, answer.revision, answer.selected_options, answer.notes.to_s, answer.unsure]
      end
      corrections = profile.professional_capability_corrections.order(:domain).map(&:snapshot_values)
      digest_input = corrections.empty? ? [VERSION, answers] : [VERSION, answers, corrections]
      Digest::SHA256.hexdigest(JSON.generate(digest_input))
    end
  end
end
