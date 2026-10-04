import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "log"]

  validate(event) {
    if (this.inputTarget.value.trim()) return

    event.preventDefault()
    this.logTarget.textContent = "Please enter a task name."
    this.inputTarget.focus()
  }
}
