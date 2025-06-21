import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["iframe", "loader", "lastMessage"];

  connect() {
    this.setAllIframeHeight();
    window.addEventListener("resize", this.setAllIframeHeight);
    this.iframeTargets.forEach((iframe, index) => {
      iframe.addEventListener("load", () => {
        this.hideLoaderShowIframe(index);
        this.setIframeHeight(iframe);
        this.scrollToLastMessage();
      });
      if (iframe.contentWindow?.document.readyState === "complete") {
        this.hideLoaderShowIframe(index);
        this.setIframeHeight(iframe);
        this.scrollToLastMessage();
      }
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.setAllIframeHeight);
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", () => this.setIframeHeight(iframe));
    });
  }

  setAllIframeHeight = () => {
    this.iframeTargets.forEach((iframe) => {
      this.setIframeHeight(iframe);
    });
  };

  hideLoaderShowIframe = (index) => {
    this.loaderTargets[index].style.display = "none";
    this.iframeTargets[index].style.display = "block";
  };

  scrollToLastMessage = () => {
    // I want to show a little of the previous message so the user knows there is more above
    const distFromTop = 80;
    const elementPosition =
      this.lastMessageTarget.getBoundingClientRect().top + window.scrollY;
    window.scrollTo({
      top: elementPosition - distFromTop,
    });
  };

  setIframeHeight = (iframe) => {
    const document = iframe.contentWindow.document;
    const html = document.documentElement;
    const height = html.scrollHeight + 2; // Add 2 pixels to account for border 1px padding
    iframe.style.height = `${height}px`;
  };
}
