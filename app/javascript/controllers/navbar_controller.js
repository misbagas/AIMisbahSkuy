import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "dropdownMenu"]

  toggleMobileMenu(event) {
    event.stopPropagation()
    this.mobileMenuTarget.classList.toggle("hidden")
  }

  toggleDropdown(event) {
    event.stopPropagation()
    this.dropdownMenuTarget.classList.toggle("hidden")
  }

  hideDropdown(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownMenuTarget?.classList.add("hidden")
    }
  }
}
