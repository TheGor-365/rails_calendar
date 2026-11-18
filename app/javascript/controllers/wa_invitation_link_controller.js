import { Controller } from "@hotwired/stimulus"

// Fragment-only bearer secret: never transmit as GET query, URL path or Referer.
export default class extends Controller {
  static targets = ["token"]

  connect() {
    const match = window.location.hash.match(/^#token=([0-9a-f]{64})$/)
    if (!match || !this.hasTokenTarget) return
    this.tokenTarget.value = match[1]
    window.history.replaceState(null, "", window.location.pathname)
    this.element.requestSubmit()
  }
}
