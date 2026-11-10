import { Controller } from "@hotwired/stimulus"

// Progressive enhancement. Keyboard/file-input works without JS.
// No background upload, auto-submit or durable storage here.
export default class extends Controller {
  static targets = ["zone", "input", "filename"]

  connect() {
    this.changed()
  }

  dragOver(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("rc-studio-dropzone--hover")
  }

  dragLeave(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("rc-studio-dropzone--hover")
  }

  drop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("rc-studio-dropzone--hover")
    if (!event.dataTransfer?.files?.length) return

    const transfer = new DataTransfer()
    transfer.items.add(event.dataTransfer.files[0])
    this.inputTarget.files = transfer.files
    this.changed()
  }

  changed() {
    const file = this.inputTarget.files?.[0]
    this.filenameTarget.textContent = file
      ? file.name + " · " + (file.size / 1024).toFixed(1) + " KB selected"
      : "No source selected. Nothing will be sent until you choose Analyze."
  }
}
