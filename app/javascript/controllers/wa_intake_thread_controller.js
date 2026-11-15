import { Controller } from "@hotwired/stimulus"

// Presentation-only role filter; all stored messages remain in the DOM.
// No AI generation, network requests, or server status transitions.
export default class extends Controller {
  static targets = ["item", "filter", "empty"]

  connect() {
    this.role = "all"
    this.apply()
  }

  filter(event) {
    const requested = event.params.role
    if (!["all", "client", "assistant"].includes(requested)) return
    this.role = requested
    this.apply()
  }

  apply() {
    let visible = 0
    this.filterTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.waIntakeThreadRoleParam === this.role))
    })
    this.itemTargets.forEach((item) => {
      item.hidden = this.role !== "all" && item.dataset.waIntakeThreadRole !== this.role
      if (!item.hidden) visible += 1
    })
    this.emptyTarget.hidden = visible > 0
  }
}
