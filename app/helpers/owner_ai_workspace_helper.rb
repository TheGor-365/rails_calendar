module OwnerAiWorkspaceHelper
  # One shared UI registry of EXISTING approved routes, not arbitrary AI execution.
  # New workflows must bring a server-side privacy, budget and permission policy.
  def owner_ai_workflows
    [
      { key: "catalogue", icon: "bi-collection", path: owner_catalogue_ai_path },
      { key: "profile", icon: "bi-person-vcard", path: owner_setup_review_path },
      { key: "capabilities", icon: "bi-diagram-3", path: owner_capabilities_path }
    ]
  end
end
