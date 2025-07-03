import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["video", "step"];

  connect() {
    this.videoTarget.addEventListener(
      "timeupdate",
      this.updateActiveStep.bind(this),
    );

    // Make steps clickable to jump to video position
    this.stepTargets.forEach((step) => {
      step.style.cursor = "pointer";
      step.addEventListener("click", this.jumpToStep.bind(this));
    });
  }

  disconnect() {
    this.videoTarget.removeEventListener(
      "timeupdate",
      this.updateActiveStep.bind(this),
    );
  }

  updateActiveStep() {
    const currentTime = this.videoTarget.currentTime;

    this.stepTargets.forEach((step) => {
      const startTime = parseFloat(step.dataset.startTime);
      const endTime = parseFloat(step.dataset.endTime);

      if (currentTime >= startTime && currentTime < endTime) {
        this.activateStep(parseInt(step.dataset.step));
      }
    });
  }

  activateStep(stepNumber) {
    this.stepTargets.forEach((step) => {
      const stepNum = parseInt(step.dataset.step);
      const dt = step.querySelector("dt");
      const dd = step.querySelector("dd");
      const svg = step.querySelector("svg");

      if (stepNum === stepNumber) {
        step.dataset.active = true;
        dt.dataset.active = true;
        dd.dataset.active = true;
        svg.dataset.active = true;
      } else {
        delete step.dataset.active;
        delete dt.dataset.active;
        delete dd.dataset.active;
        delete svg.dataset.active;
      }
    });
  }

  jumpToStep(event) {
    const step = event.currentTarget;
    const startTime = parseFloat(step.dataset.startTime);

    this.videoTarget.currentTime = startTime;

    // If video is paused, play it
    if (this.videoTarget.paused) {
      this.videoTarget.play();
    }
  }
}
