import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.resizeIframe = this.resizeIframe.bind(this);
    this.handleLoad = this.handleLoad.bind(this);

    window.addEventListener("resize", this.resizeIframe);
    this.element.addEventListener("load", this.handleLoad);

    if (this.element.contentWindow?.document.readyState === "complete") {
      this.handleLoad();
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeIframe);
    this.element.removeEventListener("load", this.handleLoad);
  }

  handleLoad() {
    this.resizeIframe();
    this.scrollToTarget();
  }

  resizeIframe() {
    const html = this.element.contentWindow?.document?.documentElement;
    if (!html) return;
    this.element.style.height = `${html.scrollHeight}px`;
  }

  // Every message iframe scrolls to the last message when it loads.
  // So if the last message loads before previous messages the scroll goes down to the last message
  scrollToTarget() {
    const target = document.querySelector("[is-last-vipreply-message]");
    if (!target) return;

    const offset = 80;
    const rect = target.getBoundingClientRect();

    // Non-last messages use instant scroll to quickly move down without scrolling
    // through the whole thread. The last message smooth scrolls for a clean effect
    // when new messages arrive.
    // Cool side effect you'll notice is if the last message smooth scrolled to the bottom already,
    // it appears to "stay in place" with the instant scrolls for the rest of the messages
    const scrollSmoothly = this.element.hasAttribute("is-last-vipreply-message")
      ? "smooth"
      : "instant";

    window.scrollTo({
      top: rect.top + window.scrollY - offset,
      behavior: scrollSmoothly,
    });
  }
}
