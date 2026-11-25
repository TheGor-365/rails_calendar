module OwnerAi
  # Page-aware AI capabilities. Only expose actions backed by existing,
  # authorised operations. More pages can register separate explicit catalogs.
  # This registry is presentation and policy metadata, not model-granted access.
  class PageActionRegistry
    ACTIONS = {
      invitation: {
        "intake_questions" => { icon: "bi-ui-checks-grid", target: "private_ai_draft" },
        "client_reply" => { icon: "bi-chat-square-text", target: "private_ai_draft" },
        "plan_outline" => { icon: "bi-diagram-3", target: "private_ai_draft" }
      }
    }.freeze

    def self.for_page(key)
      ACTIONS.fetch(key.to_sym, {}).select do |operation, _definition|
        OperationRegistry.fetch(operation).present?
      end
    end

    def self.allowed?(key, operation)
      for_page(key).key?(operation.to_s)
    end
  end
end
