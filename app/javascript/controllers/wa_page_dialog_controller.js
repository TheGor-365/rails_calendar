import { Controller } from "@hotwired/stimulus"

// Only explicitly marked GET links. Server authorization is unchanged.
// The original link is always available as a full-page fallback.
export default class extends Controller {
  static targets = ["dialog", "content", "fallback", "status", "heading", "frame"]

  connect() {
    this.onClick = event => this.openLink(event)
    this.element.addEventListener("click", this.onClick)
    this.beforeCache = () => this.reset()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.reset()
  }

  async openLink(event) {
    const link = event.target.closest("a[data-wa-page-dialog]")
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey ||
        event.ctrlKey || event.shiftKey || event.altKey || link.target) return
    const url = new URL(link.href, location.href)
    if (url.origin !== location.origin) return
    if (this.dialogTarget.open) return
    event.preventDefault()
    this.opener = link
    this.fallbackTarget.href = url.href
    this.headingTarget.textContent = link.getAttribute("aria-label") || link.textContent.trim()
    this.contentTarget.replaceChildren()
    this.statusTarget.hidden = false
    this.dialogTarget.showModal()
    if (link.dataset.waPageDialog === "frame") {
      this.frameTarget.hidden = false
      this.frameTarget.src = url.href
      return
    }
    this.request = new AbortController()
    const request = this.request
    try {
      const response = await fetch(url.href, { credentials: "same-origin", signal: request.signal,
        headers: { Accept: "text/html" }, cache: "no-store" })
      if (!response.ok || response.redirected || new URL(response.url).origin !== location.origin) throw Error("unavailable")
      const document = new DOMParser().parseFromString(await response.text(), "text/html")
      const source = document.querySelector("#main-content")
      if (source) source.querySelectorAll("turbo-frame").forEach(frame => frame.replaceWith(...frame.childNodes))
      if (!source) throw Error("unavailable")
      if (request.signal.aborted || this.request !== request) return
      // Read-only preview: do not clone forms, interactive scripts or nested dialogs.
      source.querySelectorAll("form, script, dialog, iframe, object, embed, [data-controller]").forEach(node => {
        if (node.matches("[data-controller]") && !node.matches("form, script, dialog, iframe, object, embed")) {
          node.removeAttribute("data-controller")
        } else node.remove()
      })
      source.querySelectorAll("*").forEach(node => {
        node.removeAttribute("id")
        node.removeAttribute("autofocus")
        for (const attr of [...node.attributes]) {
          if (attr.name.startsWith("data-") || attr.name.startsWith("on")) node.removeAttribute(attr.name)
        }
      })
      source.querySelectorAll("a").forEach(anchor => {
        anchor.setAttribute("data-turbo", "false")
      })
      this.contentTarget.replaceChildren(...source.childNodes)
      this.statusTarget.hidden = true
    } catch (error) {
      if (!request.signal.aborted) this.statusTarget.hidden = true
    }
  }

  frameLoaded() {
    this.statusTarget.hidden = true
  }

  frameMissing(event) {
    event.preventDefault()
    this.statusTarget.hidden = true
    this.frameTarget.hidden = true
    this.fallbackTarget.href = event.detail.response.url
    this.fallbackTarget.focus()
  }

  cancel(event) {
    event.preventDefault()
    this.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  close() {
    if (!this.dialogTarget.open || this.closing) return
    this.closing = true
    this.request?.abort()
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    const dialog = this.dialogTarget
    if (reduced) { this.reset(); return }
    const animation = dialog.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 160, easing: "ease-in" })
    animation.finished.catch(() => {}).then(() => this.reset())
  }

  reset() {
    this.request?.abort()
    this.request = null
    this.closing = false
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.hasContentTarget) this.contentTarget.replaceChildren()
    if (this.hasFrameTarget) {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.replaceChildren()
      this.frameTarget.hidden = true
    }
    if (this.opener?.isConnected) this.opener.focus({ preventScroll: true })
    this.opener = null
  }
}
