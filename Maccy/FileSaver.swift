import AppKit

// Saves the selected history item (image or files) into "Maccy Files" inside
// Downloads, so it can be quickly found and shared. The folder is created on
// first use and tagged green in Finder.
@MainActor
enum FileSaver {
  enum SaveError: Error {
    case nothingToSave
  }

  static var folderURL: URL {
    FileManager.default
      .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Maccy Files", isDirectory: true)
  }

  static func save(_ decorator: HistoryItemDecorator) {
    do {
      let url = try saveContent(of: decorator.item)
      NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch {
      Notifier.notify(body: NSLocalizedString("file_save_failed", comment: ""), sound: nil)
      NSLog("File save failed: \(error)")
    }
  }

  private static func ensureFolder() throws -> URL {
    let folder = folderURL
    if !FileManager.default.fileExists(atPath: folder.path) {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      applyGreenTag(to: folder)
    }
    return folder
  }

  // The URLResourceValues.tagNames setter is macOS 26+, so the Finder tag is
  // written directly: the "\n2" suffix is the color index (2 = green).
  private static func applyGreenTag(to url: URL) {
    guard let data = try? PropertyListSerialization.data(
      fromPropertyList: ["Green\n2"],
      format: .binary,
      options: 0
    ) else { return }

    data.withUnsafeBytes { buffer in
      _ = setxattr(url.path, "com.apple.metadata:_kMDItemUserTags", buffer.baseAddress, buffer.count, 0, 0)
    }
  }

  private static func saveContent(of item: HistoryItem) throws -> URL {
    let folder = try ensureFolder()

    // File items: copy the originals over. Reading can fail for locations the
    // sandbox has no access to — the error notification covers that.
    let fileURLs = item.fileURLs
    if !fileURLs.isEmpty {
      var savedURL: URL?
      for source in fileURLs {
        let destination = uniqueURL(for: folder.appendingPathComponent(source.lastPathComponent))
        try FileManager.default.copyItem(at: source, to: destination)
        savedURL = destination
      }
      guard let savedURL else { throw SaveError.nothingToSave }
      return savedURL
    }

    // Image items: always save as PNG for predictable sharing.
    if let pngData = pngData(of: item) {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
      let name = "Image \(formatter.string(from: Date())).png"
      let destination = uniqueURL(for: folder.appendingPathComponent(name))
      try pngData.write(to: destination)
      return destination
    }

    throw SaveError.nothingToSave
  }

  private static func pngData(of item: HistoryItem) -> Data? {
    if let content = item.contents.first(where: { $0.type == NSPasteboard.PasteboardType.png.rawValue }),
       let data = content.value {
      return data
    }

    // TIFF/JPEG/HEIC representations are converted.
    guard let data = item.imageData,
          let representation = NSBitmapImageRep(data: data) else {
      return nil
    }
    return representation.representation(using: .png, properties: [:])
  }

  private static func uniqueURL(for url: URL) -> URL {
    let base = url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension
    let folder = url.deletingLastPathComponent()

    var candidate = url
    var counter = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
      candidate = folder.appendingPathComponent(name)
      counter += 1
    }
    return candidate
  }
}
