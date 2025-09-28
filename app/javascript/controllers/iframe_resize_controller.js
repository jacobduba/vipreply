import { Controller } from "@hotwired/stimulus";

// Iframes need h-0 class to reset height before measuring scrollHeight
// iframes's inner html expands to max size if less, so html scrollheight will be too big
export default class extends Controller {
  static targets = ["iframe", "lastMessage"];

  connect() {
    this.resizeAllIframes();
    window.addEventListener("resize", this.resizeAllIframes);
    document.addEventListener("turbo:morph", this.resizeAllIframes);

    this.iframeTargets.forEach((iframe) => {
      iframe.addEventListener("load", this.handleIframeLoad);

      if (iframe.contentWindow?.document.readyState === "complete") {
        this.resizeIframe(iframe);
        this.scrollToLastMessage();
      }
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeAllIframes);
    document.removeEventListener("turbo:morph", this.resizeAllIframes);
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", this.handleIframeLoad);
    });
  }

  handleIframeLoad = (event) => {
    this.resizeIframe(event.target);
    this.scrollToLastMessage();
  };

  resizeAllIframes = () => {
    this.iframeTargets.forEach(this.resizeIframe);
  };

  resizeIframe = (iframe) => {
    const html = iframe.contentWindow?.document?.documentElement;
    if (!html) return;

    // Add 2px to account for border/padding
    iframe.style.height = `${html.scrollHeight}px`;
  };

  scrollToLastMessage = () => {
    const offset = 80;
    const rect = this.lastMessageTarget.getBoundingClientRect();
    window.scrollTo({
      top: rect.top + window.scrollY - offset,
    });
  };
}
