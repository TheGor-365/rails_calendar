import { Controller } from "@hotwired/stimulus"

// Local, no-network feedback for the synthetic quiz. The persisted answer is
// always controlled by IntakeQuizzesController and revisioned server-side.
export default class extends Controller {
  static targets = ["state", "count", "unsure", "other"]

  connect() {
    this.submitting = false
    this.original = this.snapshot()
    this.onVisit = this.beforeVisit.bind(this)
    this.onUnload = this.beforeUnload.bind(this)
    document.addEventListener("turbo:before-visit", this.onVisit)
    window.addEventListener("beforeunload", this.onUnload)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.onVisit)
    window.removeEventListener("beforeunload", this.onUnload)
  }

  snapshot() {
    const form = this.element
    return JSON.stringify(Array.from(form.elements).filter((el) => {
      return el.name && el.name !== "quiz[navigation]" && el.name !== "authenticity_token" &&
        el.type !== "submit" && el.type !== "hidden"
    }).map((el) => [el.name, el.value, el.type === "checkbox" || el.type === "radio" ? el.checked : null]))
  }

  changed(event) {
    const el = event.target
    if (el === this.unsureTarget && el.checked) {
      this.element.querySelectorAll('input[name="quiz[selected_options][]"]').forEach((input) => { input.checked = false })
      if (this.hasOtherTarget) this.otherTarget.value = ""
    } else if (this.hasUnsureTarget && el !== this.unsureTarget &&
      (el.name === "quiz[selected_options][]" || el.name === "quiz[other_text]") &&
      (el.type === "checkbox" ? el.checked : Boolean(el.value.trim()))) {
      this.unsureTarget.checked = false
    }
    this.refresh()
  }

  refresh() {
    const count = this.element.querySelectorAll('input[name="quiz[selected_options][]"]:checked').length
    const dirty = this.snapshot() !== this.original
    if (this.hasCountTarget) {
      this.countTarget.textContent = count > 0 ? `${count} option${count === 1 ? "" : "s"} selected` : "Choose an option or enter your own answer"
    }
    if (this.hasStateTarget) {
      this.stateTarget.dataset.dirty = String(dirty)
      this.stateTarget.textContent = dirty ? "Unsaved changes — choose Save to keep them" : "No unsaved edits on this card"
    }
  }

  submit() { this.submitting = true }

  submitEnd(event) {
    if (!event.detail.success) this.submitting = false
  }

  beforeVisit(event) {
    if (this.submitting || this.snapshot() === this.original) return
    if (!window.confirm("This quiz card has unsaved changes. Leave without saving?")) event.preventDefault()
  }

  beforeUnload(event) {
    if (this.submitting || this.snapshot() === this.original) return
    event.preventDefault()
    event.returnValue = ""
  }
}
