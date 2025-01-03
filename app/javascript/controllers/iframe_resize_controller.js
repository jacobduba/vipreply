import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["iframe"];

  connect() {
    console.log("Started")
    this.setIframeHeight(); // Set height on page load
    window.addEventListener("resize", this.setIframeHeight); // Adjust on resize
    this.iframeTargets.forEach((iframe) => {
      iframe.addEventListener("load", () => this.setIframeHeight);
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.setIframeHeight); // Clean up
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", () => this.setIframeHeight);
    })
  }

  setIframeHeight = async () => {
    this.iframeTargets.forEach((iframe) => {
      const height = iframe.contentWindow.document.body.scrollHeight;

      iframe.style.height = `${height}px`;
      console.log(`Iframe height set to: ${height}px for`, iframe);
    });
  };
}
