import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  toggle() {
    this.element.classList.toggle("-translate-x-full")
    this.overlayTarget.classList.toggle("hidden")
  }

  close() {
    this.element.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
  }

  newTask() {
    window.location.href = "/tasks/new"
  }
}