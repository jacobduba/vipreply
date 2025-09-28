import { Controller } from "@hotwired/stimulus";

// Iframes need h-0 class to reset height before measuring scrollHeight
// iframes's inner html expands to max size if less, so html scrollheight will be too big
export default class extends Controller {
  connect() {
    this.resizeIframe();
    window.addEventListener("resize", this.resizeIframe);
    document.addEventListener("turbo:morph", this.handleMorph);

    this.element.addEventListener("load", this.handleLoad);

    if (this.element.contentWindow?.document.readyState === "complete") {
      this.resizeIframe();
      this.scrollToTarget();
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeIframe);
    document.removeEventListener("turbo:morph", this.handleMorph);
    this.element.removeEventListener("load", this.handleLoad);
  }

  handleLoad = () => {
    this.resizeIframe();
    this.scrollToTarget();
  };

  handleMorph = () => {
    // Reset height before iframe reloads with new content
    this.element.style.height = '0px';
    setTimeout(() => this.resizeIframe(), 100);
  };

  resizeIframe = () => {
    const html = this.element.contentWindow?.document?.documentElement;
    if (!html) return;

    // Add 2px to account for border/padding
    this.element.style.height = `${html.scrollHeight}px`;
  };

  scrollToTarget = () => {
    const target = document.getElementById("last-message");
    if (!target) return;

    const offset = 80;
    const rect = target.getBoundingClientRect();
    window.scrollTo({
      top: rect.top + window.scrollY - offset,
    });
  };
}
