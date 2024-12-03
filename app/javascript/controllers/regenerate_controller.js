import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["exampleQueryField", "generateQueryField"];

  copyQueryToExampleForm() {
    this.exampleQueryFieldTarget.value = this.generateQueryFieldTarget.value;
  }
}
