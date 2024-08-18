import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="turbo-modal"
export default class extends Controller {
  hideModal() {
    this.element.parentElement.removeAttribute("src");
    this.element.remove();
  }

  submitEnd(e) {
    console.log(e);
    if (e.detail.success) {
      console.log("success");
      this.hideModal();
    }
  }
}
