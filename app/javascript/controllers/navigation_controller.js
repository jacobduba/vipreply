import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="navigation"
export default class extends Controller {
  back(event) {
    history.back();
    event.preventDefault();
  }
}
