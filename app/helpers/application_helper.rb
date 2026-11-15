module ApplicationHelper
  # Actions always keep their visible text; the Bootstrap icon is decorative.
  # Restrict callers to authored icon names, never untrusted request params.
  def rc_icon_label(icon, label)
    safe_join([
      tag.i(class: "bi bi-#{icon} rc-icon", aria: { hidden: "true" }),
      tag.span(label, class: "rc-action-label")
    ])
  end

  # A compact visual label for narrow buttons while keeping the full
  # accessible name on the parent link/button.
  def rc_responsive_icon_label(icon, label, mobile_label)
    safe_join([
      tag.i(class: "bi bi-#{icon} rc-icon", aria: { hidden: "true" }),
      tag.span(label, class: "rc-action-label rc-action-label--full"),
      tag.span(mobile_label, class: "rc-action-label rc-action-label--compact", aria: { hidden: "true" })
    ])
  end

  # One SQL count per rendered owner request; client and legacy admin get zero.
  def owner_unread_intake_count
    return 0 unless owner_signed_in?

    @owner_unread_intake_count ||= OwnerIntakeInbox.unread_for(owner: current_user).count
  end

  def owner_unread_badge_label
    total = owner_unread_intake_count
    total > 99 ? "99+" : total.to_s
  end
end
