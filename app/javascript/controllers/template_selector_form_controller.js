import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector-form"
export default class extends Controller {
  static targets = ["templateCheckbox", "templateDiv", "multiselect"];

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
  }
}
