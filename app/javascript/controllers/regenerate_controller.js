import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "updateQueryField",
    "createQueryField",
    "generateQueryField",
  ];

  copyQueryToUpdateForm() {
    this.updateQueryFieldTarget.value = this.generateQueryFieldTarget.value;
  }

  copyQueryToCreateForm() {
    this.createQueryFieldTarget.value = this.generateQueryFieldTarget.value;
  }
}
