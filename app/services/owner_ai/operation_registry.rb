# RC055.1f: explicit, owner-only AI purposes. No model-invented Rails actions.
module OwnerAi
  class OperationRegistry
    OPERATIONS = {
      "service_copy" => {
        instruction: "Draft a concise service description with bounded included and excluded scope. Keep unverified experience conditional.",
        icon: "bi-collection", max_output_tokens: 2200
      },
      "intake_questions" => {
        instruction: "Draft a short adaptive multiple-choice client intake, with useful follow-up questions and a 'not sure' option. No private information requests.",
        icon: "bi-ui-checks-grid", max_output_tokens: 2200
      },
      "client_reply" => {
        instruction: "Draft a polite reply for the OWNER TO REVIEW; request missing facts, do not promise price, deadline or deliverables.",
        icon: "bi-chat-left-text", max_output_tokens: 1800
      },
      "plan_outline" => {
        instruction: "Draft an initial project roadmap with milestones, dependencies, assumptions, acceptance criteria and risks. It is not an agreed schedule.",
        icon: "bi-list-check", max_output_tokens: 2200
      }
    }.freeze

    NAVIGATION = {
      "workspace" => "workspace",
      "cabinet" => "owner_cabinet",
      "services" => "owner_services",
      "catalogue_ai" => "owner_catalogue_ai",
      "capabilities" => "owner_capabilities",
      "interview" => "owner_setup",
      "spending" => "owner_ai_activity"
    }.freeze

    def self.fetch(key)
      OPERATIONS[key.to_s]
    end

    def self.keys
      OPERATIONS.keys
    end
  end
end
