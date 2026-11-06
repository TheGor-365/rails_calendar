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
end
