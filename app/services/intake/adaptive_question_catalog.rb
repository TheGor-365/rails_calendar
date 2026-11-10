module Intake
  # RC-035B (stage 1): deterministic catalog only. It is not wired to the
  # existing two-question quiz or any public/client submission endpoint.
  # The selected ProjectIntake#project_type represents section A; section H
  # remains an owner-only draft review until the ACL/privacy gate is complete.
  class AdaptiveQuestionCatalog
    VERSION = "rc035b.v1".freeze
    SECTION_ORDER = %w[B C D E F G].freeze

    COMMON = [
      {
        key: "business_goals", section: "B", mode: :multi,
        title: "What should this work achieve?",
        options: {
          "leads" => "More enquiries", "sales" => "More sales",
          "automation" => "Less manual work", "reliability" => "Better reliability",
          "usability" => "Easier user experience", "other" => "Another business goal"
        }
      },
      {
        key: "audiences", section: "C", mode: :multi,
        title: "Who will use or benefit from it?",
        options: {
          "visitors" => "Visitors", "customers" => "Customers",
          "staff" => "Employees", "admins" => "Administrators",
          "partners" => "Partners", "unknown" => "Not decided yet"
        }
      },
      {
        key: "scope", section: "D", mode: :multi,
        title: "Which parts of the work matter most?",
        options: {
          "frontend" => "User-facing interface", "backend" => "Backend logic",
          "data" => "Data and database", "security" => "Permissions or security",
          "tests" => "Testing and validation", "unknown" => "Need advice"
        }
      },
      {
        key: "integrations", section: "F", mode: :multi,
        title: "Which systems need to connect?",
        options: {
          "none" => "No external services", "email" => "Email provider",
          "crm" => "CRM", "api" => "Third-party API",
          "payments" => "Payment provider", "unknown" => "Need advice"
        }
      },
      {
        key: "constraints", section: "G", mode: :single,
        title: "What is the main delivery constraint?",
        options: {
          "deadline" => "Preferred target date", "budget" => "Budget range",
          "legacy" => "Existing system limitations", "flexible" => "Flexible / need an estimate"
        }
      }
    ].freeze

    BRANCHES = {
      "website" => [
        {
          key: "website_pages", section: "D", mode: :multi,
          title: "Which website pages or features are needed?",
          options: {
            "landing" => "Landing page", "services" => "Services and contact",
            "catalogue" => "Catalogue or store", "booking" => "Appointments",
            "blog" => "Blog or articles", "search" => "Search and filters"
          }
        },
        {
          key: "website_checkout", section: "D", mode: :multi,
          title: "What must the catalogue support?",
          options: {
            "product_list" => "Products and categories", "cart" => "Shopping cart",
            "checkout" => "Checkout", "delivery" => "Delivery methods"
          },
          requires: { "website_pages" => %w[catalogue] }
        },
        {
          key: "website_materials", section: "E", mode: :multi,
          title: "Which design and content materials already exist?",
          options: {
            "logo" => "Logo or brand guide", "copy" => "Text content",
            "images" => "Images", "references" => "Design references",
            "unknown" => "Not sure yet"
          }
        }
      ],
      "redesign" => [
        {
          key: "redesign_problems", section: "D", mode: :multi,
          title: "What is not working on the current site?",
          options: {
            "mobile" => "Mobile layout", "navigation" => "Navigation",
            "performance" => "Performance", "accessibility" => "Accessibility",
            "conversion" => "Conversion flow", "content" => "Content structure"
          }
        },
        {
          key: "redesign_preserve", section: "E", mode: :multi,
          title: "What must the redesign preserve?",
          options: {
            "urls" => "Existing URLs and SEO", "brand" => "Brand identity",
            "content" => "Existing content", "data" => "User or business data",
            "unknown" => "Need investigation"
          }
        }
      ],
      "rails_bugfix" => [
        {
          key: "bug_symptoms", section: "D", mode: :multi,
          title: "What is failing in the Rails application?",
          options: {
            "http500" => "HTTP 500 or crashes", "forms" => "Forms/validation",
            "hotwire" => "Turbo/Stimulus", "postgres" => "Active Record/PostgreSQL",
            "auth" => "Authentication", "slow" => "Slow response"
          }
        },
        {
          key: "bug_repro", section: "D", mode: :single,
          title: "Can you reproduce the failure?",
          options: {
            "always" => "Yes, consistently", "intermittent" => "Only sometimes",
            "unknown" => "Not yet"
          }
        },
        {
          key: "bug_environment", section: "G", mode: :multi,
          title: "Where does the failure happen?",
          options: {
            "development" => "Development", "test" => "Test/CI",
            "production" => "Production", "unknown" => "Not sure"
          }
        }
      ],
      "api_integration" => [
        {
          key: "api_direction", section: "D", mode: :single,
          title: "Which direction should the data move?",
          options: {
            "inbound" => "Import into our app", "outbound" => "Send from our app",
            "two_way" => "Both directions", "unknown" => "Need investigation"
          }
        },
        {
          key: "api_mechanism", section: "F", mode: :multi,
          title: "Which integration mechanisms are involved?",
          options: {
            "rest" => "REST API", "webhook" => "Webhooks",
            "csv" => "CSV/files", "oauth" => "OAuth authorization",
            "unknown" => "Not sure"
          }
        },
        {
          key: "api_webhook_recovery", section: "F", mode: :multi,
          title: "What should happen if a webhook fails?",
          options: {
            "retry" => "Retry delivery", "log" => "Record failure",
            "alert" => "Notify an administrator", "unknown" => "Need advice"
          },
          requires: { "api_mechanism" => %w[webhook] }
        }
      ]
    }.freeze

    def self.for(project_type, answers: {})
      type = project_type.to_s
      return [] unless BRANCHES.key?(type) || type == "unknown"

      candidates = COMMON + BRANCHES.fetch(type, [])
      candidates.sort_by { |entry| SECTION_ORDER.index(entry.fetch(:section)) }
                .select { |entry| BranchingEngine.visible?(entry, answers) }
                .map do |entry|
                  entry.merge(
                    options: entry.fetch(:options).dup,
                    requires: entry.fetch(:requires, {}).transform_values(&:dup)
                  )
                end
    end

    def self.question(project_type, question_key, answers: {})
      self.for(project_type, answers: answers).find { |entry| entry.fetch(:key) == question_key }
    end
  end
end
