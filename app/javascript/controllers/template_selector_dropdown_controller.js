import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector-dropdown"
export default class extends Controller {
  static targets = ["selector", "button", "loadingOverlay"];

  toggle(event) {
    if (this.buttonTarget.dataset.active === "false") {
      this.buttonTarget.dataset.active = "true";
      return;
    }

    event.preventDefault();
    this.close();
  }

  showLoadingOverlay() {
    this.loadingOverlayTarget.dataset.loading = "true";
  }

  close() {
    this.selectorTarget.innerHTML = "";
    this.buttonTarget.dataset.active = "false";
  }

  closeIfOutsideSelector(event) {
    // If clicked inside selector, return
    if (
      this.selectorTarget.contains(event.target) ||
      this.buttonTarget.contains(event.target)
    ) {
      return;
    }

    this.close();
  }
}
