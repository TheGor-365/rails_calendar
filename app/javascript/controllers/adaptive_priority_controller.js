import { Controller } from "@hotwired/stimulus"

// Progressive enhancement only. With JS disabled every priority selector
// remains visible; the Rails model validates explicit priorities either way.
export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh() {
    this.element.querySelectorAll("[data-rc-priority-row]").forEach((row) => {
      const choice = row.querySelector("input[type='checkbox'], input[type='radio']")
      const field = row.querySelector("[data-rc-priority-field]")
      const priority = row.querySelector("[data-rc-priority-select]")
      if (!choice || !field || !priority) return

      const chosen = choice.checked
      field.hidden = !chosen
      priority.disabled = !chosen
      priority.required = chosen
    })
  }
}
