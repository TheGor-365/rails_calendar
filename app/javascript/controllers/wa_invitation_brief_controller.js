import { Controller } from "@hotwired/stimulus"

// E2 local pilot: deterministic, free, reviewable brief composer.
// No provider calls. All selections are composed into existing seed_goal;
// structured server-side versioning is a separate rollout gate.
export default class extends Controller {
  static targets = ["goal", "notes", "status", "service"]
  static values = { minimum: { type: Number, default: 10 }, maximum: { type: Number, default: 1200 } }


  // Fast local matching against the owner's actual published services, not a
  // fabricated AI result. A future provider-based suggestion must be explicitly
  // consented, costed and reviewed before modifying anything.
  connect() {
    this.manualServiceIds = new Set()
    this.refreshSuggestions()
  }

  manualService(event) {
    if (!event.isTrusted) return
    this.manualServiceIds.add(event.currentTarget.value)
  }

  refreshSuggestions() {
    if (!this.hasServiceTarget) return
    const selected = Array.from(this.element.querySelectorAll("[data-wa-brief-choice]:checked"))
      .map(input => input.value)
    const title = this.element.querySelector("#proposal_seed_title")?.value || ""
    const notes = this.hasNotesTarget ? this.notesTarget.value : ""
    const category = this.element.querySelector("#proposal_seed_project_type")?.value || ""

    // Only specific task keywords count. Broad stack labels (Ruby, Rails, etc.)
    // must not accidentally select the entire catalogue.
    const lexicon = {
      bugfix: ["исправлен", "ошиб", "отлад", "bug", "debug", "fix"],
      forms: ["форм", "crud", "admin", "админ", "form"],
      api: ["api", "интеграц", "integration", "rest"],
      tests: ["тест", "надёж", "test", "quality", "qa"],
      ui: ["дизайн", "адаптив", "лендинг", "ui/ux", "frontend", "responsive", "website", "сайт"],
      automation: ["автоматизац", "automation", "workflow"],
      postgresql: ["postgresql", "баз дан", "database"],
      bootstrap: ["bootstrap"], stimulus: ["stimulus", "hotwire"],
      railway: ["railway"], docker: ["docker"], redis: ["redis"]
    }
    const freeText = `${title} ${notes}`.toLocaleLowerCase()
    const scored = this.serviceTargets.map(input => {
      const service = (input.dataset.waServiceSearch || "").toLocaleLowerCase()
      let score = 0
      for (const key of selected) {
        for (const keyword of (lexicon[key] || [])) {
          if (service.includes(keyword)) { score += ["bugfix", "forms", "api", "tests", "ui", "automation"].includes(key) ? 5 : 1; break }
        }
      }
      // Title/notes reinforce a known service match, but never authorize a
      // recommendation solely from generic words such as Rails.
      if (score > 0) {
        const significant = freeText.split(/[^\\p{L}\\p{N}]+/u).filter(x => x.length >= 5)
        if (significant.some(word => service.includes(word))) score += 2
        if (input.dataset.waServiceCategory === category) score += 1
      }
      return { input, score }
    }).filter(item => item.score >= 5).sort((a, b) => b.score - a.score)

    const suggested = new Set(scored.slice(0, 6).map(item => item.input.value))
    for (const input of this.serviceTargets) {
      if (!this.manualServiceIds.has(input.value)) input.checked = suggested.has(input.value)
    }
  }

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
