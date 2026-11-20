import { Controller } from "@hotwired/stimulus"

// View preference is local to this browser. Server-rendered records remain owner-scoped.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { key: String }

  connect() {
    const requested = new URLSearchParams(window.location.search).get("view")
    let persisted = null
    try { persisted = window.localStorage.getItem(this.keyValue) } catch (_) {}
    this.activate(requested === "outgoing" || requested === "incoming" ? requested : persisted || "incoming")
  }

  select(event) {
    this.activate(event.currentTarget.dataset.view)
  }

  keyboard(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.currentTarget)
    const next = event.key === "Home" ? 0 :
      event.key === "End" ? tabs.length - 1 :
      (index + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length
    this.activate(tabs[next].dataset.view)
    tabs[next].focus()
  }

  activate(view) {
    const chosen = this.panelTargets.some(panel => panel.dataset.view === view) ? view : "incoming"
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.view === chosen
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach(panel => {
      const active = panel.dataset.view === chosen
      panel.hidden = !active
      panel.classList.toggle("is-active", active)
    })
    try { window.localStorage.setItem(this.keyValue, chosen) } catch (_) {}
  }
}
