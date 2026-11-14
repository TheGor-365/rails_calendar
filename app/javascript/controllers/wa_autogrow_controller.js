import { Controller } from "@hotwired/stimulus"

// Opt-in progressive enhancement. The native textarea remains the source of
// truth for form submission, validation, content and Turbo history snapshots.
export default class extends Controller {
  static values = { counterId: String }

  connect() {
    this.onViewportResize = () => this.resize()
    this.onBeforeCache = () => this.resetSizing()

    window.addEventListener("resize", this.onViewportResize)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.resize()
  }

  disconnect() {
    window.removeEventListener("resize", this.onViewportResize)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.resetSizing()
  }

  resize() {
    const input = this.element
    if (!(input instanceof HTMLTextAreaElement)) return

    // Always recompute from the content, including pasted text, undo, input
    // reductions and pre-filled error forms. Respect the CSS viewport cap.
    input.style.height = "auto"
    const style = getComputedStyle(input)
    const minimum = Number.parseFloat(style.minHeight) || 0
    const limit = Number.parseFloat(style.maxHeight)
    const contentHeight = Math.max(input.scrollHeight, minimum)
    const targetHeight = Number.isFinite(limit) ? Math.min(contentHeight, limit) : contentHeight

    input.style.height = `${targetHeight}px`
    input.style.overflowY = contentHeight > targetHeight ? "auto" : "hidden"

    if (this.hasCounterIdValue) {
      const counter = document.getElementById(this.counterIdValue)
      if (counter) {
        const max = input.maxLength >= 0 ? input.maxLength : ""
        counter.textContent = max ? `${input.value.length} / ${max}` : String(input.value.length)
      }
    }
  }

  resetSizing() {
    if (!(this.element instanceof HTMLTextAreaElement)) return
    this.element.style.removeProperty("height")
    this.element.style.removeProperty("overflow-y")
  }
}
