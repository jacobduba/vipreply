import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector-form"
export default class extends Controller {
  static targets = [
    "templateCheckbox",
    "templateDiv",
    "multiselect",
    "buttonText",
  ];

  toggleCheck(event) {
    const checkbox = event.target;
    const row = checkbox.closest(
      '[data-template-selector-form-target="templateRow"]',
    );
    row.dataset.isChecked = checkbox.checked;

    if (checkbox.checked) {
      this.multiselectTarget.dataset.totalChecked++;
    } else {
      this.multiselectTarget.dataset.totalChecked--;
    }

    if (this.multiselectTarget.dataset.totalChecked == 1) {
      this.buttonTextTarget.textContent = "Selected 1 template";
    } else {
      this.buttonTextTarget.textContent = `Selected ${this.multiselectTarget.dataset.totalChecked} templates`;
    }
  }
}
