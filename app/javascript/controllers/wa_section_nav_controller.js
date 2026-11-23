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

    // The White Atlas header is sticky on desktop and may wrap to two rows.
    // A fixed 20px top hides the section rail behind it. Measure actual height.
    this.header = document.querySelector(".app-header")
    this.syncHeaderOffset = this.syncHeaderOffset.bind(this)
    window.addEventListener("resize", this.syncHeaderOffset, { passive: true })
    if (this.header && typeof ResizeObserver !== "undefined") {
      this.headerObserver = new ResizeObserver(this.syncHeaderOffset)
      this.headerObserver.observe(this.header)
    }
    this.syncHeaderOffset()
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onPositionChanged)
    window.removeEventListener("resize", this.onPositionChanged)
    window.removeEventListener("hashchange", this.onHashChanged)
    window.removeEventListener("resize", this.syncHeaderOffset)
    this.headerObserver?.disconnect()
  }

  syncHeaderOffset() {
    const sticky = this.header && ["sticky", "fixed"].includes(getComputedStyle(this.header).position)
    const height = sticky ? Math.ceil(this.header.getBoundingClientRect().height) : 0
    this.element.style.setProperty("--wa-section-nav-sticky-top", `${height + 16}px`)
  }

  activate(event) {
    const hash = event.currentTarget.getAttribute("href")
    if (!hash?.startsWith("#")) return
    const anchor = hash.slice(1)
    const section = document.getElementById(anchor)
    if (!section || !this.element.contains(section)) return
    event.preventDefault()

    // Turbo may handle in-page links without leaving the fragment in the
    // address bar. Keep native back/forward and shareable section URLs.
    if (window.location.hash !== hash) {
      window.history.pushState(window.history.state, "", hash)
    }
    section.scrollIntoView({ block: "start", behavior: "auto" })
    this.highlight(anchor)
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
