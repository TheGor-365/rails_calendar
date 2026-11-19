import { Controller } from "@hotwired/stimulus"

// E2 local pilot: deterministic, free, reviewable brief composer.
// No provider calls. All selections are composed into existing seed_goal;
// structured server-side versioning is a separate rollout gate.
export default class extends Controller {
  static targets = ["goal", "notes", "status"]
  static values = { minimum: { type: Number, default: 10 }, maximum: { type: Number, default: 1200 } }

  compose(event) {
    event.preventDefault()
    if (!this.hasGoalTarget) return

    // Never silently overwrite a hand-edited task description.
    if (this.goalTarget.value.trim() && this.goalTarget.dataset.waGenerated !== "true") {
      this.announce(this.element.dataset.waBriefKeepManual || "Manual text preserved; clear it before using the composer.")
      this.goalTarget.focus()
      return
    }

    const lines = []
    this.element.querySelectorAll("[data-wa-brief-section]").forEach((section) => {
      const choices = Array.from(section.querySelectorAll("[data-wa-brief-choice]:checked"))
        .map((input) => input.closest("label")?.querySelector("span")?.textContent?.trim())
        .filter(Boolean)
      const decision = section.querySelector("[data-wa-brief-decision]")?.value
      const title = section.querySelector("legend")?.textContent?.trim()
      if (choices.length) {
        lines.push(`${title}: ${choices.join(", ")}.`)
      } else if (decision === "client") {
        lines.push(`${title}: ${this.element.dataset.waBriefClientDecides || "To be clarified by client"}.`)
      } else if (decision === "owner") {
        lines.push(`${title}: ${this.element.dataset.waBriefOwnerDecides || "At owner's discretion"}.`)
      }
    })

    const notes = this.hasNotesTarget ? this.notesTarget.value.trim() : ""
    if (notes) lines.push(`${this.element.dataset.waBriefNotesLabel || "Additional details"}: ${notes}`)
    const text = lines.join("\n")

    if (text.length < this.minimumValue) {
      this.announce(this.element.dataset.waBriefEmpty || "Choose a category or add a note first.")
      return
    }
    if (text.length > this.maximumValue) {
      this.announce(this.element.dataset.waBriefLong || "The brief exceeds the permitted length; shorten selections or notes.")
      return
    }

    this.goalTarget.value = text
    this.goalTarget.dataset.waGenerated = "true"
    this.goalTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.announce(this.element.dataset.waBriefComposed || "Review the drafted brief before issuing an invitation.")
    this.goalTarget.focus()
  }

  manualEdit(event) {
    if (event.isTrusted) this.goalTarget.dataset.waGenerated = "false"
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
