import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["updateQueryField", "createQueryField"];

  copyQueryToUpdateForm() {
    this.updateQueryFieldTarget.value =
      document.getElementById("query_field").value;
  }

  copyQueryToCreateForm() {
    this.createQueryFieldTarget.value =
      document.getElementById("query_field").value;
  }
}
