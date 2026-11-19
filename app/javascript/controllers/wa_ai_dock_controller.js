import { Controller } from "@hotwired/stimulus"

// White Atlas owner dock: close only on explicit user intent (launcher or Escape).
// Custom combobox menus may be rendered outside <details>; clicking their options
// must not collapse the assistant or discard in-progress form state.
export default class extends Controller {
  connect() {
    this.onKeydown = (event) => {
      if (event.key !== "Escape" || !this.element.open) return
      // Let an open nested combobox handle its own Escape before closing the dock.
      if (event.target.closest("[role='listbox'], [role='combobox'][aria-expanded='true']")) return
      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
    this.onBeforeCache = () => { this.element.open = false }
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  close() {
    this.element.open = false
    this.element.querySelector("summary")?.focus()
  }
}
