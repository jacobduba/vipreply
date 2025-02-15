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
    this.selectorTarget.innerHTML = "";
    this.buttonTarget.dataset.active = "false";
  }

  showLoadingOverlay() {
    console.log(this.loadingOverlayTarget);
    this.loadingOverlayTarget.dataset.loading = "true";
  }

  closeIfOutsideSelector(event) {
    // If did clicked inside selector, return
    if (
      this.selectorTarget.contains(event.target) ||
      this.buttonTarget.contains(event.target)
    ) {
      return;
    }

    this.selectorTarget.innerHTML = "";
    this.buttonTarget.dataset.active = "false";
  }
}
