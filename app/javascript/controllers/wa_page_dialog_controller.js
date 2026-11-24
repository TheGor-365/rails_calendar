import { Controller } from "@hotwired/stimulus"

// Explicit GET destinations which are safe to use as embedded workspaces.
// Unknown internal destinations leave the dialog and navigate the main page.
const MODAL_AREAS = [
  ["interview", /^\/workspace\/setup(?:\/review)?\/?$/],
  ["capabilities", /^\/workspace\/practice\/capabilities\/?$/],
  ["practice", /^\/workspace\/practice\/?$/],
  ["ai-spend", /^\/workspace\/ai\/?$/],
  ["services", /^\/workspace\/services(?:\/(?:new|ai|\d+))?\/?$/],
  ["assistant", /^\/workspace\/assistant(?:\/conversations(?:\/\d+)?)?\/?$/],
  ["activity", /^\/workspace\/activity\/?$/],
  ["library", /^\/workspace\/library\/?$/],
  ["notifications", /^\/workspace\/notifications\/?$/],
  ["calendar", /^\/calendar\/hour\/?$/],
  ["calendar", /^\/consultations(?:\/(?:new|\d+(?:\/edit)?))?\/?$/],
  ["intakes", /^\/admin\/project_intakes(?:\/\d+(?:\/edit_spec)?)?\/?$/],
  ["invitations", /^\/workspace\/invitations(?:\/\d+)?\/?$/]
]

const areaFor = path => MODAL_AREAS.find(([, pattern]) => pattern.test(path))?.[0]

// Explicit authenticated download endpoints. Leave their normal browser behavior
// intact so Content-Disposition and Rails authorization remain authoritative.
const DOWNLOAD_PATHS = [
  /^\/workspace\/activity\/\d+\.txt$/,
  /^\/workspace\/library\/[^/]+\/\d+\.txt$/,
  /^\/workspace\/assistant\/conversations\/\d+\/messages\/\d+\/files\/\d+$/,
  /^\/workspace\/services\/\d+\/media\/\d+\/file$/,
  /^\/workspace\/avatar\/\d+$/,
  /^\/client\/avatar\/\d+$/
]
const isDownload = path => DOWNLOAD_PATHS.some(pattern => pattern.test(path))

function sameParentDestination(url, parentHref) {
  if (!parentHref) return false
  const parent = new URL(parentHref)
  return url.pathname === parent.pathname && url.search === parent.search
}

function eligibleLink(link, event) {
  return link && !event.defaultPrevented && event.button === 0 &&
    !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey &&
    !link.target && !link.hasAttribute("data-turbo-method") && !link.hasAttribute("data-method") &&
    !link.hasAttribute("data-turbo-frame")
}

function intentFor(url, currentHref, parentHref, explicitModal = false, download = false) {
  if (download || isDownload(url.pathname)) return "DOWNLOAD"
  if (url.origin !== location.origin) return "EXTERNAL_LINK"
  const current = new URL(currentHref)
  if (url.href === current.href || (url.pathname === current.pathname &&
      url.search === current.search && url.hash)) return "LOCAL_ACTION"
  if (sameParentDestination(url, parentHref)) return "CLOSE_TO_PARENT"
  const destinationArea = areaFor(url.pathname)
  const currentArea = areaFor(current.pathname)
  if (destinationArea && currentArea === destinationArea) return "LOCAL_WORKFLOW"
  if (destinationArea && (explicitModal || destinationArea !== currentArea)) return "REPLACE_MODAL"
  return "NAVIGATE_PARENT"
}

// Same-origin full pages retain their own forms, CSRF, Turbo and controllers.
// Navigation is coordinated only for a document inside the explicitly marked iframe.
export default class extends Controller {
  static targets = ["dialog", "heading", "page"]

  connect() {
    this.embedded = window.parent !== window &&
      window.frameElement?.hasAttribute("data-wa-embedded-page")
    this.onClick = event => this.openLink(event)
    this.element.addEventListener("click", this.onClick)
    this.beforeCache = () => { if (!this.embedded) this.reset() }
    document.addEventListener("turbo:before-cache", this.beforeCache)

    if (this.embedded) {
      document.documentElement.classList.add("wa-embedded-page")
      this.beforeVisit = event => this.embeddedVisit(event)
      this.afterSubmit = event => this.embeddedSubmit(event)
      document.addEventListener("turbo:before-visit", this.beforeVisit)
      document.addEventListener("turbo:submit-end", this.afterSubmit)
    } else {
      this.onMessage = event => this.receiveMessage(event)
      window.addEventListener("message", this.onMessage)
    }
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    if (this.embedded) {
      document.removeEventListener("turbo:before-visit", this.beforeVisit)
      document.removeEventListener("turbo:submit-end", this.afterSubmit)
    } else {
      window.removeEventListener("message", this.onMessage)
      this.reset()
    }
  }

  openLink(event) {
    const link = event.target.closest?.("a[href]")
    if (this.embedded) {
      this.embeddedClick(event, link)
      return
    }
    if (!link?.hasAttribute("data-wa-page-dialog") || link.hasAttribute("download") ||
        !eligibleLink(link, event) || this.dialogTarget.open) return
    const url = new URL(link.href, location.href)
    if (url.origin !== location.origin || !areaFor(url.pathname)) return

    event.preventDefault()
    this.opener = link
    this.parentScroll = { x: window.scrollX, y: window.scrollY }
    this.pageTarget.dataset.waParentHref = window.location.href
    this.replacePage(url, this.linkTitle(link))
    this.dialogTarget.showModal()
  }

  linkTitle(link) {
    return link.getAttribute("aria-label") ||
      link.querySelector("strong")?.textContent || link.textContent.trim()
  }

  embeddedClick(event, link) {
    if (!eligibleLink(link, event)) return
    const url = new URL(link.href, location.href)
    if (!["http:", "https:"].includes(url.protocol)) return
    const parentHref = window.frameElement?.dataset.waParentHref
    const intent = intentFor(url, window.location.href, parentHref,
      link.hasAttribute("data-wa-page-dialog"), link.hasAttribute("download"))
    if (["LOCAL_ACTION", "LOCAL_WORKFLOW", "DOWNLOAD"].includes(intent)) return

    event.preventDefault()
    if (intent === "EXTERNAL_LINK") {
      window.open(url.href, "_blank", "noopener,noreferrer")
      return
    }
    this.notifyParent(intent, url, this.linkTitle(link))
  }

  embeddedVisit(event) {
    if (!event.detail?.url) return
    const url = new URL(event.detail.url, location.href)
    if (url.origin !== location.origin) return
    const intent = intentFor(url, window.location.href,
      window.frameElement?.dataset.waParentHref)
    if (intent === "LOCAL_ACTION" || intent === "LOCAL_WORKFLOW") return
    event.preventDefault()
    this.notifyParent(intent, url)
  }

  embeddedSubmit(event) {
    const form = event.target
    if (!event.detail?.success || !(form instanceof HTMLFormElement) ||
        form.method.toLowerCase() === "get") return
    // Only a successfully completed Turbo mutation can refresh parent projections.
    window.parent.postMessage({ type: "wa:dialog-write", path: location.pathname }, location.origin)
  }

  notifyParent(intent, url, title = "") {
    window.parent.postMessage({
      type: "wa:dialog-navigation", intent, href: url.href, title
    }, location.origin)
  }

  receiveMessage(event) {
    if (!this.hasPageTarget || !this.hasDialogTarget || !this.dialogTarget.open ||
        event.origin !== location.origin || event.source !== this.pageTarget.contentWindow) return
    const data = event.data
    if (data?.type === "wa:dialog-write") {
      this.refreshParentProjections()
      return
    }
    if (data?.type !== "wa:dialog-navigation" ||
        !["CLOSE_TO_PARENT", "REPLACE_MODAL", "NAVIGATE_PARENT"].includes(data.intent)) return
    if (typeof data.href !== "string") return
    const url = new URL(data.href, location.href)
    if (url.origin !== location.origin || !["http:", "https:"].includes(url.protocol)) return

    if (data.intent === "CLOSE_TO_PARENT") {
      if (sameParentDestination(url, this.pageTarget.dataset.waParentHref)) this.close()
    } else if (data.intent === "REPLACE_MODAL") {
      if (areaFor(url.pathname)) this.replacePage(url, data.title || this.headingTarget.textContent)
    } else {
      this.close(() => window.location.assign(url.href))
    }
  }

  replacePage(url, title) {
    this.headingTarget.textContent = title
    this.pageTarget.title = title
    this.pageTarget.src = url.href
  }

  // Refresh only explicitly marked, read-only summary projections, not the whole
  // parent document (its open details, focus, filters and scroll remain untouched).
  async refreshParentProjections() {
    const regions = [...document.querySelectorAll("[data-wa-dialog-refresh][id]")]
    if (!regions.length || this.refreshingProjections) return
    this.refreshingProjections = true
    try {
      const response = await fetch(location.href, {
        credentials: "same-origin", headers: { Accept: "text/html" }
      })
      if (!response.ok || !response.headers.get("content-type")?.includes("text/html")) return
      const fresh = new DOMParser().parseFromString(await response.text(), "text/html")
      for (const region of regions) {
        const replacement = fresh.getElementById(region.id)
        if (replacement?.hasAttribute("data-wa-dialog-refresh") && region.isConnected) {
          region.replaceWith(replacement)
        }
      }
      window.dispatchEvent(new CustomEvent("wa:dialog-updated"))
    } catch (_) {
      // A failed read-only projection update is not a successful form submission.
    } finally {
      this.refreshingProjections = false
    }
  }

  cancel(event) { event.preventDefault(); this.close() }
  backdrop(event) { if (event.target === this.dialogTarget) this.close() }

  close(afterClose) {
    if (!this.dialogTarget.open || this.closing) return
    this.closing = true
    const finish = () => {
      this.reset()
      if (typeof afterClose === "function") afterClose()
    }
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      finish()
    } else {
      this.dialogTarget.animate([{ opacity: 1 }, { opacity: 0 }],
        { duration: 160, easing: "ease-in" }).finished.catch(() => {}).then(finish)
    }
  }

  reset() {
    this.closing = false
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.hasPageTarget) {
      this.pageTarget.src = "about:blank"
      delete this.pageTarget.dataset.waParentHref
    }
    if (this.opener?.isConnected) this.opener.focus({ preventScroll: true })
    if (this.parentScroll && (window.scrollX !== this.parentScroll.x ||
        window.scrollY !== this.parentScroll.y)) {
      window.scrollTo(this.parentScroll.x, this.parentScroll.y)
    }
    this.opener = null
    this.parentScroll = null
  }
}
