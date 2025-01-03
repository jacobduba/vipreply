import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["iframe"];

  connect() {
    this.setAllIframeHeight(); // Set height on page load
    window.addEventListener("resize", this.setAllIframeHeight); // Adjust on resize
    this.iframeTargets.forEach((iframe) => {
      console.log(iframe)
      iframe.addEventListener("load", () => this.setIframeHeight(iframe));
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.setAllIframeHeight); // Clean up
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", () => this.setIframeHeight(iframe));
    })
  }

  setAllIframeHeight = async () => {
    this.iframeTargets.forEach((iframe) => {
      this.setIframeHeight(iframe);
    });
  }

  setIframeHeight = async (iframe) => {
    const document = iframe.contentWindow.document;
    const html = document.documentElement;
    iframe.style.height = `${html.scrollHeight}px`;
    console.log(`Iframe height set to: ${height}px for`, iframe);
  };
}
