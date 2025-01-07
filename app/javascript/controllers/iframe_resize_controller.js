import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["iframe", "loader"];

  connect() {
    this.setAllIframeHeight();
    window.addEventListener("resize", this.setAllIframeHeight);
    this.iframeTargets.forEach((iframe, index) => {
      iframe.addEventListener("load", () => {
        this.hideLoaderShowIframe(index);
        this.setIframeHeight(iframe);
      });
      if (iframe.contentWindow?.document.readyState === 'complete') {
        this.hideLoaderShowIframe(index);
        this.setIframeHeight(iframe);
      }
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.setAllIframeHeight);
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", () => this.setIframeHeight(iframe));
    })
  }

  setAllIframeHeight = async () => {
    this.iframeTargets.forEach((iframe) => {
      this.setIframeHeight(iframe);
    });
  }

  hideLoaderShowIframe = async (index) => {
    this.loaderTargets[index].style.display = "none";
    this.iframeTargets[index].style.display = "block";
  }

  setIframeHeight = async (iframe) => {
    const document = iframe.contentWindow.document;
    const html = document.documentElement;
    const height = html.scrollHeight
    iframe.style.height = `${height}px`;
  };
}
