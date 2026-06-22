import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const selected = event.currentTarget
    if (!selected.open) return

    this.itemTargets.forEach((item) => {
      if (item !== selected) item.open = false
    })
  }
}
