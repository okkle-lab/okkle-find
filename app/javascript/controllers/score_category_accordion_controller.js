import { Controller } from "@hotwired/stimulus"

const DURATION = 320

// Animates the open/close of each category by tweening the panel's height, so the
// categories below slide to their new position instead of jumping. A native
// <details> changes height instantly; here we drive it ourselves.
export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const details = event.currentTarget.closest("details")
    if (!details) return

    // Let reduced-motion users get the instant native behaviour.
    if (this.prefersReducedMotion) {
      if (!details.open) {
        this.itemTargets.forEach((item) => {
          if (item !== details) item.open = false
        })
      }
      return
    }

    event.preventDefault()
    if (details.dataset.animating) return

    if (details.open) {
      this.close(details)
    } else {
      this.closeOthers(details)
      this.open(details)
    }
  }

  closeOthers(selected) {
    this.itemTargets.forEach((item) => {
      if (item !== selected && item.open) this.close(item)
    })
  }

  open(details) {
    const panel = this.panelFor(details)
    if (!panel) {
      details.open = true
      return
    }

    details.open = true
    const target = panel.scrollHeight
    this.animate(details, panel, 0, target, () => {
      panel.style.height = ""
      panel.style.overflow = ""
    })
  }

  close(details) {
    const panel = this.panelFor(details)
    if (!panel) {
      details.open = false
      return
    }

    const start = panel.scrollHeight
    this.animate(details, panel, start, 0, () => {
      details.open = false
      panel.style.height = ""
      panel.style.overflow = ""
    })
  }

  animate(details, panel, from, to, done) {
    details.dataset.animating = "true"
    panel.style.overflow = "hidden"
    panel.style.height = `${from}px`
    panel.style.transition = "none"
    panel.getBoundingClientRect()

    requestAnimationFrame(() => {
      panel.style.transition = `height ${DURATION}ms cubic-bezier(0.22, 1, 0.36, 1)`
      panel.style.height = `${to}px`

      let finished = false
      const finish = (event) => {
        if (event && event.propertyName !== "height") return
        if (finished) return
        finished = true
        panel.removeEventListener("transitionend", finish)
        panel.style.transition = ""
        delete details.dataset.animating
        done()
      }
      panel.addEventListener("transitionend", finish)
      // Fallback in case transitionend is missed (e.g. tab hidden mid-animation).
      setTimeout(() => finish(), DURATION + 60)
    })
  }

  panelFor(details) {
    return details.querySelector(".cat-subpanel")
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
