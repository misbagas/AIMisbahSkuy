import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "submit", "fileInput", "uploadStatus", "previewList"]

  connect() {
    this.selectedFiles = []
  }

  fileSelected() {
    this.selectedFiles = Array.from(this.fileInputTarget.files)
    this.updateUploadStatus()
    this.renderPreviews()
  }

  addFiles(fileList) {
    const incomingFiles = Array.from(fileList || [])
    if (!incomingFiles.length) return

    this.selectedFiles = [...this.selectedFiles, ...incomingFiles]
    this.syncFileInput()
    this.updateUploadStatus()
    this.renderPreviews()
  }

  updateUploadStatus() {
    this.uploadStatusTarget.textContent = this.selectedFiles.length
      ? `${this.selectedFiles.length} file${this.selectedFiles.length === 1 ? "" : "s"} ready`
      : "Upload File"
  }

  removeFile(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.selectedFiles.splice(index, 1)

    this.syncFileInput()
    this.updateUploadStatus()
    this.renderPreviews()
  }

  dragOver(event) {
    event.preventDefault()
    this.formTarget.classList.add("is-dragging")
  }

  dragLeave(event) {
    if (this.formTarget.contains(event.relatedTarget)) return

    this.formTarget.classList.remove("is-dragging")
  }

  drop(event) {
    event.preventDefault()
    this.formTarget.classList.remove("is-dragging")
    this.addFiles(event.dataTransfer.files)
  }

  syncFileInput() {
    const transfer = new DataTransfer()
    this.selectedFiles.forEach((file) => transfer.items.add(file))
    this.fileInputTarget.files = transfer.files
  }

  renderPreviews() {
    this.previewListTarget.hidden = this.selectedFiles.length === 0
    this.previewListTarget.replaceChildren()

    this.selectedFiles.forEach((file, index) => {
      const card = document.createElement("div")
      card.className = "attachment-preview"

      const thumbnail = document.createElement("div")
      thumbnail.className = "attachment-preview-thumb"
      if (file.type.startsWith("image/")) {
        const image = document.createElement("img")
        image.src = URL.createObjectURL(file)
        image.onload = () => URL.revokeObjectURL(image.src)
        image.onerror = () => URL.revokeObjectURL(image.src)
        image.alt = ""
        thumbnail.append(image)
      } else {
        thumbnail.textContent = file.type.startsWith("video/") ? "▶" : "▧"
      }

      const details = document.createElement("div")
      details.className = "attachment-preview-details"
      const name = document.createElement("strong")
      name.textContent = file.name
      const size = document.createElement("small")
      size.textContent = this.formatBytes(file.size)
      details.append(name, size)

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "attachment-preview-remove"
      remove.dataset.index = index
      remove.setAttribute("aria-label", `Remove ${file.name}`)
      remove.textContent = "×"
      remove.addEventListener("click", (event) => this.removeFile(event))

      card.append(thumbnail, details, remove)
      this.previewListTarget.append(card)
    })
  }

  formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  submitting() {
    if (this.submitTarget.disabled) return

    this.submitTarget.disabled = true
    this.submitTarget.setAttribute("aria-busy", "true")
    this.submitTarget.textContent = "…"
    this.uploadStatusTarget.textContent = this.selectedFiles.length
      ? "Uploading & analyzing…"
      : "Thinking…"
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey || (!this.inputTarget.value.trim() && this.selectedFiles.length === 0)) return

    event.preventDefault()

    this.formTarget.requestSubmit(this.submitTarget)
  }
}
