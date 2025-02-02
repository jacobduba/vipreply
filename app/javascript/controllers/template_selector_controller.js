import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector"
export default class extends Controller {
  static targets = ["selector", "button"];

  toggle(event) {
    if (this.buttonTarget.dataset.active === "false") {
      this.buttonTarget.dataset.active = "true";
      return;
    }

    event.preventDefault();
    this.selectorTarget.innerHTML = "";
    this.buttonTarget.dataset.active = "false";
  }

  closeIfOutsideSelector(event) {
    // If did not click inside selector
    if (
      this.selectorTarget.contains(event.target) ||
      this.buttonTarget.contains(event.target)
    )
      return;

    this.selectorTarget.innerHTML = "";
    this.buttonTarget.dataset.active = "false";
  }

  beforeFetch(event) {
    event.preventDefault();

    if (this.buttonTarget.dataset.active === "false") {
      event.detail.resume();
    }
  }
}
