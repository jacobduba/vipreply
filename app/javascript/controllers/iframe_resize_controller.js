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

  scrollToTarget() {
    // Every message iframe scrolls to the last message when it loads.
    // So if the last message loads before previous messages the scroll goes down to the last message
    const lastMessageIframe = document.querySelector("[data-last-message]");
    if (!lastMessageIframe) return;

    const lastMessageContainer = lastMessageIframe.parentElement.parentElement;
    const containerRect = lastMessageContainer.getBoundingClientRect();

    // not last message? insant scroll down
    // last message? smooth scroll (for appending the last message when you send a message)
    const scrollSmoothly = this.element.hasAttribute("data-last-message")
      ? "smooth"
      : "instant";

    const header = document.getElementById("main-header");
    const headerHeight = header ? header.offsetHeight : 0;
    const marginTop = parseFloat(
      getComputedStyle(lastMessageContainer).marginTop,
    );
    const distanceFromViewportTop = containerRect.top;
    const currentScrollPosition = window.scrollY;
    const elementPositionOnPage =
      distanceFromViewportTop + currentScrollPosition;
    const scrollTarget = elementPositionOnPage - headerHeight - marginTop;

    window.scrollTo({
      top: scrollTarget,
      behavior: scrollSmoothly,
    });
  }
}
