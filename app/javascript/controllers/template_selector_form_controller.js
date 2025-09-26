import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector-form"
export default class extends Controller {
  static targets = [
    "templateCheckbox",
    "templateDiv",
    "multiselect",
    "buttonText",
  ];

  get totalChecked() {
    return this.multiselectTarget.dataset.totalChecked;
  }

  set totalChecked(value) {
    this.multiselectTarget.dataset.totalChecked = value;
  }

  toggleCheck(event) {
    const checkbox = event.target;
    const row = checkbox.closest(
      '[data-template-selector-form-target="templateRow"]',
    );
    row.dataset.isChecked = checkbox.checked;

    if (checkbox.checked) {
      this.totalChecked++;
    } else {
      this.totalChecked--;
    }

    if (this.totalChecked == 1) {
      this.buttonTextTarget.textContent = "Choose 1 smart card";
    } else {
      this.buttonTextTarget.textContent = `Choose ${this.totalChecked} smart cards`;
    }
  }
}
