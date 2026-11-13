module OwnerSetupHelper
  def owner_capability_title(domain)
    label = OwnerIntelligence::Catalog::QUESTIONS.values
      .filter_map { |section| section.fetch(:options)[domain] }.first
    t("owner_setup.options.B.#{domain}",
      default: t("owner_setup.options.C.#{domain}", default: label || domain.tr("_", " ").capitalize))
  end

  def owner_capability_condition(domain)
    # A technology marked both practiced and AI-assisted is not a verified
    # autonomous delivery promise. Show the conditions before acceptance.
    t("owner_setup.requires_review")
  end
end
