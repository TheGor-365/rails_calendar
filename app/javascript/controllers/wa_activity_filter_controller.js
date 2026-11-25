import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = null
  }

  change() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      // The target is a Turbo frame, not a document navigation.
      if (this.element.isConnected) this.element.requestSubmit()
    }, 260)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
