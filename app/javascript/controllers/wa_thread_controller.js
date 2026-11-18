import { Controller } from "@hotwired/stimulus"

// Small progressive enhancement: Turbo keeps the page stationary while the
// provider replies. It never triggers network requests, retries, or AI calls.
export default class extends Controller {
  static targets = ["files", "fileNames", "loading"]

  filesChanged() {
    if (!this.hasFilesTarget || !this.hasFileNamesTarget) return
    const files = Array.from(this.filesTarget.files || [])
    this.fileNamesTarget.textContent = files.map(file => file.name).join(" · ")
    if (files.length > 3) {
      this.fileNamesTarget.textContent += " — maximum 3 files"
    }
  }

  submitStart(event) {
    this.element.setAttribute("aria-busy", "true")
    const intent = event.detail?.formSubmission?.submitter?.value
    if (this.hasLoadingTarget && intent === "ai") {
      this.loadingTarget.hidden = false
    }
  }

  submitEnd() {
    this.element.removeAttribute("aria-busy")
    if (this.hasLoadingTarget) this.loadingTarget.hidden = true
  }
}
