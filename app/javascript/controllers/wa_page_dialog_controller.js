import { Controller } from "@hotwired/stimulus"

// Same-origin full pages retain their own forms, CSRF, Turbo and controllers.
export default class extends Controller {
  static targets = ["dialog", "heading", "page"]
  connect() {
    this.onClick = event => this.openLink(event)
    this.element.addEventListener("click", this.onClick)
    this.beforeCache = () => this.reset()
    document.addEventListener("turbo:before-cache", this.beforeCache)
    if (window.parent !== window && window.frameElement?.hasAttribute("data-wa-embedded-page")) {
      document.documentElement.classList.add("wa-embedded-page")
    }
  }
  disconnect() {
    this.element.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.reset()
  }
  openLink(event) {
    const link = event.target.closest("a[data-wa-page-dialog]")
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey ||
        event.ctrlKey || event.shiftKey || event.altKey || link.target || this.dialogTarget.open) return
    const url = new URL(link.href, location.href)
    if (url.origin !== location.origin) return
    event.preventDefault()
    this.opener = link
    const title = link.getAttribute("aria-label") || link.querySelector("strong")?.textContent || link.textContent.trim()
    this.headingTarget.textContent = title
    this.pageTarget.title = title
    this.pageTarget.src = url.href
    this.dialogTarget.showModal()
  }
  cancel(event) { event.preventDefault(); this.close() }
  backdrop(event) { if (event.target === this.dialogTarget) this.close() }
  close() {
    if (!this.dialogTarget.open || this.closing) return
    this.closing = true
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) { this.reset(); return }
    this.dialogTarget.animate([{opacity:1},{opacity:0}], {duration:160,easing:"ease-in"}).finished.catch(() => {}).then(() => this.reset())
  }
  reset() {
    this.closing = false
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.hasPageTarget) this.pageTarget.src = "about:blank"
    if (this.opener?.isConnected) this.opener.focus({preventScroll:true})
    this.opener = null
  }
}
