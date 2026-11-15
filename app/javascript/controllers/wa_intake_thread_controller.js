import { Controller } from "@hotwired/stimulus"

// Presentation-only filters, search and chronological ordering.
// Reads DOM attributes only; no network, DB mutation or inferred AI status.
export default class extends Controller {
  static targets = ["item", "filter", "empty", "list", "count", "search", "order"]

  connect() {
    this.role = "all"
    this.query = ""
    this.direction = "oldest"
    this.apply()
  }

  filter(event) {
    const requested = event.params.role
    if (!["all", "client", "assistant"].includes(requested)) return
    this.role = requested
    this.apply()
  }

  search(event) {
    this.query = event.target.value.trim().toLocaleLowerCase()
    this.apply()
  }

  sort(event) {
    const requested = event.target.value
    if (!["oldest", "newest"].includes(requested)) return
    this.direction = requested
    if (this.hasListTarget) {
      const items = [...this.itemTargets].sort((a, b) => {
        const difference = Number(a.dataset.waIntakeThreadId) - Number(b.dataset.waIntakeThreadId)
        return this.direction === "newest" ? -difference : difference
      })
      items.forEach((item) => this.listTarget.append(item))
    }
    this.apply()
  }

  apply() {
    let visible = 0
    this.filterTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.waIntakeThreadRoleParam === this.role))
    })
    this.itemTargets.forEach((item) => {
      const matchesRole = this.role === "all" || item.dataset.waIntakeThreadRole === this.role
      const matchesSearch = this.query === "" || item.textContent.toLocaleLowerCase().includes(this.query)
      item.hidden = !(matchesRole && matchesSearch)
      if (!item.hidden) visible += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
    if (this.hasCountTarget) this.countTarget.textContent = `${visible} / ${this.itemTargets.length}`
  }
}
