import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "answer", "expandIcon", "collapseIcon"]

  toggle() {
    const isExpanded = this.answerTarget.classList.contains("hidden")
    
    if (isExpanded) {
      // Show answer
      this.answerTarget.classList.remove("hidden")
      this.expandIconTarget.classList.add("hidden")
      this.collapseIconTarget.classList.remove("hidden")
      this.buttonTarget.setAttribute("aria-expanded", "true")
    } else {
      // Hide answer
      this.answerTarget.classList.add("hidden")
      this.expandIconTarget.classList.remove("hidden")
      this.collapseIconTarget.classList.add("hidden")
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }
}