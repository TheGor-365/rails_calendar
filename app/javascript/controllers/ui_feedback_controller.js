import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for existing Turbo forms. Status is not invented:
// Rails continues to render its own flash/error messages on the response.
export default class extends Controller {
  start(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    form.classList.add("rc-turbo-pending")
    form.setAttribute("aria-busy", "true")
  }

  finish(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    form.classList.remove("rc-turbo-pending")
    form.removeAttribute("aria-busy")
  }

  reset() {
    this.element.querySelectorAll("form.rc-turbo-pending").forEach((form) => {
      form.classList.remove("rc-turbo-pending")
      form.removeAttribute("aria-busy")
    })
  }
}
