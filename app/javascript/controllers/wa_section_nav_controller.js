import { Controller } from "@hotwired/stimulus"

// Local scroll position only: no request, mutation or server status transitions.
// Links are native hash anchors and continue to work without JavaScript.
export default class extends Controller {
  static targets = ["link"]

  connect() {
    this.onPositionChanged = this.update.bind(this)
    this.onHashChanged = this.update.bind(this)
    window.addEventListener("scroll", this.onPositionChanged, { passive: true })
    window.addEventListener("resize", this.onPositionChanged, { passive: true })
    window.addEventListener("hashchange", this.onHashChanged)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onPositionChanged)
    window.removeEventListener("resize", this.onPositionChanged)
    window.removeEventListener("hashchange", this.onHashChanged)
  }

  activate(event) {
    const anchor = event.currentTarget.getAttribute("href")
    if (anchor) this.highlight(anchor.slice(1))
  }

  update() {
    const sections = this.linkTargets.map((link) => {
      const anchor = link.getAttribute("href")?.slice(1)
      return { link, anchor, section: anchor && document.getElementById(anchor) }
    }).filter((item) => item.section && this.element.contains(item.section))
    if (!sections.length) return

    // Sticky header and mobile dock may obscure the extreme viewport edges.
    const threshold = Math.max(180, Math.min(260, window.innerHeight * 0.28))
    let active = sections[0].anchor
    for (const entry of sections) {
      if (entry.section.getBoundingClientRect().top <= threshold) active = entry.anchor
    }
    this.highlight(active)
  }

  highlight(anchor) {
    this.linkTargets.forEach((link) => {
      const active = link.getAttribute("href") === `#${anchor}`
      link.setAttribute("aria-current", active ? "location" : "false")
    })
  }
}
