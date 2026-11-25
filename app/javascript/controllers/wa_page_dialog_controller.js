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
  static targets = ["dialog", "heading", "page", "backButton", "trail", "confirmation", "keepEditing"]

  connect() {
    this.embedded = window.parent !== window &&
      window.frameElement?.hasAttribute("data-wa-embedded-page")
    this.onClick = event => this.openLink(event)
    this.element.addEventListener("click", this.onClick)
    this.beforeCache = () => { if (!this.embedded) this.reset() }
    document.addEventListener("turbo:before-cache", this.beforeCache)

    if (this.embedded) {
      document.documentElement.classList.add("wa-embedded-page")
      this.dirtyForms = new Set()
      this.pendingForms = new Set()
      this.onEdit = event => this.trackEdit(event)
      this.onSubmitStart = event => this.trackSubmitStart(event)
      this.element.addEventListener("input", this.onEdit, true)
      this.element.addEventListener("change", this.onEdit, true)
      document.addEventListener("turbo:submit-start", this.onSubmitStart)
      this.beforeVisit = event => this.embeddedVisit(event)
      this.afterSubmit = event => this.embeddedSubmit(event)
      document.addEventListener("turbo:before-visit", this.beforeVisit)
      document.addEventListener("turbo:submit-end", this.afterSubmit)
      this.onCommitted = () => this.reportCommittedPage()
      this.onScroll = () => this.reportScroll()
      window.addEventListener("scroll", this.onScroll, { passive: true })
      document.addEventListener("turbo:load", this.onCommitted)
      // A server-rendered invalid consultation remains an unsaved draft.
      const invalidForms = document.querySelectorAll("form[data-wa-invalid-draft=true], form:has(#consultation-form-errors)")
      for (const form of invalidForms) this.dirtyForms.add(form)
      this.publishFormState()
      this.reportCommittedPage()
    } else {
      this.onMessage = event => this.receiveMessage(event)
      window.addEventListener("message", this.onMessage)
    }
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    if (this.embedded) {
      this.element.removeEventListener("input", this.onEdit, true)
      this.element.removeEventListener("change", this.onEdit, true)
      document.removeEventListener("turbo:submit-start", this.onSubmitStart)
      document.removeEventListener("turbo:before-visit", this.beforeVisit)
      document.removeEventListener("turbo:submit-end", this.afterSubmit)
      document.removeEventListener("turbo:load", this.onCommitted)
      window.removeEventListener("scroll", this.onScroll)
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
    this.stack = []
    this.dialogTarget.showModal()
    this.replacePage(url, this.linkTitle(link))
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
    if (["LOCAL_ACTION", "DOWNLOAD"].includes(intent)) return
    if (intent === "LOCAL_WORKFLOW" && link.getAttribute("data-turbo") !== "false" &&
        !link.closest('[data-turbo="false"]')) return
    // Ordinary non-Turbo GET links use the same parent navigation guard.
    if (intent === "LOCAL_WORKFLOW") {
      event.preventDefault()
      this.notifyParent("REPLACE_MODAL", url, this.linkTitle(link))
      return
    }

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
    if (intent === "LOCAL_ACTION") return
    if (intent === "LOCAL_WORKFLOW") {
      if (this.pendingForms.size > 0) {
        event.preventDefault()
      } else if (this.dirtyForms.size > 0) {
        event.preventDefault()
        this.notifyParent("REPLACE_MODAL", url)
      }
      return
    }
    event.preventDefault()
    this.notifyParent(intent, url)
  }

  mutationForm(form) {
    return form instanceof HTMLFormElement && form.method.toLowerCase() !== "get"
  }

  trackEdit(event) {
    const field = event.target
    if (!field?.matches?.("input, textarea, select") || !this.mutationForm(field.form)) return
    if (["hidden", "submit", "button", "reset"].includes(field.type)) return
    this.dirtyForms.add(field.form)
    this.publishFormState()
  }

  trackSubmitStart(event) {
    if (!this.mutationForm(event.target)) return
    this.pendingForms.add(event.target)
    const frame = window.frameElement
    if (frame) frame.dataset.waMutationSource = location.href
    this.publishFormState()
  }

  publishFormState() {
    const frame = window.frameElement
    if (!frame) return
    frame.dataset.waDirty = String(this.dirtyForms.size > 0)
    frame.dataset.waSubmitting = String(this.pendingForms.size > 0)
  }

  async allowDeparture() {
    const frame = this.pageTarget
    if (this.discardResolver || frame.dataset.waSubmitting === "true") return false
    if (frame.dataset.waDirty !== "true") return true
    if (!this.hasConfirmationTarget) return false
    const source = frame.contentDocument
    const approved = await new Promise(resolve => {
      this.discardResolver = resolve
      this.confirmationTarget.showModal()
      this.keepEditingTarget.focus()
    })
    return approved && this.dialogTarget.open && source === frame.contentDocument &&
      frame.dataset.waSubmitting !== "true"
  }

  finishDiscard(approved) {
    const resolve = this.discardResolver
    this.discardResolver = null
    if (this.hasConfirmationTarget && this.confirmationTarget.open) this.confirmationTarget.close()
    if (resolve) resolve(approved)
  }

  cancelDiscard(event) {
    event?.preventDefault()
    this.finishDiscard(false)
  }

  confirmDiscard() { this.finishDiscard(true) }

  discardBackdrop(event) {
    if (event.target === this.confirmationTarget) this.finishDiscard(false)
  }

  embeddedSubmit(event) {
    const form = event.detail?.formSubmission?.formElement || event.target
    if (!this.mutationForm(form)) return
    this.pendingForms.delete(form)
    // Transport success is not proof of persistence. The committed server page
    // supplies the outcome for instrumented workflows.
    if (event.detail?.success && !form.isConnected) this.dirtyForms.delete(form)
    this.publishFormState()
    if (!event.detail?.success) {
      const frame = window.frameElement
      if (frame) delete frame.dataset.waMutationSource
    }
  }

  reportCommittedPage() {
    const heading = document.querySelector("main [data-wa-banner] h1, main h1")
    window.parent.postMessage({
      type: "wa:dialog-committed", href: location.href,
      title: heading?.textContent.trim() || document.title,
      outcome: document.querySelector("main[data-wa-dialog-outcome]")?.dataset.waDialogOutcome || ""
    }, location.origin)
  }

  reportScroll() {
    window.parent.postMessage({
      type: "wa:dialog-scroll", href: location.href, x: window.scrollX, y: window.scrollY
    }, location.origin)
  }

  notifyParent(intent, url, title = "") {
    window.parent.postMessage({
      type: "wa:dialog-navigation", intent, href: url.href, title
    }, location.origin)
  }

  async receiveMessage(event) {
    if (!this.hasPageTarget || !this.hasDialogTarget || !this.dialogTarget.open ||
        event.origin !== location.origin || event.source !== this.pageTarget.contentWindow) return
    const data = event.data
    if (data?.type === "wa:dialog-scroll") {
      const current = this.stack?.at(-1)
      if (current && data.href === current.href && !this.pendingRestore &&
          Number.isFinite(data.x) && Number.isFinite(data.y)) {
        current.scroll = { x: Math.max(0, data.x), y: Math.max(0, data.y) }
      }
      return
    }
    if (data?.type === "wa:dialog-committed") {
      this.acceptCommittedPage(data)
      return
    }
    if (data?.type !== "wa:dialog-navigation" ||
        !["CLOSE_TO_PARENT", "REPLACE_MODAL", "NAVIGATE_PARENT"].includes(data.intent)) return
    if (typeof data.href !== "string") return
    let url
    try { url = new URL(data.href, location.href) } catch (_) { return }
    if (url.origin !== location.origin || !["http:", "https:"].includes(url.protocol)) return

    if (data.intent === "CLOSE_TO_PARENT") {
      if (sameParentDestination(url, this.pageTarget.dataset.waParentHref)) this.close()
    } else if (data.intent === "REPLACE_MODAL") {
      if (!this.navigationPending && areaFor(url.pathname) && await this.allowDeparture() && this.dialogTarget.open && !this.closing && !this.navigationPending) this.replacePage(url, data.title || this.headingTarget.textContent)
    } else {
      this.close(() => window.location.assign(url.href))
    }
  }

  pageKey(url) { return url.pathname + url.search }

  // Interview steps are local wizard tabs, not independent modal levels.
  // Keep the actual URL for stale-message checks and returning to the last step.
  historyKey(url) {
    if (/^\/workspace\/setup\/?$/.test(url.pathname)) return "/workspace/setup"
    return this.pageKey(url)
  }

  acceptCommittedPage(data) {
    if (typeof data.href !== "string") return
    let url
    try { url = new URL(data.href) } catch (_) { return }
    if (url.origin !== location.origin) return
    // Ignore stale messages from a document which has already navigated.
    try {
      if (this.pageKey(new URL(this.pageTarget.contentWindow.location.href)) !== this.pageKey(url)) return
    } catch (_) { return }
    this.clearNavigationTimer()
    const source = this.pageTarget.dataset.waMutationSource
    const outcome = source && ["advance", "replace"].includes(data.outcome) ? data.outcome : ""
    if (outcome) {
      delete this.pageTarget.dataset.waMutationSource
      this.pageTarget.dataset.waSubmitting = "false"
      this.refreshParentProjections()
    }
    if (sameParentDestination(url, this.pageTarget.dataset.waParentHref)) {
      this.close()
      return
    }
    if (!areaFor(url.pathname)) {
      // Only recognized top-level GET destinations can escape after a server
      // redirect. Unknown URLs may be mutation endpoints rendering errors.
      const topLevel = /^\/(?:sign_in|admin\/login|workspace|workspace\/cabinet|client|client\/cabinet|calendar\/day|services)?\/?$/.test(url.pathname)
      if (source) delete this.pageTarget.dataset.waMutationSource
      if (topLevel) this.close(() => window.location.assign(url.href))
      return
    }
    if (source) delete this.pageTarget.dataset.waMutationSource
    const title = typeof data.title === "string" ? data.title.slice(0, 180) : ""
    if (outcome === "replace" && this.stack?.at(-1)?.href === source) this.stack.pop()
    this.recordPage(url, title)
  }

  recordPage(url, title) {
    this.stack ||= []
    const key = this.historyKey(url)
    const existing = this.stack.findIndex(entry => entry.key === key)
    const entry = { key, href: url.href, title: title || this.headingTarget.textContent || document.title,
      scroll: existing >= 0 && this.stack[existing].href === url.href ? this.stack[existing].scroll : { x: 0, y: 0 } }
    if (existing >= 0) this.stack.splice(existing, this.stack.length - existing, entry)
    else this.stack.push(entry)
    if (this.stack.length > 40) this.stack.shift()
    this.headingTarget.textContent = entry.title
    this.pageTarget.title = entry.title
    if (this.hasBackButtonTarget) this.backButtonTarget.disabled = this.stack.length < 2
    this.renderTrail()
    const restore = this.pendingRestore
    if (restore) {
      this.pendingRestore = null
      if (restore.key === key) {
        const frame = this.pageTarget.contentWindow
        frame.requestAnimationFrame(() => {
          try {
            if (this.dialogTarget.open && this.pageKey(new URL(frame.location.href)) === restore.pageKey) {
              frame.scrollTo(restore.scroll.x, restore.scroll.y)
            }
          } catch (_) {}
        })
      }
    }
  }

  renderTrail() {
    if (!this.hasTrailTarget) return
    this.trailTarget.replaceChildren()
    this.trailTarget.hidden = !this.stack?.length || this.stack.length < 2
    if (this.trailTarget.hidden) return
    this.stack.forEach((entry, index) => {
      const current = index === this.stack.length - 1
      const item = document.createElement(current ? "span" : "button")
      item.className = "wa-page-dialog__crumb"
      item.textContent = entry.title
      if (current) item.setAttribute("aria-current", "page")
      else {
        item.type = "button"
        item.addEventListener("click", () => this.jumpTo(index))
      }
      this.trailTarget.append(item)
    })
  }

  async jumpTo(index) {
    if (!this.dialogTarget.open || this.closing || this.navigationPending ||
        !this.stack || index < 0 || index >= this.stack.length - 1) return
    const entry = this.stack[index]
    if (!(await this.allowDeparture()) || !this.dialogTarget.open || this.closing || this.navigationPending || this.stack[index] !== entry) return
    this.pendingRestore = { key: entry.key, pageKey: this.pageKey(new URL(entry.href)), scroll: entry.scroll || { x: 0, y: 0 } }
    this.replacePage(new URL(entry.href), entry.title)
  }

  replacePage(url, title) {
    // The committed document, not a clicked link, becomes a history entry.
    this.clearNavigationTimer()
    this.navigationPending = true
    this.headingTarget.textContent = title
    this.pageTarget.title = title
    if (this.hasBackButtonTarget) this.backButtonTarget.disabled = true
    if (this.hasTrailTarget) this.trailTarget.querySelectorAll("button").forEach(button => { button.disabled = true })
    this.navigationTimer = window.setTimeout(() => {
      this.navigationPending = false
      this.pendingRestore = null
      this.navigationTimer = null
      if (!this.dialogTarget.open) return
      const last = this.stack?.at(-1)
      if (last) {
        this.headingTarget.textContent = last.title
        this.pageTarget.title = last.title
      }
      if (this.hasBackButtonTarget) this.backButtonTarget.disabled = (this.stack?.length || 0) < 2
      this.renderTrail()
    }, 15000)
    this.pageTarget.src = url.href
  }

  clearNavigationTimer() {
    if (this.navigationTimer != null) window.clearTimeout(this.navigationTimer)
    this.navigationTimer = null
    this.navigationPending = false
  }

  back() {
    // Explicit GET only; never use iframe browser history which may replay a form.
    this.jumpTo((this.stack?.length || 0) - 2)
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

  async close(afterClose) {
    if (!this.dialogTarget.open || this.closing || !(await this.allowDeparture()) || !this.dialogTarget.open || this.closing) return
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
    this.finishDiscard(false)
    this.closing = false
    this.clearNavigationTimer()
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.hasPageTarget) {
      this.pageTarget.src = "about:blank"
      delete this.pageTarget.dataset.waParentHref
      delete this.pageTarget.dataset.waDirty
      delete this.pageTarget.dataset.waSubmitting
      delete this.pageTarget.dataset.waMutationSource
    }
    if (this.opener?.isConnected) this.opener.focus({ preventScroll: true })
    else if (this.opener) document.getElementById("main-content")?.focus({ preventScroll: true })
    if (this.parentScroll && (window.scrollX !== this.parentScroll.x ||
        window.scrollY !== this.parentScroll.y)) {
      window.scrollTo(this.parentScroll.x, this.parentScroll.y)
    }
    this.opener = null
    this.parentScroll = null
    this.stack = []
    this.pendingRestore = null
    this.renderTrail()
    if (this.hasBackButtonTarget) this.backButtonTarget.disabled = true
  }
}
