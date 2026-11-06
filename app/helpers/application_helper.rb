module ApplicationHelper
  # Actions always keep their visible text; the Bootstrap icon is decorative.
  # Restrict callers to authored icon names, never untrusted request params.
  def rc_icon_label(icon, label)
    safe_join([
      tag.i(class: "bi bi-#{icon} rc-icon", aria: { hidden: "true" }),
      tag.span(label, class: "rc-action-label")
    ])
  end
end
