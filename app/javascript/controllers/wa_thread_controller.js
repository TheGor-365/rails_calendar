import { Controller } from "@hotwired/stimulus"

// Small progressive enhancement: Turbo keeps the page stationary while the
// provider replies. It never triggers network requests, retries, or AI calls.
export default class extends Controller {
  static targets = ["files", "fileNames", "loading", "clear", "consent", "error"]
  static values = { consentError: String, fileError: String }

  filesChanged() {
    if (!this.hasFilesTarget || !this.hasFileNamesTarget) return
    const files = Array.from(this.filesTarget.files || [])
    this.fileNamesTarget.textContent = files.map(file => file.name).join(" · ")
    if (this.hasClearTarget) this.clearTarget.hidden = files.length === 0
    if (files.length > 3) {
      this.fileNamesTarget.textContent += " — maximum 3 files"
    }
  }

  clearFiles() {
    if (!this.hasFilesTarget) return
    this.filesTarget.value = ""
    this.filesChanged()
  }

  // Prevent avoidable validation POSTs so the browser keeps the selected file
  // and typed draft. Rails independently enforces the same authorization.
  guard(event) {
    if (!this.hasErrorTarget) return
    const files = this.hasFilesTarget ? Array.from(this.filesTarget.files || []) : []
    const ai = event.submitter?.name === "intent" && event.submitter?.value === "ai"
    let error = ""
    if (files.length > 3) {
      error = this.fileErrorValue
    } else if (ai && files.some(file => ![".png", ".jpg", ".jpeg", ".txt", ".csv", ".md", ".markdown", ".log", ".json", ".rb", ".py", ".js", ".ts", ".yml", ".yaml", ".xml", ".css", ".scss", ".sql", ".sh"].some(ext => file.name.toLowerCase().endsWith(ext)))) {
      error = this.fileErrorValue
    } else if (ai && (!this.hasConsentTarget || !this.consentTarget.checked)) {
      error = this.consentErrorValue
      if (this.hasConsentTarget) this.consentTarget.focus()
    }
    if (error) {
      event.preventDefault()
      this.errorTarget.textContent = error
      this.errorTarget.hidden = false
    } else {
      this.errorTarget.textContent = ""
      this.errorTarget.hidden = true
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
