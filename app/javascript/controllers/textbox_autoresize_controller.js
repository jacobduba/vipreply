import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="textbox-autoresize"
export default class extends Controller {
  connect() {
    this.resize();

    this.element.addEventListener("input", this.resize.bind(this));
  }

  disconnect() {
    this.element.removeEventListener("input", this.resize.bind(this));
  }

  resize() {
    this.element.style.height = "auto";
    this.element.style.height = `${this.element.scrollHeight + 2}px`;
  }
}
