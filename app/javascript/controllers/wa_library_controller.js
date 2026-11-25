import { Controller } from "@hotwired/stimulus"

// Instant local filtering across authorized, server-rendered library records.
// No network calls, paid AI requests or private data stored in browser storage.
export default class extends Controller {
  static targets = ["item", "search", "kind", "from", "to", "count", "empty", "chip"]
  static values = { allLabel: String }

  connect() {
    this.apply()
  }

  apply() {
    const q = this.fold(this.searchTarget.value.trim())
    const kind = this.kindTarget.value
    const from = this.fromTarget.value
    const to = this.toTarget.value
    let visible = 0
    this.itemTargets.forEach(item => {
      const date = item.dataset.date || ""
      const matches = (!q || this.fold(item.dataset.search || "").includes(q)) &&
        (kind === "all" || item.dataset.kind === kind) &&
        (!from || date >= from) && (!to || date <= to)
      item.hidden = !matches
      if (!matches) item.open = false
      if (matches) visible++
    })
    this.countTarget.textContent = String(visible)
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible !== 0
    this.chipTargets.forEach(chip => {
      const active = chip.dataset.kind === kind
      chip.classList.toggle("is-active", active)
      chip.setAttribute("aria-pressed", String(active))
    })
    this.reflectUrl()
  }

  setKind(event) {
    this.kindTarget.value = event.currentTarget.dataset.kind
    this.apply()
  }

  datePreset(event) {
    const days = Number(event.currentTarget.dataset.days)
    if (days === 0) {
      this.fromTarget.value = ""
      this.toTarget.value = ""
    } else {
      const now = new Date()
      const end = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))
      const start = new Date(end)
      start.setUTCDate(start.getUTCDate() - days + 1)
      const iso = date => date.toISOString().slice(0, 10)
      this.fromTarget.value = iso(start)
      this.toTarget.value = iso(end)
    }
    this.apply()
  }

  reset(event) {
    event.preventDefault()
    this.searchTarget.value = ""
    this.kindTarget.value = "all"
    this.fromTarget.value = ""
    this.toTarget.value = ""
    this.apply()
  }

  submit(event) {
    event.preventDefault()
    this.apply()
  }

  fold(text) {
    return String(text).normalize("NFKC").toLocaleLowerCase()
  }

  reflectUrl() {
    const url = new URL(window.location.href)
    for (const key of ["q", "kind", "from", "to", "button"]) url.searchParams.delete(key)
    if (this.searchTarget.value.trim()) url.searchParams.set("q", this.searchTarget.value.trim())
    if (this.kindTarget.value !== "all") url.searchParams.set("kind", this.kindTarget.value)
    if (this.fromTarget.value) url.searchParams.set("from", this.fromTarget.value)
    if (this.toTarget.value) url.searchParams.set("to", this.toTarget.value)
    try { window.history.replaceState(window.history.state, "", url.toString()) } catch (_) {}
  }
}
