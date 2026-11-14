import { Controller } from "@hotwired/stimulus"

// Select-only combobox enhancement for White Atlas. The original <select> is
// the canonical form control; this adds a completely themed, keyboard-operated
// listbox without changing Rails form names, validation or submitted values.
// Menus are portalled to <body> to avoid clipping inside cards and <details>.
let nextSelectId = 0

export default class extends Controller {
  connect() {
    this.items = new Map()
    this.current = null
    this.onPointerDown = this.onPointerDown.bind(this)
    this.onDocumentKeyDown = this.onDocumentKeyDown.bind(this)
    this.onReposition = this.onReposition.bind(this)
    this.teardown = this.teardown.bind(this)

    this.observer = new MutationObserver(() => this.enhance())
    this.observer.observe(this.element, { childList: true, subtree: true })
    document.addEventListener("pointerdown", this.onPointerDown, true)
    document.addEventListener("keydown", this.onDocumentKeyDown)
    document.addEventListener("turbo:before-cache", this.teardown)
    window.addEventListener("resize", this.onReposition)
    window.addEventListener("scroll", this.onReposition, true)
    this.enhance()
  }

  disconnect() {
    this.teardown()
  }

  enhance() {
    this.element.querySelectorAll("select:not([multiple])").forEach((select) => {
      if (select.dataset.rcSelectEnhanced || select.size > 1) return
      this.enhanceSelect(select)
    })
  }

  enhanceSelect(select) {
    const id = ++nextSelectId
    if (!select.id) select.id = `rc-select-native-${id}`

    const label = select.labels && select.labels.length ? select.labels[0] : null
    if (label && !label.id) label.id = `rc-select-label-${id}`

    const wrap = document.createElement("div")
    wrap.className = "rc-select"
    select.parentNode.insertBefore(wrap, select)
    wrap.appendChild(select)

    const trigger = document.createElement("button")
    trigger.type = "button"
    trigger.id = `rc-select-trigger-${id}`
    trigger.className = `${select.className} rc-select-trigger`
    trigger.setAttribute("role", "combobox")
    trigger.setAttribute("aria-haspopup", "listbox")
    trigger.setAttribute("aria-expanded", "false")
    trigger.setAttribute("aria-controls", `rc-select-menu-${id}`)
    if (select.required) trigger.setAttribute("aria-required", "true")

    const display = document.createElement("span")
    display.id = `rc-select-display-${id}`
    display.className = "rc-select-display"
    const caret = document.createElement("i")
    caret.className = "bi bi-chevron-down rc-select-caret"
    caret.setAttribute("aria-hidden", "true")
    trigger.append(display, caret)
    if (label) {
      trigger.setAttribute("aria-labelledby", `${label.id} ${display.id}`)
    } else {
      trigger.setAttribute("aria-label", select.getAttribute("aria-label") || select.name || "Choose")
    }
    wrap.appendChild(trigger)

    const menu = document.createElement("div")
    menu.id = `rc-select-menu-${id}`
    menu.className = "rc-select-menu"
    menu.setAttribute("role", "listbox")
    menu.setAttribute("aria-labelledby", label ? label.id : display.id)
    menu.hidden = true
    document.body.appendChild(menu)

    const original = {
      tabindex: select.getAttribute("tabindex"),
      ariaHidden: select.getAttribute("aria-hidden"),
      idGenerated: select.id === `rc-select-native-${id}`
    }
    select.classList.add("rc-select-native")
    select.dataset.rcSelectEnhanced = "1"
    select.setAttribute("aria-hidden", "true")
    select.tabIndex = -1

    const entry = { select, label, wrap, trigger, display, menu, original,
                    optionElements: [], activeIndex: -1, search: "", searchedAt: 0 }
    entry.onTriggerClick = () => this.current === entry ? this.close() : this.open(entry)
    entry.onTriggerKeyDown = (event) => this.onTriggerKeyDown(event, entry)
    entry.onSelectChange = () => this.sync(entry)
    entry.onSelectInvalid = (event) => {
      event.preventDefault()
      trigger.setAttribute("aria-invalid", "true")
      trigger.focus()
      this.open(entry)
    }
    entry.onReset = () => queueMicrotask(() => this.sync(entry))
    entry.onLabelClick = (event) => {
      if (select.disabled) return
      event.preventDefault()
      trigger.focus()
      if (this.current !== entry) this.open(entry)
    }
    entry.onMenuClick = (event) => {
      const target = event.target.closest('[role="option"]')
      if (!target || !menu.contains(target)) return
      this.commit(entry, Number(target.dataset.index))
    }
    entry.onMenuPointerDown = (event) => event.preventDefault()

    trigger.addEventListener("click", entry.onTriggerClick)
    trigger.addEventListener("keydown", entry.onTriggerKeyDown)
    select.addEventListener("change", entry.onSelectChange)
    select.addEventListener("invalid", entry.onSelectInvalid)
    select.form?.addEventListener("reset", entry.onReset)
    label?.addEventListener("click", entry.onLabelClick)
    menu.addEventListener("click", entry.onMenuClick)
    menu.addEventListener("pointerdown", entry.onMenuPointerDown)
    this.items.set(select, entry)
    this.sync(entry)
  }

  sync(entry) {
    const { select, trigger, display } = entry
    const selected = select.selectedOptions[0]
    display.textContent = selected ? selected.textContent.trim() : ""
    const placeholder = !selected || selected.value === ""
    trigger.classList.toggle("is-placeholder", placeholder)
    trigger.disabled = select.disabled
    trigger.setAttribute("aria-disabled", String(select.disabled))
    if (select.validity.valid) trigger.removeAttribute("aria-invalid")
    if (this.current === entry) {
      this.buildOptions(entry)
      this.position(entry)
    }
  }

  buildOptions(entry) {
    const { select, menu } = entry
    menu.replaceChildren()
    entry.optionElements = []
    Array.from(select.options).forEach((option, index) => {
      if (option.hidden) return
      const item = document.createElement("div")
      item.id = `${menu.id}-option-${index}`
      item.className = "rc-select-option"
      item.textContent = option.textContent.trim()
      item.dataset.index = String(index)
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", String(option.selected))
      if (option.disabled) {
        item.setAttribute("aria-disabled", "true")
        item.classList.add("is-disabled")
      }
      if (option.value === "") item.classList.add("is-placeholder")
      if (option.parentElement?.tagName === "OPTGROUP") {
        item.setAttribute("aria-label", `${option.parentElement.label}: ${item.textContent}`)
      }
      menu.appendChild(item)
      entry.optionElements.push(item)
    })
    entry.activeIndex = entry.optionElements.findIndex((item) =>
      Number(item.dataset.index) === select.selectedIndex && !this.disabledOption(entry, item))
    if (entry.activeIndex < 0) entry.activeIndex = this.firstEnabled(entry)
    this.markActive(entry)
  }

  disabledOption(entry, item) {
    const opt = entry.select.options[Number(item.dataset.index)]
    return !opt || opt.disabled || !!opt.parentElement?.disabled
  }

  firstEnabled(entry, fromEnd = false) {
    const elements = entry.optionElements
    const indices = elements.map((_, index) => index)
    if (fromEnd) indices.reverse()
    return indices.find((index) => !this.disabledOption(entry, elements[index])) ?? -1
  }

  open(entry) {
    if (entry.select.disabled) return
    if (this.current && this.current !== entry) this.close()
    this.current = entry
    this.buildOptions(entry)
    entry.menu.hidden = false
    entry.wrap.classList.add("is-open")
    entry.trigger.setAttribute("aria-expanded", "true")
    this.position(entry)
    this.markActive(entry)
    this.scrollActive(entry)
  }

  close({ focus = false } = {}) {
    const entry = this.current
    if (!entry) return
    entry.menu.hidden = true
    entry.wrap.classList.remove("is-open")
    entry.trigger.setAttribute("aria-expanded", "false")
    entry.trigger.removeAttribute("aria-activedescendant")
    entry.search = ""
    this.current = null
    if (focus) entry.trigger.focus()
  }

  position(entry) {
    if (entry.menu.hidden) return
    const rect = entry.trigger.getBoundingClientRect()
    if (rect.bottom < 0 || rect.top > window.innerHeight) {
      this.close()
      return
    }
    const gap = 6
    const margin = 9
    const maxWidth = Math.max(100, window.innerWidth - margin * 2)
    const width = Math.min(Math.max(rect.width, 160), maxWidth)
    const left = Math.max(margin, Math.min(rect.left, window.innerWidth - margin - width))
    const below = Math.max(0, window.innerHeight - rect.bottom - margin - gap)
    const above = Math.max(0, rect.top - margin - gap)
    const flip = below < 190 && above > below
    const available = flip ? above : below
    entry.menu.style.width = `${width}px`
    entry.menu.style.left = `${left}px`
    entry.menu.style.maxHeight = `${Math.min(310, Math.max(66, available))}px`
    entry.menu.style.top = flip
      ? `${Math.max(margin, rect.top - entry.menu.getBoundingClientRect().height - gap)}px`
      : `${rect.bottom + gap}px`
  }

  move(entry, direction) {
    const total = entry.optionElements.length
    if (!total) return
    let at = entry.activeIndex
    for (let n = 0; n < total; n++) {
      at = (at + direction + total) % total
      if (!this.disabledOption(entry, entry.optionElements[at])) {
        entry.activeIndex = at
        this.markActive(entry)
        this.scrollActive(entry)
        return
      }
    }
  }

  markActive(entry) {
    entry.optionElements.forEach((item, index) => {
      item.classList.toggle("is-active", index === entry.activeIndex)
      const option = entry.select.options[Number(item.dataset.index)]
      item.setAttribute("aria-selected", String(!!option?.selected))
    })
    const active = entry.optionElements[entry.activeIndex]
    if (active) entry.trigger.setAttribute("aria-activedescendant", active.id)
    else entry.trigger.removeAttribute("aria-activedescendant")
  }

  scrollActive(entry) {
    const active = entry.optionElements[entry.activeIndex]
    if (!active) return
    const optionTop = active.offsetTop
    const optionBottom = optionTop + active.offsetHeight
    if (optionTop < entry.menu.scrollTop) entry.menu.scrollTop = optionTop
    else if (optionBottom > entry.menu.scrollTop + entry.menu.clientHeight)
      entry.menu.scrollTop = optionBottom - entry.menu.clientHeight
  }

  commit(entry, index) {
    const option = entry.select.options[index]
    if (!option || option.hidden || option.disabled || option.parentElement?.disabled) return
    const changed = entry.select.selectedIndex !== index
    entry.select.selectedIndex = index
    if (changed) {
      entry.select.dispatchEvent(new Event("input", { bubbles: true }))
      entry.select.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.sync(entry)
    this.close({ focus: true })
  }

  onTriggerKeyDown(event, entry) {
    const key = event.key
    if (key === "Tab") {
      this.close()
      return
    }
    if (key === "Escape") {
      if (this.current === entry) {
        event.preventDefault()
        this.close({ focus: true })
      }
      return
    }
    if (key === "ArrowDown" || key === "ArrowUp") {
      event.preventDefault()
      if (this.current !== entry) this.open(entry)
      else this.move(entry, key === "ArrowDown" ? 1 : -1)
      return
    }
    if (key === "Home" || key === "End") {
      event.preventDefault()
      if (this.current !== entry) this.open(entry)
      entry.activeIndex = this.firstEnabled(entry, key === "End")
      this.markActive(entry)
      this.scrollActive(entry)
      return
    }
    if (key === "Enter" || key === " ") {
      event.preventDefault()
      if (this.current === entry) {
        const item = entry.optionElements[entry.activeIndex]
        if (item) this.commit(entry, Number(item.dataset.index))
      } else this.open(entry)
      return
    }
    if (key.length === 1 && !event.altKey && !event.ctrlKey && !event.metaKey) {
      event.preventDefault()
      if (this.current !== entry) this.open(entry)
      const now = Date.now()
      entry.search = now - entry.searchedAt > 700 ? key.toLocaleLowerCase() : entry.search + key.toLocaleLowerCase()
      entry.searchedAt = now
      const found = entry.optionElements.findIndex((item) =>
        !this.disabledOption(entry, item) && item.textContent.toLocaleLowerCase().startsWith(entry.search))
      if (found >= 0) {
        entry.activeIndex = found
        this.markActive(entry)
        this.scrollActive(entry)
      }
    }
  }

  onPointerDown(event) {
    if (!this.current) return
    if (this.current.wrap.contains(event.target) || this.current.menu.contains(event.target)) return
    this.close()
  }

  onDocumentKeyDown(event) {
    if (event.key !== "Escape") return
    if (this.current) {
      event.preventDefault()
      this.close({ focus: true })
    }
    // The language menu is already a themed <details>; make it dismissible.
    document.querySelectorAll("details.rc-locale-switcher[open]").forEach((details) => {
      details.open = false
      details.querySelector("summary")?.focus()
    })
  }

  onReposition(event) {
    if (!this.current) return
    if (this.current.menu.contains(event.target)) return
    this.position(this.current)
  }

  teardown() {
    this.observer?.disconnect()
    document.removeEventListener("pointerdown", this.onPointerDown, true)
    document.removeEventListener("keydown", this.onDocumentKeyDown)
    document.removeEventListener("turbo:before-cache", this.teardown)
    window.removeEventListener("resize", this.onReposition)
    window.removeEventListener("scroll", this.onReposition, true)
    this.close()
    if (!this.items) return
    this.items.forEach((entry) => {
      const { select, label, wrap, trigger, menu, original } = entry
      trigger.removeEventListener("click", entry.onTriggerClick)
      trigger.removeEventListener("keydown", entry.onTriggerKeyDown)
      select.removeEventListener("change", entry.onSelectChange)
      select.removeEventListener("invalid", entry.onSelectInvalid)
      select.form?.removeEventListener("reset", entry.onReset)
      label?.removeEventListener("click", entry.onLabelClick)
      menu.remove()
      select.classList.remove("rc-select-native")
      delete select.dataset.rcSelectEnhanced
      if (original.tabindex === null) select.removeAttribute("tabindex")
      else select.setAttribute("tabindex", original.tabindex)
      if (original.ariaHidden === null) select.removeAttribute("aria-hidden")
      else select.setAttribute("aria-hidden", original.ariaHidden)
      if (original.idGenerated) select.removeAttribute("id")
      if (wrap.contains(select)) wrap.replaceWith(select)
    })
    this.items.clear()
  }
}
