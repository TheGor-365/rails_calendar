module OwnerServiceOfferingsHelper
  SERVICE_ICONS = {
    "auto-rails-bugfix" => "bi-bug",
    "auto-rails-crud" => "bi-columns-gap",
    "auto-rails-api" => "bi-diagram-3",
    "auto-rails-tests" => "bi-clipboard2-check",
    "auto-websites" => "bi-window",
    "auto-automation" => "bi-lightning-charge",
    "auto-ai-integrations" => "bi-stars",
    "auto-data-tasks" => "bi-table",
    "auto-adjacent-web" => "bi-palette"
  }.freeze

  def service_offering_icon(offering)
    SERVICE_ICONS.fetch(offering.key, "bi-boxes")
  end

  def service_offering_state(offering)
    if offering.published_version
      ["bi-eye", t("owner_services.public_label"), "enabled"]
    elsif offering.approved_version && offering.draft_version.nil?
      ["bi-patch-check", t("owner_services.final_label"), "approved"]
    else
      ["bi-pencil-square", t("owner_services.draft_label"), "draft"]
    end
  end
end
