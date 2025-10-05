import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="smart-template-hover"
export default class extends Controller {
  static targets = ["tooltip"];

  show() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.remove("hidden");
    }
  }

  hide() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden");
    }
  }
}
