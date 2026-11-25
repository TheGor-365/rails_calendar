// One pending confirmation per document. No network, persistence or implicit consent.
const pending = new WeakMap()
const kinds = new Set(["discard", "overwrite", "destructive", "bulk", "archive", "paid"])

export function confirmationPending(doc) {
  return pending.has(doc)
}

export function requestConfirmation(doc, { kind, title, message, cancel, approve, isCurrent = () => true } = {}) {
  if (!doc || pending.has(doc) || !kinds.has(kind) ||
      ![title, message, cancel, approve].every(value => typeof value === "string" && value.trim()) ||
      typeof isCurrent !== "function") return Promise.resolve(false)

  const dialog = doc.querySelector("dialog.wa-confirm-dialog")
  const nodes = [dialog?.querySelector("#wa-discard-title"), dialog?.querySelector("#wa-discard-description"),
    dialog?.querySelector("[data-wa-page-dialog-target='keepEditing']"),
    dialog?.querySelector("[data-action='wa-page-dialog#confirmDiscard']")]
  if (!dialog?.isConnected || dialog.open || nodes.some(node => !node)) return Promise.resolve(false)
  try { if (!isCurrent()) return Promise.resolve(false) } catch (_) { return Promise.resolve(false) }

  return new Promise(resolve => {
    const opener = doc.activeElement
    const original = nodes.map(node => node.textContent)
    const onClose = () => { if (!dialog.open) finish(false) }
    const onCache = () => finish(false)
    const finish = approved => {
      if (pending.get(doc)?.finish !== finish) return
      pending.delete(doc)
      dialog.removeEventListener("close", onClose)
      doc.removeEventListener("turbo:before-cache", onCache)
      let accepted = false
      try {
        accepted = approved === true && dialog.open && dialog.isConnected && isCurrent() === true
        if (dialog.open) dialog.close()
      } catch (_) { accepted = false }
      finally {
        nodes.forEach((node, i) => { node.textContent = original[i] })
        delete dialog.dataset.waConfirmKind
        if (!accepted && opener?.isConnected) {
          try { opener.focus({ preventScroll: true }) } catch (_) {}
        }
        resolve(accepted)
      }
    }
    pending.set(doc, { finish, dialog })
    try {
      nodes.forEach((node, i) => { node.textContent = [title, message, cancel, approve][i] })
      dialog.dataset.waConfirmKind = kind
      dialog.addEventListener("close", onClose)
      doc.addEventListener("turbo:before-cache", onCache)
      dialog.showModal()
      nodes[2].focus()
    } catch (_) { finish(false) }
  })
}

// Only the active dialog may resolve its own request.
export function settleConfirmation(dialog, approved = false) {
  const request = dialog && pending.get(dialog.ownerDocument)
  if (request?.dialog === dialog) request.finish(approved)
}
