import { Controller } from "@hotwired/stimulus"

// E2: issue a one-time invitation without leaving the owner's working draft.
// Token is intentionally only held in page memory and disappears on reload.
export default class extends Controller {
  static targets = ["submit", "result", "link", "preview", "download", "status"]
  static values = { error: String, issued: String }

  async submit(event) {
    if (!window.fetch || !this.element.reportValidity()) return
    event.preventDefault()
    if (this.submitTarget.disabled) return
    this.submitTarget.disabled = true
    this.statusTarget.textContent = ""
    try {
      const response = await fetch(this.element.action, {
        method: "POST", credentials: "same-origin",
        headers: { "Accept": "application/json" },
        body: new FormData(this.element)
      })
      const data = await response.json()
      if (!response.ok) {
        this.statusTarget.textContent = (data.errors || []).join(". ") || this.errorValue
        return
      }
      this.linkTarget.value = data.url
      this.previewTarget.href = data.preview_url
      this.downloadTarget.href = data.export_url
      this.resultTarget.hidden = false
      this.statusTarget.textContent = this.issuedValue
      this.resultTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
      // Do not reset the form or erase the AI draft; owner can inspect them.
      // One-time token should never be stored in localStorage/sessionStorage.
    } catch (_error) {
      // Network uncertainty: do not retry automatically and risk duplicate invites.
      this.statusTarget.textContent = this.errorValue
    } finally {
      this.submitTarget.disabled = false
    }
  }

  async copy(event) {
    event.preventDefault()
    if (!this.hasLinkTarget || !this.linkTarget.value) return
    try {
      await navigator.clipboard.writeText(this.linkTarget.value)
    } catch (_error) {
      this.linkTarget.focus()
      this.linkTarget.select()
    }
  }
}
