import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Owner-only, inline creation for a dated calendar slot; posts to existing guarded
// consultations endpoint and keeps the user on the same calendar view.
export default class extends Controller {
  static targets = ["dialog", "start", "end", "title", "description", "error", "submit"]
  static values = { url: String }

  open(event) {
    event.preventDefault()
    const requested = event.currentTarget.dataset.startAt
    if (requested) this.setStart(requested)
    this.errorTarget.textContent = ""
    this.dialogTarget.showModal()
    this.titleTarget.focus()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  outside(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  setStart(value) {
    const initial = new Date(value)
    if (Number.isNaN(initial.getTime())) return
    // Calendar's own timezone is authoritative (currently UTC). Use the
    // local-time component supplied by the server instead of an inferred zone.
    const local = value.slice(0, 16)
    this.startTarget.value = local
    const [day, clock] = local.split("T")
    const hours = Number(clock.slice(0, 2))
    const minutes = clock.slice(3, 5)
    const end = new Date(`${day}T${clock}:00Z`)
    end.setUTCHours(hours + 1)
    this.endTarget.value = `${end.toISOString().slice(0, 10)}T${end.toISOString().slice(11, 16)}`
  }

  async save(event) {
    event.preventDefault()
    const form = event.currentTarget
    if (!form.reportValidity() || this.pending) return
    this.pending = true
    this.submitTarget.disabled = true
    this.errorTarget.textContent = ""
    try {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": csrf || "" },
        body: new FormData(form)
      })
      const payload = await response.json()
      if (!response.ok) {
        this.errorTarget.textContent = (payload.errors || ["Unable to save"]).join(". ")
        return
      }
      this.close()
      Turbo.visit(window.location.href, { action: "replace" })
    } catch (_) {
      this.errorTarget.textContent = this.element.dataset.networkError || "Unable to save"
    } finally {
      this.pending = false
      this.submitTarget.disabled = false
    }
  }
}
