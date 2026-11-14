import { Controller } from "@hotwired/stimulus"

// Client-side view filter only. Sections and their native inputs stay in the
// form and are never mutated, dropped or replaced during search/filtering.
export default class extends Controller {
  static targets = ["section", "filter", "search", "toolbar", "empty"]

  connect() {
    this.category = "all"
    this.toolbarTarget.hidden = false
    this.update()
  }

  filter(event) {
    const requested = event.params.category
    if (["all", "overview", "scope", "verification", "risks"].includes(requested)) {
      this.category = requested
      this.update()
    }
  }

  navigate() {
    // Anchor navigation must always work, including when a prior filter hid
    // its target. The link's default fragment jump is preserved.
    this.category = "all"
    this.searchTarget.value = ""
    this.update()
  }

  clearSearch(event) {
    event.preventDefault()
    this.searchTarget.value = ""
    this.update()
  }

  update() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    let visible = 0
    this.filterTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.waSpecReviewCategoryParam === this.category))
    })

    this.sectionTargets.forEach((section) => {
      const field = section.querySelector("textarea")
      const contents = field ? field.value : ""
      const label = section.dataset.waSpecReviewLabel || ""
      const matchesGroup = this.category === "all" || section.dataset.waSpecReviewGroup === this.category
      const matchesQuery = !query || `${label} ${contents}`.toLocaleLowerCase().includes(query)
      section.hidden = !(matchesGroup && matchesQuery)
      if (!section.hidden) visible += 1

      const counter = section.querySelector("[data-wa-spec-review-count]")
      if (counter && field) {
        counter.textContent = String(contents.split(/\r?\n/).filter((line) => line.trim().length > 0).length)
      }
    })
    this.emptyTarget.hidden = visible > 0
  }

  // Keep the editor stable while users modify text that previously matched a
  // search query. Re-filter only on an explicit search/filter interaction.
  refreshCounts() {
    this.sectionTargets.forEach((section) => {
      const field = section.querySelector("textarea")
      const counter = section.querySelector("[data-wa-spec-review-count]")
      if (!field || !counter) return
      counter.textContent = String(field.value.split(/\\r?\\n/).filter((line) => line.trim().length > 0).length)
    })
  }
}
