import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="template-selector-form"
export default class extends Controller {
  static targets = [
    "templateCheckbox",
    "templateRow",
    "multiselect",
    "buttonText",
  ];

  connect() {
    const initialCount = parseInt(this.multiselectTarget.dataset.totalChecked) || 0;
    this.updateButtonText(initialCount);
  }

  get totalChecked() {
    return parseInt(this.multiselectTarget.dataset.totalChecked) || 0;
  }

  set totalChecked(value) {
    this.multiselectTarget.dataset.totalChecked = value;
    this.updateButtonText(value);
  }

  toggleCheck(event) {
    const checkbox = event.target;
    const row = checkbox.closest(
      '[data-template-selector-form-target="templateRow"]',
    );
    row.dataset.isChecked = checkbox.checked;

    this.totalChecked = this.templateCheckboxTargets.filter(cb => cb.checked).length;
  }

  // Allow clicking anywhere on the template row to toggle the checkbox
  toggleTemplate(event) {
    const templateId = event.currentTarget.dataset.templateId;
    const checkbox = this.templateCheckboxTargets.find(
      cb => cb.value === templateId
    );
    
    if (checkbox) {
      checkbox.checked = !checkbox.checked;
      const row = checkbox.closest('[data-template-selector-form-target="templateRow"]');
      row.dataset.isChecked = checkbox.checked;
      
      this.totalChecked = this.templateCheckboxTargets.filter(cb => cb.checked).length;
    }
  }

  updateButtonText(count) {
    if (count === 1) {
      this.buttonTextTarget.textContent = "Select 1 template";
    } else {
      this.buttonTextTarget.textContent = `Select ${count} templates`;
    }
    
    // Show/hide the button based on checked items
    if (count > 0) {
      this.multiselectTarget.classList.remove("hidden");
    } else {
      this.multiselectTarget.classList.add("hidden");
    }
  }
}