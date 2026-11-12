module ProjectIntakeI18nHelper
  # Presentation only. Persist canonical enum values and document section keys.
  def rc_intake_type(value)
    I18n.t("intake.types.#{value}", default: value.to_s.humanize)
  end

  def rc_intake_status(value)
    I18n.t("intake.statuses.#{value}", default: value.to_s.humanize)
  end
end
