import { Controller } from "@hotwired/stimulus"

// Owner-only, read-only Turbo preview. No server writes, form interception,
// provider requests, or state changes. Full-page links still work without JS.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  remember(event) {
    this.opener = event.currentTarget
  }

  // Isolated review worktrees may have database metadata but no local media
  // bytes. Show the real category-icon placeholder instead of a broken image.
  // Never delete, overwrite or re-upload the original attachment.
  imageFailed(event) {
    const cover = event.currentTarget.closest(".wa-services__cover-wrap")
    if (cover) cover.classList.add("wa-services__cover-wrap--unavailable")
    event.currentTarget.hidden = true
  }

  loaded(event) {
    if (event.target !== this.frameTarget) return
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  restoreFocus() {
    if (this.opener?.isConnected) this.opener.focus()
  }

  disconnect() {
    if (this.hasDialogTarget) this.close()
  }
}
