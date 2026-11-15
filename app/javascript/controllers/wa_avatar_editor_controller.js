import { Controller } from "@hotwired/stimulus"

// Progressive enhancement: browser-side 1:1 square crop before private upload.
// Native HTML form remains functional if JavaScript/canvas is unavailable.
export default class extends Controller {
  static targets = ["file", "preview", "status", "submit"]
  static values = { success: String, failure: String }

  connect() {
    this.processing = false
    this.previewObjectUrl = null
  }

  async prepare() {
    const file = this.fileTarget.files?.[0]
    if (!file) return
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) return

    this.processing = true
    this.submitTarget.disabled = true
    this.statusTarget.textContent = ""
    try {
      const bitmap = await createImageBitmap(file)
      const canvas = document.createElement("canvas")
      canvas.width = 512
      canvas.height = 512
      const ctx = canvas.getContext("2d")
      if (!ctx) throw new Error("Canvas unavailable")

      const side = Math.min(bitmap.width, bitmap.height)
      const x = Math.floor((bitmap.width - side) / 2)
      const y = Math.floor((bitmap.height - side) / 2)
      ctx.drawImage(bitmap, x, y, side, side, 0, 0, 512, 512)
      bitmap.close?.()

      const blob = await new Promise((resolve, reject) => {
        canvas.toBlob(result => result ? resolve(result) : reject(new Error("Encoding failed")), "image/jpeg", 0.9)
      })
      const normalized = new File([blob], "avatar-square.jpg",
        { type: "image/jpeg", lastModified: Date.now() })
      const transfer = new DataTransfer()
      transfer.items.add(normalized)
      this.fileTarget.files = transfer.files

      if (this.hasPreviewTarget) {
        if (this.previewObjectUrl) URL.revokeObjectURL(this.previewObjectUrl)
        this.previewObjectUrl = URL.createObjectURL(blob)
        this.previewTarget.src = this.previewObjectUrl
      }
      this.statusTarget.textContent = this.successValue
    } catch (_) {
      // Explicit feedback and original file fallback: server still validates MIME and size.
      this.statusTarget.textContent = this.failureValue
    } finally {
      this.processing = false
      this.submitTarget.disabled = false
    }
  }

  guard(event) {
    if (this.processing) event.preventDefault()
  }

  disconnect() {
    if (this.previewObjectUrl) URL.revokeObjectURL(this.previewObjectUrl)
  }
}
