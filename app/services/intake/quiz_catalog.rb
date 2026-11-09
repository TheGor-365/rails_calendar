module Intake
  # Deterministic, offline question catalogue. Never accepts model-generated HTML.
  class QuizCatalog
    OUTCOMES = {
      "website" => { "leads" => "Collect enquiries", "sales" => "Generate sales", "inform" => "Explain an offering" },
      "redesign" => { "clarity" => "Improve clarity", "conversion" => "Increase conversions", "speed" => "Improve usability or speed" },
      "rails_bugfix" => { "restore" => "Restore broken functionality", "stability" => "Improve reliability", "diagnose" => "Diagnose the cause" },
      "api_integration" => { "sync" => "Synchronize data", "automate" => "Automate a workflow", "connect" => "Connect two services" }
    }.freeze

    FEATURES = {
      "website" => { "contact_form" => "Contact form", "catalogue" => "Catalogue", "search" => "Search and filters", "booking" => "Online booking", "accounts" => "User accounts", "payments" => "Payments" },
      "redesign" => { "mobile" => "Mobile layout", "navigation" => "Navigation", "content" => "Content structure", "seo" => "SEO", "accessibility" => "Accessibility", "performance" => "Performance" },
      "rails_bugfix" => { "http_500" => "HTTP 500 errors", "forms" => "Forms and validation", "turbo" => "Turbo / Stimulus", "db" => "Active Record / PostgreSQL", "auth" => "Authentication", "performance" => "Performance" },
      "api_integration" => { "rest" => "REST API", "webhooks" => "Webhooks", "csv" => "CSV import/export", "authentication" => "API authentication", "sync" => "Data synchronization", "logs" => "Monitoring and error logs" }
    }.freeze

    def self.for(project_type)
      return [] unless OUTCOMES.key?(project_type) && FEATURES.key?(project_type)

      [
        { key: "outcome", mode: :single, title: "What is the main desired outcome?", options: OUTCOMES.fetch(project_type) },
        { key: "features", mode: :multi, title: "What should be included or investigated?", options: FEATURES.fetch(project_type) }
      ]
    end

    def self.question(project_type, question_key)
      self.for(project_type).find { |item| item.fetch(:key) == question_key }
    end
  end
end
