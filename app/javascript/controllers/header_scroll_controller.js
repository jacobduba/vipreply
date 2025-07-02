import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.scrolled = false;
    this.handleScroll();

    this.throttledScroll = this.throttle(() => this.handleScroll(), 100);

    window.addEventListener("scroll", this.throttledScroll);
  }

  throttle(fn, delay) {
    let time = Date.now();

    return () => {
      if (time + delay - Date.now() <= 0) {
        fn();
        time = Date.now();
      }
    };
  }

  disconnect() {
    window.removeEventListener("scroll", this.throttledScroll);
  }

  handleScroll() {
    console.log("lol");
    const scrollPosition = window.scrollY;
    const scrollThreshold = 50;
    const shouldBeScrolled = scrollPosition > scrollThreshold;

    // Only update DOM if state changed
    if (this.scrolled !== shouldBeScrolled) {
      this.scrolled = shouldBeScrolled;
      this.element.dataset.scrolled = shouldBeScrolled;
    }
  }
}
