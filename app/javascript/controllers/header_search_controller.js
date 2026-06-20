import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "input"]
  static values = { home: Boolean }

  connect() {
    this.compactQuery = window.matchMedia("(max-width: 720px)")

    if (this.homeValue) {
      this.watchHomepageSearch()
    } else {
      this.setAvailable(true)
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  submit(event) {
    if (this.compactQuery.matches && !this.containerTarget.classList.contains("header-search--open")) {
      event.preventDefault()
      this.containerTarget.classList.add("header-search--open")
      this.inputTarget.focus()
    }
  }

  watchHomepageSearch() {
    const sentinel = document.querySelector("[data-header-search-sentinel]")
    if (!sentinel || !("IntersectionObserver" in window)) {
      this.setAvailable(true)
      return
    }

    this.observer = new IntersectionObserver(([entry]) => {
      this.setAvailable(!entry.isIntersecting)
    }, {
      rootMargin: "-72px 0px 0px 0px",
      threshold: 0.1
    })

    this.observer.observe(sentinel)
  }

  setAvailable(available) {
    this.containerTarget.classList.toggle("header-search--available", available)
    if (!available) this.containerTarget.classList.remove("header-search--open")
  }
}
