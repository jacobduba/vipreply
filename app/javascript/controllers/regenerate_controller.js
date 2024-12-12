import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["updateQueryField", "createQueryField"];

  copyQueryToUpdateForm() {
    this.updateQueryFieldTarget.value = this.generateQueryFieldTarget.value;
  }

  copyQueryToCreateForm() {
    this.createQueryFieldTarget.value =
      document.getElementById("query_field").value;
  }
}
