import { Controller } from "@hotwired/stimulus"

// E2 owner-only, consent-gated AI: generate -> review stored draft -> explicit apply.
// Never sends requests on connect or on option selection. Text is rendered safely.
export default class extends Controller {
  static targets = ["generate", "consent", "status", "result", "heading", "draft",
    "questions", "cautions", "nextStep", "reviewLink", "apply"]
  static values = { url: String }

  async generate(event) {
    event.preventDefault()
    if (!this.hasConsentTarget || !this.consentTarget.checked) {
      this.notify(this.element.dataset.consentRequired || "Explicit paid consent is required.", true)
      return
    }
    const form = this.element.closest("form")
    const selected = this.element.querySelector('input[name="ai_operation"]:checked')
    if (!form || !selected || !this.hasUrlValue) return

    const params = new FormData()
    params.set("operation", selected.value)
    params.set("paid_consent", "1")
    params.set("seed_title", form.querySelector("#proposal_seed_title")?.value?.trim() || "")
    params.set("seed_goal", form.querySelector("#proposal_seed_goal")?.value?.trim() || "")

    form.querySelectorAll("[data-wa-brief-choice]:checked").forEach(input => {
      const match = input.name.match(/^proposal\[brief_selections\]\[([a-z_]+)\]\[\]$/)
      if (match) params.append(`brief_selections[${match[1]}][]`, input.value)
    })

    form.querySelectorAll('input[name="service_version_ids[]"]:checked').forEach(input => {
      params.append("service_version_ids[]", input.value)
    })

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    this.generateTarget.disabled = true
    this.notify(this.element.dataset.generating || "Generating a private AI draft...", false)
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "same-origin",
        headers: { "X-CSRF-Token": csrf || "", "Accept": "application/json" },
        body: params
      })
      const payload = await response.json()
      if (!response.ok) {
        const errorName = payload.error || "provider_unavailable"
        this.notify(this.element.dataset[errorName.replace(/_([a-z])/g, (_all, c) => c.toUpperCase())] ||
          this.element.dataset.unavailable || "AI draft unavailable; the form is unchanged.", true)
        return
      }
      this.renderResult(payload)
      this.notify(this.element.dataset.saved || "AI draft saved for owner review.", false)
      this.resultTarget.scrollIntoView({ block: "nearest", behavior: "smooth" })
    } catch (_error) {
      this.notify(this.element.dataset.unavailable || "AI draft unavailable; the form is unchanged.", true)
    } finally {
      this.generateTarget.disabled = false
      // Fresh, explicit consent for each new request.
      this.consentTarget.checked = false
    }
  }

  renderResult(data) {
    this.headingTarget.textContent = data.heading || ""
    this.draftTarget.textContent = data.draft || ""
    this.nextStepTarget.textContent = data.next_step || ""
    this.populate(this.questionsTarget, data.questions)
    this.populate(this.cautionsTarget, data.cautions)
    if (data.review_url?.startsWith("/workspace/assistant")) {
      this.reviewLinkTarget.href = data.review_url
      this.reviewLinkTarget.hidden = false
    }
    this.resultTarget.hidden = false
    this.applyTarget.disabled = !data.draft?.trim()
    const linkedEntry = this.element.closest("form")?.querySelector("#proposal_owner_ai_entry_id")
    if (linkedEntry && Number.isInteger(data.id) && data.id > 0) linkedEntry.value = String(data.id)
  }

  populate(node, lines) {
    node.replaceChildren()
    for (const line of (Array.isArray(lines) ? lines : [])) {
      const li = document.createElement("li")
      li.textContent = String(line)
      node.append(li)
    }
    node.hidden = node.childElementCount === 0
  }

  apply(event) {
    event.preventDefault()
    const form = this.element.closest("form")
    const input = form?.querySelector("#proposal_seed_goal")
    if (!input || !this.hasDraftTarget) return
    const text = this.draftTarget.textContent.trim()
    if (text.length < 10 || text.length > 1200) {
      this.notify(this.element.dataset.tooLong || "AI text exceeds the field limit. Review the saved draft.", true)
      return
    }
    if (input.value.trim() && !window.confirm(this.element.dataset.replaceConfirm ||
        "Replace the current description? The existing text will be overwritten in this form.")) return
    input.value = text
    input.dataset.waGenerated = "false"
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.notify(this.element.dataset.applied || "Added to the form. Review before issuing the invitation.", false)
    input.focus()
  }

  useClientPreview(event) {
    event.preventDefault()
    const form = this.element.closest("form")
    const field = form?.querySelector("#proposal_approved_client_preview")
    const check = form?.querySelector("#proposal_share_preview")
    if (!field || !check) return
    const heading = this.headingTarget.textContent.trim()
    const draft = this.draftTarget.textContent.trim()
    const questions = Array.from(this.questionsTarget.children).map(node => node.textContent.trim())
    const proposal = [heading, draft, ...questions.map((q, i) => `${i + 1}. ${q}`)].filter(Boolean).join("\n\n")
    if (proposal.length > 1200) {
      this.notify(this.element.dataset.tooLong || "Reduce the AI result to 1200 characters first.", true)
      field.focus()
      return
    }
    if (field.value.trim() && !window.confirm(this.element.dataset.replaceConfirm ||
        "Replace the client preview with this reviewed AI text?")) return
    field.value = proposal
    field.dispatchEvent(new Event("input", { bubbles: true }))
    // A separate explicit checkbox is required before the text is shared.
    check.checked = false
    field.focus()
    this.notify(this.element.dataset.previewReady || "Review this preview and check the sharing confirmation.", false)
  }

  notify(message, error) {
    this.statusTarget.textContent = message
    this.statusTarget.dataset.error = error ? "true" : "false"
  }
}
