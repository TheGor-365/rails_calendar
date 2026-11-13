module OwnerSetupHelper
  def owner_capability_title(domain, mode = "direct")
    label = OwnerIntelligence::Catalog::QUESTIONS.values
      .filter_map { |section| section.fetch(:options)[domain] }.first
    primary = mode == "ai_assisted" ? "C" : "B"
    alternate = primary == "B" ? "C" : "B"
    t("owner_setup.options.#{primary}.#{domain}",
      default: t("owner_setup.options.#{alternate}.#{domain}",
                 default: label || domain.tr("_", " ").capitalize))
  end

  def owner_capability_condition(domain)
    # A technology marked both practiced and AI-assisted is not a verified
    # autonomous delivery promise. Show the conditions before acceptance.
    t("owner_setup.requires_review")
  end
end
