import { Controller } from "@hotwired/stimulus"

// Native details remains usable without JS. Reverse from the currently
// painted height rather than the stale open attribute during rapid clicks.
export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.beforeCache = () => this.finish()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  toggle(event) {
    if (!this.hasContentTarget || !this.element.animate) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.finish()
      return
    }
    event.preventDefault()
    const element = this.element
    const start = element.getBoundingClientRect().height
    const opening = !(this.animation ? this.destination : element.open)
    this.finish(false)
    this.destination = opening
    const overflow = element.style.overflow
    element.open = true
    const expanded = element.getBoundingClientRect().height
    element.open = false
    const collapsed = element.getBoundingClientRect().height
    element.open = true
    element.style.overflow = "hidden"
    this.previousOverflow = overflow
    const animation = element.animate(
      [{ height: `${start}px` }, { height: `${opening ? expanded : collapsed}px` }],
      { duration: opening ? 240 : 200, easing: "cubic-bezier(.22,.74,.24,1)", fill: "both" }
    )
    this.animation = animation
    animation.onfinish = () => {
      if (this.animation === animation) this.finish()
    }
  }

  finish(settle = true) {
    if (!this.animation) return
    const animation = this.animation
    this.animation = null
    animation.onfinish = null
    if (settle) this.element.open = this.destination
    animation.cancel()
    this.element.style.overflow = this.previousOverflow
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.finish()
  }
}
