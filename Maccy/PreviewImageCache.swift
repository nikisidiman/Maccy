import AppKit
import Defaults

// Keeps the total size of decoded preview bitmaps bounded: previews are
// screen-sized (tens of MB each) and otherwise accumulate for the lifetime
// of the process. When the budget is exceeded, the least recently used
// previews are released; they are lazily regenerated on the next hover.
@MainActor
final class PreviewImageCache {
  static let shared = PreviewImageCache()

  private struct Entry {
    let decorator: HistoryItemDecorator
    let bytes: Int
  }

  private var entries: [ObjectIdentifier: Entry] = [:]
  private var order: [ObjectIdentifier] = [] // least recently used first
  private var totalBytes = 0

  func track(_ decorator: HistoryItemDecorator, image: NSImage) {
    let id = ObjectIdentifier(decorator)
    forget(id)
    let bytes = Self.estimatedBytes(of: image)
    entries[id] = Entry(decorator: decorator, bytes: bytes)
    order.append(id)
    totalBytes += bytes
    evictIfNeeded()
  }

  func touch(_ decorator: HistoryItemDecorator) {
    let id = ObjectIdentifier(decorator)
    guard entries[id] != nil, order.last != id else { return }
    order.removeAll { $0 == id }
    order.append(id)
  }

  func forget(_ decorator: HistoryItemDecorator) {
    forget(ObjectIdentifier(decorator))
  }

  private func forget(_ id: ObjectIdentifier) {
    guard let entry = entries.removeValue(forKey: id) else { return }
    totalBytes -= entry.bytes
    order.removeAll { $0 == id }
  }

  private func evictIfNeeded() {
    let limit = max(Defaults[.previewCacheLimitMB], 1) * 1024 * 1024
    // The most recent entry is never evicted — it is the one on screen.
    while totalBytes > limit, order.count > 1 {
      let id = order.removeFirst()
      guard let entry = entries.removeValue(forKey: id) else { continue }
      totalBytes -= entry.bytes
      entry.decorator.releasePreviewImage(notifyCache: false)
    }
  }

  private static func estimatedBytes(of image: NSImage) -> Int {
    let rep = image.representations.first
    let width = rep?.pixelsWide ?? Int(image.size.width)
    let height = rep?.pixelsHigh ?? Int(image.size.height)
    return max(width * height * 4, 1)
  }
}
