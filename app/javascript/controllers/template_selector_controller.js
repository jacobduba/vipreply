import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector"
export default class extends Controller {
  static targets = ["selector", "button"];

  toggle(event) {
    if (this.selectorIsClosed()) return;

    if (!this.selectorTarget.contains(event.target)) {
      this.selectorTarget.innerHTML = "";
    }
  }

  beforeFetch(event) {
    event.preventDefault();

    if (this.selectorIsClosed()) {
      event.detail.resume();
    }
  }

  selectorIsClosed() {
    return this.selectorTarget.innerHTML.trim() === "";
  }
}
