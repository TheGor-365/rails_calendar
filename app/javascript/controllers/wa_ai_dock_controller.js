import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the native White Atlas owner assistant <details>.
// Keep the launcher functional even when JavaScript is disabled.
export default class extends Controller {
  connect() {
    this.onKeydown = (event) => {
      if (event.key !== "Escape" || !this.element.open) return
      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
    this.onPointerDown = (event) => {
      if (this.element.open && !this.element.contains(event.target)) this.element.open = false
    }
    this.onBeforeCache = () => { this.element.open = false }
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("pointerdown", this.onPointerDown)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("pointerdown", this.onPointerDown)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }
}
