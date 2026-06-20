import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.image = this.element.querySelector(".tool-logo-img")
    if (!this.image) return

    if (this.image.complete) {
      this.sampleSoon()
    } else {
      this.image.addEventListener("load", () => this.sampleSoon(), { once: true })
    }
  }

  sampleSoon() {
    requestAnimationFrame(() => this.loadSampleImage())
  }

  loadSampleImage() {
    if (!this.image.naturalWidth || this.image.style.display === "none") return

    const source = this.image.currentSrc || this.image.src
    if (!source) return

    const sampleImage = new Image()
    sampleImage.crossOrigin = "anonymous"
    sampleImage.onload = () => this.sampleLogo(sampleImage)
    sampleImage.onerror = () => {}
    sampleImage.src = source
  }

  sampleLogo(image) {
    const size = 48
    const canvas = document.createElement("canvas")
    const scale = Math.min(size / image.naturalWidth, size / image.naturalHeight, 1)
    canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
    canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))

    const context = canvas.getContext("2d", { willReadFrequently: true })
    context.drawImage(image, 0, 0, canvas.width, canvas.height)

    let data
    try {
      data = context.getImageData(0, 0, canvas.width, canvas.height).data
    } catch {
      return
    }

    const buckets = new Map()
    for (let i = 0; i < data.length; i += 4) {
      const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]]
      if (a < 80 || this.isNearWhite(r, g, b)) continue

      const key = [r, g, b].map((value) => Math.round(value / 24) * 24).join(",")
      const bucket = buckets.get(key) || { count: 0, r: 0, g: 0, b: 0, score: 0 }
      const saturation = Math.max(r, g, b) - Math.min(r, g, b)
      bucket.count += 1
      bucket.r += r
      bucket.g += g
      bucket.b += b
      bucket.score += 1 + saturation / 255
      buckets.set(key, bucket)
    }

    const dominant = [...buckets.values()].sort((a, b) => b.score - a.score)[0]
    if (!dominant || dominant.count < 4) return

    const color = [
      dominant.r / dominant.count,
      dominant.g / dominant.count,
      dominant.b / dominant.count
    ].map((value) => Math.round(value).toString(16).padStart(2, "0")).join("")

    this.element.style.setProperty("--brand", `#${color}`)
  }

  isNearWhite(r, g, b) {
    return r > 238 && g > 238 && b > 238
  }
}
