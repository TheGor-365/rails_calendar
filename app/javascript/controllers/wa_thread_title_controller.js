import { Controller } from "@hotwired/stimulus"

// One-line inline title editor. Autocomplete is local; only a valid blur/Enter
// sends an authenticated PATCH to the owning conversation. No page navigation.
export default class extends Controller {
  static targets = ["label", "link", "input", "form", "error"]
  static values = { url: String, conversationId: Number }

  connect() {
    this.original = this.hasLabelTarget ? this.labelTarget.textContent.trim() : ""
    this.saving = false
  }

  edit(event) {
    event.preventDefault()
    const menu = event.target.closest("details")
    if (menu) menu.open = false
    this.linkTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.value = this.original
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  key(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.inputTarget.value = this.original
      this.cancel()
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.inputTarget.blur()
    }
  }

  cancel() {
    this.formTarget.hidden = true
    this.linkTarget.hidden = false
    this.errorTarget.hidden = true
  }

  async save(event) {
    event.preventDefault()
    if (this.saving || this.formTarget.hidden) return
    const next = this.inputTarget.value.trim()
    if (next === this.original) return this.cancel()
    if (!next || next.length > 100) {
      this.errorTarget.textContent = "Enter a title of 1–100 characters"
      this.errorTarget.hidden = false
      this.inputTarget.focus()
      return
    }
    this.saving = true
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
        },
        body: JSON.stringify({ title: next })
      })
      if (!response.ok) throw new Error("Unable to save title")
      const result = await response.json()
      this.original = result.title
      this.labelTarget.textContent = result.title
      const current = document.querySelector('[data-wa-thread-title-current-id="' + this.conversationIdValue + '"]')
      if (current) current.textContent = result.title
      this.cancel()
    } catch (error) {
      this.errorTarget.textContent = error.message
      this.errorTarget.hidden = false
      this.inputTarget.focus()
    } finally {
      this.saving = false
    }
  }
}
