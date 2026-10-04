document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-dropdown-toggle]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation()

      const menu = document.getElementById(
        button.dataset.dropdownToggle
      )

      document.querySelectorAll(".dropdown-menu").forEach((dropdown) => {
        if (dropdown !== menu) dropdown.classList.add("hidden")
      })

      menu.classList.toggle("hidden")
    })
  })

  document.addEventListener("click", () => {
    document.querySelectorAll(".dropdown-menu").forEach((menu) => {
      menu.classList.add("hidden")
    })
  })
})