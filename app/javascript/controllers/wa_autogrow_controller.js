import { Controller } from "@hotwired/stimulus"

// Opt-in progressive enhancement. The native textarea remains the source of
// truth for form submission, validation, content and Turbo history snapshots.
export default class extends Controller {
  static values = { counterId: String, smooth: Boolean }

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
    const oldHeight = input.getBoundingClientRect().height
    // Measure while visually retaining the previous pixel height. This allows
    // CSS height transitions when smooth mode is explicitly enabled.
    input.style.height = "auto"
    const style = getComputedStyle(input)
    const minimum = Number.parseFloat(style.minHeight) || 0
    const limit = Number.parseFloat(style.maxHeight)
    const contentHeight = Math.max(input.scrollHeight, minimum)
    const targetHeight = Number.isFinite(limit) ? Math.min(contentHeight, limit) : contentHeight

    if (this.smoothValue && oldHeight > 0 && Math.abs(oldHeight - targetHeight) > 1 &&
        !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      input.style.height = `${oldHeight}px`
      // Force the browser to register the starting size before transitioning.
      void input.offsetHeight
    }
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
