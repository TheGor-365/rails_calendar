import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for native <details>; handles variable content heights.
export default class extends Controller {
  static targets = ["content"]

  toggle(event) {
    if (!this.hasContentTarget || !this.element.animate || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    event.preventDefault()
    if (this.animation) {
      this.animation.cancel()
      this.animation = null
    }
    const summary = event.currentTarget
    const start = this.element.getBoundingClientRect().height
    const opening = !this.element.open
    if (opening) this.element.open = true
    const end = opening ? summary.getBoundingClientRect().height + this.contentTarget.scrollHeight : summary.getBoundingClientRect().height
    this.element.style.overflow = "hidden"
    this.animation = this.element.animate([
      { height: `${start}px`, opacity: 1 },
      { height: `${end}px`, opacity: 1 }
    ], { duration: 300, easing: "cubic-bezier(.22,.74,.24,1)" })
    const current = this.animation
    current.onfinish = () => {
      if (this.animation !== current) return
      this.element.open = opening
      this.element.style.overflow = ""
      this.animation = null
    }
    current.oncancel = () => {
      if (this.animation !== current) return
      this.element.style.overflow = ""
      this.animation = null
    }
  }

  disconnect() {
    if (this.animation) this.animation.cancel()
  }
}
