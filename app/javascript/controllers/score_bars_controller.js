import { Controller } from "@hotwired/stimulus"

const previousWidthsByScope = new Map()
const previousUnavailableByScope = new Map()

export default class extends Controller {
  static targets = ["fill"]
  static values = { scope: String }

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.shell = this.element.closest(".cat-bars-shell")
    this.blurElement = this.element.closest(".cat-score-content") || this.element
    this.scopeKey = this.scopeValue || this.frame?.id || "default"
    this.storeFrameState = this.storeFrameState.bind(this)
    this.frame?.addEventListener("turbo:before-frame-render", this.storeFrameState)

    if (this.prefersReducedMotion) return

    if (previousUnavailableByScope.get(this.scopeKey) && !this.unavailable) {
      this.blurElement.classList.add("cat-bars-blur-out")
    }

    const previousWidths = previousWidthsByScope.get(this.scopeKey)
    if (!previousWidths) return

    this.fillTargets.forEach((fill) => {
      const targetWidth = this.targetWidth(fill)
      const previousWidth = previousWidths.get(this.fillKey(fill)) || "0%"

      fill.style.transition = "none"
      fill.style.width = previousWidth
      fill.getBoundingClientRect()

      requestAnimationFrame(() => {
        fill.style.transition = ""
        fill.style.width = targetWidth
      })
    })
  }

  disconnect() {
    this.frame?.removeEventListener("turbo:before-frame-render", this.storeFrameState)
    this.storeFrameState()
  }

  storeFrameState() {
    previousWidthsByScope.set(this.scopeKey, this.currentWidths())
    previousUnavailableByScope.set(this.scopeKey, this.unavailable)
  }

  currentWidths() {
    return new Map(
      this.fillTargets.map((fill) => [this.fillKey(fill), this.renderedWidth(fill)])
    )
  }

  renderedWidth(fill) {
    const trackWidth = fill.parentElement?.getBoundingClientRect().width || 0
    const fillWidth = fill.getBoundingClientRect().width
    if (trackWidth <= 0) return this.targetWidth(fill)

    return `${((fillWidth / trackWidth) * 100).toFixed(2)}%`
  }

  targetWidth(fill) {
    return `${fill.dataset.scoreBarsWidth}%`
  }

  fillKey(fill) {
    return fill.dataset.scoreBarsKey
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  get unavailable() {
    return this.shell?.classList.contains("cat-bars-shell-unavailable") || false
  }
}
