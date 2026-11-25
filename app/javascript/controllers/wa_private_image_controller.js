import { Controller } from "@hotwired/stimulus"

// Media rows can outlive disk bytes in an isolated preview checkout.
// Render the White Atlas icon already in the DOM rather than a broken <img>.
// No fetch, DB mutation, or storage repair is attempted.
export default class extends Controller {
  static targets = ["image", "fallback"]

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth === 0) {
      this.failed()
    }
  }

  failed() {
    if (this.hasImageTarget) this.imageTarget.hidden = true
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }
}
