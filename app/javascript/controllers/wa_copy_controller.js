import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]

  async copy() {
    if (!this.hasInputTarget) return
    this.inputTarget.select()
    try {
      await navigator.clipboard.writeText(this.inputTarget.value)
      if (this.hasStatusTarget) this.statusTarget.textContent = "✓"
    } catch (_) {
      // The selected input still supports manual copy via Ctrl+C.
      if (this.hasStatusTarget) this.statusTarget.textContent = "Ctrl+C"
    }
  }
}
